//
//  NetworkService.swift
//  weatherapp
//
//  Created by Альберт Ражапов on 01.04.2026.
//


import Foundation

enum WeatherNetworkError: LocalizedError {
    case invalidURL
    case invalidResponse(message: String)
    case decodeError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Не удалось сформировать URL."
        case .invalidResponse(let message):
            return message.isEmpty ? "Сервер вернул ошибку." : message
        case .decodeError:
            return "Не удалось прочитать ответ сервера."
        }
    }
}

protocol NetworkServiceProtocol {
    func request<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T
}

struct NetworkService: NetworkServiceProtocol {
    private enum RetryPolicy {
        static let attempts = 3
        static let delayBetweenAttempts: Duration = .seconds(1)
    }

    private let session: URLSession
    private var preferredLanguageCode: String {
        Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "ru"
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    func request<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        var lastError: Error?

        for attempt in 1 ... RetryPolicy.attempts {
            do {
                return try await performRequest(path: path, queryItems: queryItems)
            } catch {
                lastError = error
                guard attempt < RetryPolicy.attempts else { break }
                try? await Task.sleep(for: RetryPolicy.delayBetweenAttempts)
            }
        }

        throw lastError ?? URLError(.cannotLoadFromNetwork)
    }

    private func performRequest<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        guard var components = URLComponents(string: AppConstants.weatherBaseURL) else {
            throw WeatherNetworkError.invalidURL
        }
        components.path = path
        let baseQueryItems = [
            URLQueryItem(name: "key", value: AppConstants.weatherAPIKey),
            URLQueryItem(name: "lang", value: preferredLanguageCode)
        ]
        components.queryItems = baseQueryItems + queryItems

        guard let url = components.url else {
            throw WeatherNetworkError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherNetworkError.invalidResponse(message: "Некорректный ответ от сервера")
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw WeatherNetworkError.invalidResponse(message: "Ошибка API: \(body)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw WeatherNetworkError.decodeError
        }
    }
}
