//
//  WeatherPresenter.swift
//  weatherapp
//
//  Created by Альберт Ражапов on 01.04.2026.
//

import Combine
import Foundation
import UIKit

enum LocationAccessState {
    case granted
    case denied
}

protocol WeatherViewProtocol: AnyObject {
    func displayCurrentLoading(_ isLoading: Bool)
    func displayForecastLoading(_ isLoading: Bool)
    func displayLocationAccess(state: LocationAccessState)
    func displayCurrentWeather(_ model: CurrentWeatherModel)
    func displayForecast(_ model: ForecastWeatherModel)
    func displayCurrentError(message: String)
    func displayCurrentErrorHidden()
    func displayForecastError(message: String)
    func displayForecastErrorHidden()
}

protocol WeatherPresenterProtocol: AnyObject {
    func presentAttachView(_ view: WeatherViewProtocol)
    func presentViewDidLoad()
    func presentViewDidAppear()
    func presentRetryCurrent()
    func presentRetryForecast()
    func presentViewDidDisappear()
}

private enum SectionResult {
    case current(Result<CurrentWeatherModel, Error>)
    case forecast(Result<ForecastWeatherModel, Error>)
}

private struct CurrentPayload {
    let data: CurrentWeatherResponse
    let isFromDevice: Bool
}

final class WeatherPresenter: WeatherPresenterProtocol {
    private weak var view: WeatherViewProtocol?
    private let weatherNetworkService: WeatherNetworkProtocol
    private let locationService: LocationServiceProtocol
    private let defaultCoordinate: WeatherCoordinate

    private var updatesTask: Task<Void, Never>?
    private var locationAccessObserver: AnyCancellable?

    init(
        weatherNetworkService: WeatherNetworkProtocol,
        locationService: LocationServiceProtocol,
        defaultCoordinate: WeatherCoordinate
    ) {
        self.weatherNetworkService = weatherNetworkService
        self.locationService = locationService
        self.defaultCoordinate = defaultCoordinate
    }

    func presentAttachView(_ view: WeatherViewProtocol) {
        self.view = view
        observeLocationAccessChanges()
    }

    func presentViewDidLoad() {
        Task { [weak self] in
            await self?.presentRefreshLocationPermissionStatus()
        }
        startUpdates()
    }

    func presentViewDidAppear() {
        Task { [weak self] in
            await self?.presentRefreshLocationPermissionStatus()
        }
        startUpdates()
    }

    func presentRetryCurrent() {
        Task { [weak self] in
            await self?.fetchOnlyCurrentSection()
        }
    }

    func presentRetryForecast() {
        Task { [weak self] in
            await self?.fetchOnlyForecastSection()
        }
    }

    func presentViewDidDisappear() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    private func startUpdates() {
        updatesTask?.cancel()

        updatesTask = Task { [weak self] in
            while !Task.isCancelled {
                if let self {
                    await self.fetchCycle()
                } else {
                    break
                }
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    break
                }
            }
        }
    }

    private func fetchCycle() async {
        let resolution = await resolveCoordinate()

        await MainActor.run {
            self.view?.displayCurrentLoading(true)
            self.view?.displayForecastLoading(true)
            self.view?.displayCurrentErrorHidden()
            self.view?.displayForecastErrorHidden()
        }

        await withTaskGroup(of: SectionResult.self) { group in
            group.addTask { [weak self] in
                guard let self else { return .current(.failure(CancellationError())) }
                return await self.loadCurrent(for: resolution)
            }

            group.addTask { [weak self] in
                guard let self else { return .forecast(.failure(CancellationError())) }
                return await self.loadForecast(for: resolution)
            }

            for await result in group {
                switch result {
                case .current(.success(let model)):
                    await MainActor.run {
                        self.view?.displayCurrentWeather(model)
                        self.view?.displayCurrentLoading(false)
                        self.view?.displayCurrentErrorHidden()
                    }
                case .forecast(.success(let model)):
                    await MainActor.run {
                        self.view?.displayForecast(model)
                        self.view?.displayForecastLoading(false)
                        self.view?.displayForecastErrorHidden()
                    }
                case .current(.failure(_)):
                    await MainActor.run {
                        self.view?.displayCurrentLoading(false)
                        self.view?.displayCurrentError(message: "Не удалось загрузить текущую погоду")
                    }
                case .forecast(.failure(_)):
                    await MainActor.run {
                        self.view?.displayForecastLoading(false)
                        self.view?.displayForecastError(message: "Не удалось загрузить прогноз")
                    }
                }
            }
        }
    }

    private func fetchOnlyCurrentSection() async {
        let resolution = await resolveCoordinate()
        await MainActor.run {
            self.view?.displayCurrentLoading(true)
            self.view?.displayCurrentErrorHidden()
        }

        let result = await loadCurrent(for: resolution)
        switch result {
        case .current(.success(let model)):
            await MainActor.run {
                self.view?.displayCurrentWeather(model)
                self.view?.displayCurrentLoading(false)
                self.view?.displayCurrentErrorHidden()
            }
        case .current(.failure):
            await MainActor.run {
                self.view?.displayCurrentLoading(false)
                self.view?.displayCurrentError(message: "Не удалось загрузить текущую погоду")
            }
        case .forecast:
            break
        }
    }

    private func fetchOnlyForecastSection() async {
        let resolution = await resolveCoordinate()
        await MainActor.run {
            self.view?.displayForecastLoading(true)
            self.view?.displayForecastErrorHidden()
        }

        let result = await loadForecast(for: resolution)
        switch result {
        case .forecast(.success(let model)):
            await MainActor.run {
                self.view?.displayForecast(model)
                self.view?.displayForecastLoading(false)
                self.view?.displayForecastErrorHidden()
            }
        case .forecast(.failure):
            await MainActor.run {
                self.view?.displayForecastLoading(false)
                self.view?.displayForecastError(message: "Не удалось загрузить прогноз")
            }
        case .current:
            break
        }
    }

    private func loadCurrent(for resolution: LocationResolution) async -> SectionResult {
        do {
            let response = try await fetchCurrentResponse(for: resolution)
            let model = WeatherModelMapper.makeCurrent(
                from: response.data,
                isFromDeviceLocation: response.isFromDevice
            )
            return .current(.success(model))
        } catch {
            return .current(.failure(error))
        }
    }

    private func loadForecast(for resolution: LocationResolution) async -> SectionResult {
        do {
            let response = try await fetchForecastResponse(for: resolution)
            return .forecast(.success(WeatherModelMapper.makeForecast(from: response)))
        } catch {
            return .forecast(.failure(error))
        }
    }

    private func fetchCurrentResponse(for resolution: LocationResolution) async throws -> CurrentPayload {
        if resolution.isFromDevice {
            do {
                let current = try await weatherNetworkService.fetchCurrent(for: resolution.coordinate)
                return CurrentPayload(data: current, isFromDevice: true)
            } catch {
                let defaultCurrent = try await weatherNetworkService.fetchCurrent(for: defaultCoordinate)
                return CurrentPayload(data: defaultCurrent, isFromDevice: false)
            }
        }

        let current = try await weatherNetworkService.fetchCurrent(for: resolution.coordinate)
        return CurrentPayload(data: current, isFromDevice: false)
    }

    private func fetchForecastResponse(for resolution: LocationResolution) async throws -> ForecastResponse {
        if resolution.isFromDevice {
            do {
                return try await weatherNetworkService.fetchForecast(for: resolution.coordinate, days: 3)
            } catch {
                return try await weatherNetworkService.fetchForecast(for: defaultCoordinate, days: 3)
            }
        }

        return try await weatherNetworkService.fetchForecast(for: resolution.coordinate, days: 3)
    }

    private func resolveCoordinate() async -> LocationResolution {
        return await locationService.currentCoordinate()
    }

    private func presentRefreshLocationPermissionStatus() async {
        let isGranted = await locationService.isLocationAccessGranted()
        let state: LocationAccessState = isGranted ? .granted : .denied
        await MainActor.run {
            self.view?.displayLocationAccess(state: state)
        }
    }

    private func observeLocationAccessChanges() {
        guard locationAccessObserver == nil else { return }

        locationAccessObserver = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.presentRefreshLocationPermissionStatus()
                }
                self?.startUpdates()
            }
    }

    deinit {
        updatesTask?.cancel()
        locationAccessObserver?.cancel()
    }
}
