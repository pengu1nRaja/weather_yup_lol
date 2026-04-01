//
//  WeatherAPIModels.swift
//  weatherapp
//
//  Created by Альберт Ражапов on 02.04.2026.
//

import Foundation

struct CurrentWeatherResponse: Decodable {
    let location: LocationResponse?
    let current: CurrentResponse?
}

struct ForecastResponse: Decodable {
    let location: LocationResponse?
    let forecast: Forecast?
}

struct LocationResponse: Decodable {
    let name: String?
    let localTimeEpoch: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case localTimeEpoch = "localtime_epoch"
    }
}

struct CurrentResponse: Decodable {
    let tempC: Double?
    let condition: Condition?

    enum CodingKeys: String, CodingKey {
        case tempC = "temp_c"
        case condition
    }
}

struct Forecast: Decodable {
    let days: [ForecastDay]?

    enum CodingKeys: String, CodingKey {
        case days = "forecastday"
    }
}

struct ForecastDay: Decodable {
    let dateEpoch: Int?
    let day: Day?
    let hours: [Hour]?

    enum CodingKeys: String, CodingKey {
        case dateEpoch = "date_epoch"
        case day
        case hours = "hour"
    }
}

struct Day: Decodable {
    let minTempC: Double?
    let maxTempC: Double?
    let condition: Condition?

    enum CodingKeys: String, CodingKey {
        case minTempC = "mintemp_c"
        case maxTempC = "maxtemp_c"
        case condition
    }
}

struct Hour: Decodable {
    let timeEpoch: Int?
    let tempC: Double?
    let condition: Condition?

    enum CodingKeys: String, CodingKey {
        case timeEpoch = "time_epoch"
        case tempC = "temp_c"
        case condition
    }
}

struct Condition: Decodable {
    let text: String?
    let icon: String?
    let code: Int?
}
