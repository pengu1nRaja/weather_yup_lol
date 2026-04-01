//
//  SceneDelegate.swift
//  weatherapp
//
//  Created by Альберт Ражапов on 02.04.2026.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)

        let networkService = NetworkService()
        let weatherNetworkService = WeatherNetworkService(networkService: networkService)
        let locationService = LocationService()
        let presenter = WeatherPresenter(
            weatherNetworkService: weatherNetworkService,
            locationService: locationService,
            defaultCoordinate: WeatherCoordinate.moscow
        )
        let viewController = WeatherViewController(presenter: presenter)
        presenter.presentAttachView(viewController)

        window.rootViewController = UINavigationController(rootViewController: viewController)
        self.window = window
        window.makeKeyAndVisible()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) { }

    func sceneDidBecomeActive(_ scene: UIScene) { }

    func sceneWillResignActive(_ scene: UIScene) { }

    func sceneWillEnterForeground(_ scene: UIScene) { }

    func sceneDidEnterBackground(_ scene: UIScene) { }
}
