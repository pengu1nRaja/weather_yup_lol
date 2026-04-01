//
//  WeatherTheme.swift
//  weatherapp
//
//  Created by Альберт Ражапов on 02.04.2026.
//


import UIKit

enum WeatherTheme {
    case clear
    case cloudy
    case rainy
    case storm
    case snowy
    case unknown

    init(conditionCode: Int) {
        switch conditionCode {
        case 1000:
            self = .clear
        case 1003, 1006, 1009, 1030, 1135, 1147:
            self = .cloudy
        case 1063, 1069, 1072, 1150, 1153, 1180, 1183, 1186, 1189, 1192, 1195, 1198, 1201, 1240, 1243, 1246:
            self = .rainy
        case 1066, 1114, 1117, 1210, 1213, 1216, 1219, 1222, 1225, 1237, 1249, 1252, 1255, 1258, 1261, 1264:
            self = .snowy
        case 1087, 1273, 1276, 1279, 1282:
            self = .storm
        default:
            self = .unknown
        }
    }

    static func defaultIconName(conditionCode: Int) -> String {
        WeatherTheme(conditionCode: conditionCode).defaultIconName
    }

    var defaultIconName: String {
        switch self {
        case .clear:
            return "sun.max.fill"
        case .cloudy:
            return "cloud.fill"
        case .rainy:
            return "cloud.rain.fill"
        case .snowy:
            return "cloud.snow.fill"
        case .storm:
            return "cloud.bolt.rain.fill"
        case .unknown:
            return "cloud.sun.fill"
        }
    }
    
    var backgroundColor: UIColor {
        switch self {
        case .clear:
            return UIColor(red: 0.20, green: 0.55, blue: 0.92, alpha: 1)
        case .cloudy:
            return UIColor(red: 0.38, green: 0.47, blue: 0.56, alpha: 1)
        case .rainy:
            return UIColor(red: 0.20, green: 0.33, blue: 0.48, alpha: 1)
        case .storm:
            return UIColor(red: 0.14, green: 0.18, blue: 0.28, alpha: 1)
        case .snowy:
            return UIColor(red: 0.58, green: 0.70, blue: 0.78, alpha: 1)
        case .unknown:
            return UIColor(red: 0.24, green: 0.42, blue: 0.63, alpha: 1)
        }
    }
}
