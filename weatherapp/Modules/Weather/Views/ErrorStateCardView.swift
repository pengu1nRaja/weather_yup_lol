//
//  ErrorStateCardView.swift
//  weatherapp
//
//  Created by Альберт Ражапов on 02.04.2026.
//


import SnapKit
import UIKit

final class ErrorStateCardView: UIView {
    var onRetry: (() -> Void)?

    private let messageLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setMessage(_ text: String?) {
        messageLabel.text = text
    }

    @objc private func onRetryTap() {
        onRetry?()
    }

    private func setupUI() {
        backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        layer.cornerRadius = 16

        messageLabel.textColor = UIColor(red: 1, green: 0.86, blue: 0.86, alpha: 1)
        messageLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        retryButton.setTitle("Повторить", for: .normal)

        var buttonConfiguration = UIButton.Configuration.plain()
        buttonConfiguration.baseBackgroundColor = WeatherTheme.unknown.backgroundColor
        retryButton.configuration = buttonConfiguration
        retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        retryButton.layer.cornerRadius = 10
        retryButton.addTarget(self, action: #selector(onRetryTap), for: .touchUpInside)

        addSubview(messageLabel)
        addSubview(retryButton)

        messageLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(18)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        retryButton.snp.makeConstraints {
            $0.top.equalTo(messageLabel.snp.bottom).offset(14)
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().inset(16)
        }
    }
}
