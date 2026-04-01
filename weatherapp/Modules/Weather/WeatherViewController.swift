//
//  WeatherViewController.swift
//  weatherapp
//
//  Created by Альберт Ражапов on 01.04.2026.
//


import SnapKit
import UIKit

actor WeatherIconLoader {
    private let cache = NSCache<NSURL, UIImage>()

    init() {
        cache.countLimit = 200
        cache.totalCostLimit = 20 * 1024 * 1024
    }

    func image(for url: URL) async -> UIImage? {
        let key = url as NSURL

        if let image = cache.object(forKey: key) {
            return image
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            cache.setObject(image, forKey: key, cost: data.count)
            return image
        } catch {
            return nil
        }
    }
}

final class WeatherViewController: UIViewController {
    private let presenter: WeatherPresenterProtocol
    private let imageLoader = WeatherIconLoader()
    private lazy var locationStatusButton: UIButton = makeLocationStatusButton()
    private lazy var locationBarButtonItem = UIBarButtonItem(customView: locationStatusButton)

    private let currentCard: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 18
        view.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        view.clipsToBounds = true
        return view
    }()
    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = UIColor.white.withAlphaComponent(0.95)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    private let cityLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    private let locationBadgeView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "location.fill")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()
    private let tempLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 68, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    private let conditionLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private let currentSkeletonView = SkeletonOverlayView(cornerRadius: 18)
    private let currentErrorOverlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.35)
        view.isHidden = true
        return view
    }()
    private let currentErrorCardView = ErrorStateCardView()
    private let currentLoadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        return indicator
    }()

    private let forecastCard: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 18
        view.backgroundColor = UIColor(white: 1.0, alpha: 0.12)
        view.clipsToBounds = true
        return view
    }()
    private let hourlyLabel: UILabel = {
        let label = UILabel()
        label.text = "Почасовой прогноз"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        return label
    }()
    private lazy var hourlyCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 10
        layout.itemSize = CGSize(width: 96, height: 112)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        collectionView.register(HourlyCell.self, forCellWithReuseIdentifier: HourlyCell.reuseID)
        return collectionView
    }()
    private var hourlyItems: [HourlyItem] = []

    private let dailyLabel: UILabel = {
        let label = UILabel()
        label.text = "Прогноз на 3 дня"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        return label
    }()
    private let dailyTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = 60
        tableView.isScrollEnabled = false
        tableView.register(DailyCell.self, forCellReuseIdentifier: DailyCell.reuseID)
        return tableView
    }()
    private var dailyItems: [DailyItem] = []
    private var dailyTableHeightConstraint: Constraint?
    private let forecastSkeletonView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }()
    private let hourlySkeletonStack = UIStackView()
    private let dailySkeletonStack = UIStackView()
    private var hourlySkeletonItems: [SkeletonOverlayView] = []
    private var dailySkeletonItems: [SkeletonOverlayView] = []
    private let forecastErrorOverlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.35)
        view.isHidden = true
        return view
    }()
    private let forecastErrorCardView = ErrorStateCardView()
    private let forecastLoadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        return indicator
    }()

    private var currentIconTask: Task<Void, Never>?
    private let backgroundGradient = CAGradientLayer()

    private var isCurrentLoading = false
    private var isForecastLoading = false
    private var hasCurrentContent = false
    private var hasForecastContent = false
    private let defaultForecastRows = 3
    
    // MARK: - live cycles
    init(presenter: WeatherPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.presentViewDidLoad()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradient.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presenter.presentViewDidAppear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        currentIconTask?.cancel()
        if isMovingFromParent {
            presenter.presentViewDidDisappear()
        }
    }

    @objc private func didTapLocationMode() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func setupUI() {
        backgroundGradient.colors = [
            WeatherTheme.unknown.backgroundColor.cgColor,
            WeatherTheme.unknown.backgroundColor.withAlphaComponent(0.65).cgColor
        ]
        backgroundGradient.startPoint = CGPoint(x: 0, y: 0)
        backgroundGradient.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(backgroundGradient, at: 0)

        currentSkeletonView.isHidden = true
        setupForecastSkeletonPlaceholders()

        currentErrorCardView.onRetry = { [weak self] in
            self?.presenter.presentRetryCurrent()
        }

        forecastErrorCardView.onRetry = { [weak self] in
            self?.presenter.presentRetryForecast()
        }

        hourlyCollectionView.dataSource = self

        dailyTableView.dataSource = self

        view.addSubview(currentCard)
        view.addSubview(forecastCard)

        forecastCard.addSubview(hourlyLabel)
        forecastCard.addSubview(hourlyCollectionView)
        forecastCard.addSubview(dailyLabel)
        forecastCard.addSubview(dailyTableView)
        forecastCard.addSubview(forecastSkeletonView)
        forecastCard.addSubview(forecastErrorOverlayView)
        forecastCard.addSubview(forecastLoadingIndicator)

        currentCard.addSubview(iconView)
        currentCard.addSubview(cityLabel)
        currentCard.addSubview(locationBadgeView)
        currentCard.addSubview(tempLabel)
        currentCard.addSubview(conditionLabel)
        currentCard.addSubview(currentSkeletonView)
        currentCard.addSubview(currentErrorOverlayView)
        currentCard.addSubview(currentLoadingIndicator)
        currentErrorOverlayView.addSubview(currentErrorCardView)

        forecastSkeletonView.addSubview(hourlySkeletonStack)
        forecastSkeletonView.addSubview(dailySkeletonStack)
        forecastErrorOverlayView.addSubview(forecastErrorCardView)
        
        setConstraints()
        configActions()
    }
    
    private func setConstraints() {
        currentCard.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.height.equalTo(view.safeAreaLayoutGuide.snp.height).multipliedBy(0.34)
        }

        cityLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(20)
            $0.centerX.equalToSuperview()
        }

        locationBadgeView.snp.makeConstraints {
            $0.centerY.equalTo(cityLabel)
            $0.leading.equalTo(cityLabel.snp.trailing).offset(6)
            $0.size.equalTo(14)
        }

        tempLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        conditionLabel.snp.makeConstraints {
            $0.top.equalTo(tempLabel.snp.bottom).offset(6)
            $0.centerX.equalToSuperview()
        }

        iconView.snp.makeConstraints {
            $0.leading.greaterThanOrEqualTo(conditionLabel.snp.trailing)
            $0.centerY.equalTo(conditionLabel)
            $0.size.equalTo(34)
        }

        forecastCard.snp.makeConstraints {
            $0.top.equalTo(currentCard.snp.bottom).offset(18)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        hourlyLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(14)
            $0.leading.trailing.equalToSuperview().inset(12)
        }

        hourlyCollectionView.snp.makeConstraints {
            $0.top.equalTo(hourlyLabel.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(120)
        }

        dailyLabel.snp.makeConstraints {
            $0.top.equalTo(hourlyCollectionView.snp.bottom).offset(14)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        dailyTableView.snp.makeConstraints {
            $0.top.equalTo(dailyLabel.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview().inset(12)
            $0.bottom.equalToSuperview().inset(12)
            dailyTableHeightConstraint = $0.height.equalTo(CGFloat(defaultForecastRows) * dailyTableView.rowHeight).constraint
        }

        currentSkeletonView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        currentErrorOverlayView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        currentErrorCardView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        currentLoadingIndicator.snp.makeConstraints {
            $0.center.equalToSuperview()
        }

        forecastSkeletonView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        forecastErrorOverlayView.snp.makeConstraints {
            $0.edges.equalTo(forecastSkeletonView)
        }

        forecastErrorCardView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        forecastLoadingIndicator.snp.makeConstraints {
            $0.center.equalTo(forecastSkeletonView)
        }

        hourlySkeletonStack.snp.makeConstraints {
            $0.edges.equalTo(hourlyCollectionView).inset(8)
        }

        dailySkeletonStack.snp.makeConstraints {
            $0.edges.equalTo(dailyTableView).inset(4)
        }
    }
    
    private func configActions() {
        navigationItem.rightBarButtonItem = locationBarButtonItem
    }

    private func makeLocationStatusButton() -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "location.slash.fill")
        configuration.title = "Гео выкл"
        configuration.imagePadding = 6
        configuration.baseForegroundColor = .systemRed

        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        button.addTarget(self, action: #selector(didTapLocationMode), for: .touchUpInside)
        return button
    }

    private func applyTheme(_ theme: WeatherTheme, animated: Bool) {
        let changes = {
            self.backgroundGradient.colors = [
                theme.backgroundColor.cgColor,
                theme.backgroundColor.withAlphaComponent(0.65).cgColor
            ]
        }

        if animated {
            UIView.animate(withDuration: 0.35, animations: changes)
        } else {
            changes()
        }
    }

    private func updateDailyHeight() {
        let minRows = hasForecastContent ? 1 : defaultForecastRows
        let rows = max(dailyItems.count, minRows)
        let height = CGFloat(rows) * dailyTableView.rowHeight
        dailyTableHeightConstraint?.update(offset: height)
    }

    private func setupForecastSkeletonPlaceholders() {
        hourlySkeletonStack.axis = .horizontal
        hourlySkeletonStack.alignment = .fill
        hourlySkeletonStack.distribution = .fillEqually
        hourlySkeletonStack.spacing = 10

        dailySkeletonStack.axis = .vertical
        dailySkeletonStack.alignment = .fill
        dailySkeletonStack.distribution = .fillEqually
        dailySkeletonStack.spacing = 8

        for _ in 0 ..< 4 {
            let view = SkeletonOverlayView(cornerRadius: 12)
            hourlySkeletonItems.append(view)
            hourlySkeletonStack.addArrangedSubview(view)
        }

        for _ in 0 ..< defaultForecastRows {
            let view = SkeletonOverlayView(cornerRadius: 10)
            dailySkeletonItems.append(view)
            dailySkeletonStack.addArrangedSubview(view)
        }
    }
}

// MARK: - WeatherViewProtocol
extension WeatherViewController: WeatherViewProtocol {
    func displayCurrentLoading(_ isLoading: Bool) {
        isCurrentLoading = isLoading
        updateLoadingUI()
    }

    func displayForecastLoading(_ isLoading: Bool) {
        isForecastLoading = isLoading
        updateDailyHeight()
        updateLoadingUI()
    }

    func displayLocationAccess(state: LocationAccessState) {
        var configuration = locationStatusButton.configuration ?? .plain()
        switch state {
        case .granted:
            configuration.title = "Гео вкл"
            configuration.image = UIImage(systemName: "location.fill")
            configuration.baseForegroundColor = .systemGreen
        case .denied:
            configuration.title = "Гео выкл"
            configuration.image = UIImage(systemName: "location.slash.fill")
            configuration.baseForegroundColor = .systemRed
        }
        locationStatusButton.configuration = configuration
    }

    func displayCurrentWeather(_ model: CurrentWeatherModel) {
        hasCurrentContent = true
        isCurrentLoading = false
        cityLabel.text = model.city
        tempLabel.text = model.temperatureText
        conditionLabel.text = model.conditionText

        iconView.image = UIImage(systemName: model.defaultIconName)
        currentIconTask?.cancel()
        if let url = model.iconURL {
            currentIconTask = Task { [weak self] in
                let image = await self?.imageLoader.image(for: url)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.iconView.image = image ?? UIImage(systemName: model.defaultIconName)
                }
            }
        }

        locationBadgeView.isHidden = !model.isFromDeviceLocation
        applyTheme(model.theme, animated: true)
        updateLoadingUI()
    }

    func displayForecast(_ model: ForecastWeatherModel) {
        hasForecastContent = true
        isForecastLoading = false
        hourlyItems = model.hourlyItems
        hourlyCollectionView.reloadData()

        dailyItems = model.dailyItems
        updateDailyHeight()
        dailyTableView.reloadData()
        updateLoadingUI()
    }

    func displayCurrentError(message: String) {
        isCurrentLoading = false
        currentErrorCardView.setMessage(message)
        currentErrorOverlayView.isHidden = false
        updateLoadingUI()
    }

    func displayCurrentErrorHidden() {
        currentErrorOverlayView.isHidden = true
        currentErrorCardView.setMessage(nil)
    }

    func displayForecastError(message: String) {
        isForecastLoading = false
        forecastErrorCardView.setMessage(message)
        forecastErrorOverlayView.isHidden = false
        updateDailyHeight()
        updateLoadingUI()
    }

    func displayForecastErrorHidden() {
        forecastErrorOverlayView.isHidden = true
        forecastErrorCardView.setMessage(nil)
        updateDailyHeight()
    }

    private func updateLoadingUI() {
        let shouldShowCurrentSkeleton = isCurrentLoading && !hasCurrentContent
        currentSkeletonView.isHidden = !shouldShowCurrentSkeleton
        if shouldShowCurrentSkeleton {
            currentSkeletonView.startAnimating()
            currentLoadingIndicator.startAnimating()
        } else {
            currentSkeletonView.stopAnimating()
            currentLoadingIndicator.stopAnimating()
        }

        let shouldShowForecastSkeleton = isForecastLoading && !hasForecastContent
        forecastSkeletonView.isHidden = !shouldShowForecastSkeleton
        if shouldShowForecastSkeleton {
            hourlySkeletonItems.forEach { $0.startAnimating() }
            dailySkeletonItems.forEach { $0.startAnimating() }
            forecastLoadingIndicator.startAnimating()
        } else {
            hourlySkeletonItems.forEach { $0.stopAnimating() }
            dailySkeletonItems.forEach { $0.stopAnimating() }
            forecastLoadingIndicator.stopAnimating()
        }

        currentCard.alpha = isCurrentLoading && !hasCurrentContent ? 0.6 : 1.0

        let forecastAlpha: CGFloat = isForecastLoading && !hasForecastContent ? 0.6 : 1.0
        forecastCard.alpha = forecastAlpha
    }
}

// MARK: - UICollectionViewDataSource
extension WeatherViewController: UICollectionViewDataSource {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        hourlyItems.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: HourlyCell.reuseID,
                for: indexPath
            ) as? HourlyCell
        else {
            return UICollectionViewCell()
        }

        cell.configure(with: hourlyItems[indexPath.item], imageLoader: imageLoader)
        return cell
    }
}

// MARK: - UITableViewDataSource
extension WeatherViewController: UITableViewDataSource {
    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        dailyItems.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: DailyCell.reuseID, for: indexPath) as? DailyCell
        else {
            return UITableViewCell()
        }

        cell.configure(with: dailyItems[indexPath.row], imageLoader: imageLoader)
        return cell
    }
}
