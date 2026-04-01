//
//  WeatherModel.swift
//  weatherapp
//
//  Created by Альберт Ражапов on 01.04.2026.
//

import Foundation
import UIKit

struct HourlyItem {
    let dayText: String
    let timeText: String
    let temperatureText: String
    let iconURL: URL?
    let defaultIconName: String
}

struct DailyItem {
    let dayText: String
    let minTempText: String
    let maxTempText: String
    let conditionText: String
    let iconURL: URL?
    let defaultIconName: String
}

struct CurrentWeatherModel {
    let city: String
    let temperatureText: String
    let conditionText: String
    let iconURL: URL?
    let defaultIconName: String
    let theme: WeatherTheme
    let isFromDeviceLocation: Bool
}

struct ForecastWeatherModel {
    let hourlyItems: [HourlyItem]
    let dailyItems: [DailyItem]
}

enum WeatherModelMapper {
    static func makeCurrent(
        from response: CurrentWeatherResponse,
        isFromDeviceLocation: Bool
    ) -> CurrentWeatherModel {
        let city = response.location?.name ?? "Нет данных"
        let current = response.current
        let tempValue = current?.tempC ?? 0
        let conditionText = current?.condition?.text ?? "Нет данных"
        let conditionCode = current?.condition?.code ?? -1
        let conditionIcon = current?.condition?.icon
        let theme = WeatherTheme(conditionCode: conditionCode)

        return CurrentWeatherModel(
            city: city,
            temperatureText: "\(Int(tempValue.rounded()))°",
            conditionText: conditionText,
            iconURL: iconURL(from: conditionIcon),
            defaultIconName: WeatherTheme.defaultIconName(conditionCode: conditionCode),
            theme: theme,
            isFromDeviceLocation: isFromDeviceLocation
        )
    }

    static func makeForecast(from response: ForecastResponse) -> ForecastWeatherModel {
        let nowEpoch = response.location?.localTimeEpoch ?? Int(Date().timeIntervalSince1970)
        let nowDate = Date(timeIntervalSince1970: TimeInterval(nowEpoch))
        let calendar = Calendar.current
        let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: nowDate)

        let days = response.forecast?.days ?? []

        let hourlyItems = days
            .flatMap { $0.hours ?? [] }
            .filter {
                guard let timeEpoch = $0.timeEpoch else { return false }
                let hourDate = Date(timeIntervalSince1970: TimeInterval(timeEpoch))
                let isTodayAndUpcoming = calendar.isDate(hourDate, inSameDayAs: nowDate) && timeEpoch >= nowEpoch
                let isTomorrow = tomorrowDate.map { calendar.isDate(hourDate, inSameDayAs: $0) } ?? false
                return isTodayAndUpcoming || isTomorrow
            }
            .map {
                let timeEpoch = $0.timeEpoch ?? nowEpoch
                let tempValue = $0.tempC ?? 0
                let conditionCode = $0.condition?.code ?? -1
                let conditionIcon = $0.condition?.icon

                return HourlyItem(
                    dayText: dayText(from: timeEpoch, nowEpoch: nowEpoch),
                    timeText: hourText(from: timeEpoch),
                    temperatureText: "\(Int(tempValue.rounded()))°",
                    iconURL: iconURL(from: conditionIcon),
                    defaultIconName: WeatherTheme.defaultIconName(conditionCode: conditionCode)
                )
            }

        let dailyItems = days
            .prefix(3)
            .map {
                let dateEpoch = $0.dateEpoch ?? nowEpoch
                let minTemp = $0.day?.minTempC ?? 0
                let maxTemp = $0.day?.maxTempC ?? 0
                let conditionText = $0.day?.condition?.text ?? "Нет данных"
                let conditionCode = $0.day?.condition?.code ?? -1
                let conditionIcon = $0.day?.condition?.icon

                return DailyItem(
                    dayText: shortWeekdayText(from: dateEpoch),
                    minTempText: "\(Int(minTemp.rounded()))°",
                    maxTempText: "\(Int(maxTemp.rounded()))°",
                    conditionText: conditionText,
                    iconURL: iconURL(from: conditionIcon),
                    defaultIconName: WeatherTheme.defaultIconName(conditionCode: conditionCode)
                )
            }

        return ForecastWeatherModel(hourlyItems: hourlyItems, dailyItems: dailyItems)
    }

    private static func iconURL(from value: String?) -> URL? {
        guard let value else { return nil }
        if value.hasPrefix("//") {
            return URL(string: "https:\(value)")
        }
        return URL(string: value)
    }

    private static func hourText(from epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func dayText(from epoch: Int, nowEpoch: Int) -> String {
        let calendar = Calendar.current
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let nowDate = Date(timeIntervalSince1970: TimeInterval(nowEpoch))
        if calendar.isDate(date, inSameDayAs: nowDate) {
            return "Сегодня"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: nowDate),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Завтра"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitalized
    }

    private static func shortWeekdayText(from epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitalized
    }

}
