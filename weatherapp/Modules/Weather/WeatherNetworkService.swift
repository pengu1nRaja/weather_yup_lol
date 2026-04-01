//
//  WeatherNetworkService.swift
//  weatherapp
//
//  Created by Альберт Ражапов on 02.04.2026.
//


import Foundation

protocol WeatherNetworkProtocol {
    func fetchCurrent(for coordinate: WeatherCoordinate) async throws -> CurrentWeatherResponse
    func fetchForecast(for coordinate: WeatherCoordinate, days: Int) async throws -> ForecastResponse
}

final class WeatherNetworkService: WeatherNetworkProtocol {
    private let networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }
    
    func fetchCurrent(for coordinate: WeatherCoordinate) async throws -> CurrentWeatherResponse {
        try await networkService.request(
            path: "/v1/current.json",
            queryItems: [
                URLQueryItem(name: "q", value: "\(coordinate.latitude),\(coordinate.longitude)")
            ]
        )
    }

    func fetchForecast(for coordinate: WeatherCoordinate, days: Int) async throws -> ForecastResponse {
        try await networkService.request(
            path: "/v1/forecast.json",
            queryItems: [
                URLQueryItem(name: "q", value: "\(coordinate.latitude),\(coordinate.longitude)"),
                URLQueryItem(name: "days", value: "\(days)")
            ]
        )
    }
}
