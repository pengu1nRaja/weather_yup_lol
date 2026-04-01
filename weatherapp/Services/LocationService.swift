//
//  LocationService.swift
//  weatherapp
//
//  Created by Альберт Ражапов on 01.04.2026.
//


import CoreLocation
import Foundation

@MainActor
protocol LocationServiceProtocol: AnyObject {
    func currentCoordinate() async -> LocationResolution
    func isLocationAccessGranted() async -> Bool
}

struct LocationResolution {
    let coordinate: WeatherCoordinate
    let isFromDevice: Bool
}

@MainActor
final class LocationService: NSObject, LocationServiceProtocol {
    private let manager = CLLocationManager()

    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<WeatherCoordinate?, Never>?

    override init() {
        super.init()
        configureManager()
    }

    private func configureManager() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentCoordinate() async -> LocationResolution {
        let status = await authorizationStatus()
        guard status == .authorizedAlways || status == .authorizedWhenInUse,
              let coordinate = await requestLocation() else {
            return LocationResolution(coordinate: .moscow, isFromDevice: false)
        }
        return LocationResolution(coordinate: coordinate, isFromDevice: true)
    }

    func isLocationAccessGranted() async -> Bool {
        let status = manager.authorizationStatus
        return status == .authorizedAlways || status == .authorizedWhenInUse
    }

    private func authorizationStatus() async -> CLAuthorizationStatus {
        let status = manager.authorizationStatus
        guard status == .notDetermined else { return status }

        return await withCheckedContinuation { continuation in
            authContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestLocation() async -> WeatherCoordinate? {
        await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authContinuation?.resume(returning: manager.authorizationStatus)
        authContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
            return
        }

        locationContinuation?.resume(
            returning: WeatherCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
        )
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}
