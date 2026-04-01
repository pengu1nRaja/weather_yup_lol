//
//  DailyCell.swift
//  weatherapp
//
//  Created by Альберт Ражапов on 02.04.2026.
//


import SnapKit
import UIKit

final class DailyCell: UITableViewCell {
    static let reuseID = "DailyCell"

    private let contentBackgroundView = UIView()
    private let dayLabel = UILabel()
    private let conditionLabel = UILabel()
    private let minTempLabel = UILabel()
    private let maxTempLabel = UILabel()
    private let iconView = UIImageView()
    private var iconTask: Task<Void, Never>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupAppearance()
        setupHierarchy()
        setupConstraints()
    }

    private func setupAppearance() {
        selectionStyle = .none
        backgroundColor = .clear
        contentBackgroundView.backgroundColor = UIColor(white: 1.0, alpha: 0.16)
        contentBackgroundView.layer.cornerRadius = 12

        dayLabel.textColor = .white
        dayLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)

        conditionLabel.textColor = UIColor(white: 1.0, alpha: 0.9)
        conditionLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)

        minTempLabel.textColor = UIColor(white: 1.0, alpha: 0.85)
        minTempLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        minTempLabel.textAlignment = .right

        maxTempLabel.textColor = .white
        maxTempLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        maxTempLabel.textAlignment = .right

        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
    }

    private func setupHierarchy() {
        contentView.addSubview(contentBackgroundView)
        contentBackgroundView.addSubview(dayLabel)
        contentBackgroundView.addSubview(conditionLabel)
        contentBackgroundView.addSubview(iconView)
        contentBackgroundView.addSubview(minTempLabel)
        contentBackgroundView.addSubview(maxTempLabel)
    }

    private func setupConstraints() {
        contentBackgroundView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(4)
            $0.trailing.leading.equalToSuperview()
        }

        dayLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(12)
            $0.top.equalToSuperview().offset(8)
        }

        conditionLabel.snp.makeConstraints {
            $0.leading.equalTo(dayLabel)
            $0.top.equalTo(dayLabel.snp.bottom).offset(2)
            $0.bottom.equalToSuperview().inset(8)
        }

        maxTempLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(12)
            $0.centerY.equalToSuperview()
            $0.width.greaterThanOrEqualTo(30)
        }

        minTempLabel.snp.makeConstraints {
            $0.trailing.equalTo(maxTempLabel.snp.leading).offset(-8)
            $0.centerY.equalToSuperview()
            $0.width.greaterThanOrEqualTo(30)
        }

        iconView.snp.makeConstraints {
            $0.trailing.equalTo(minTempLabel.snp.leading).offset(-8)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(24)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconTask?.cancel()
        dayLabel.text = nil
        conditionLabel.text = nil
        minTempLabel.text = nil
        maxTempLabel.text = nil
        iconView.image = nil
    }

    func configure(with item: DailyItem, imageLoader: WeatherIconLoader) {
        dayLabel.text = item.dayText
        conditionLabel.text = item.conditionText
        minTempLabel.text = item.minTempText
        maxTempLabel.text = item.maxTempText
        iconView.image = UIImage(systemName: item.defaultIconName)

        guard let url = item.iconURL else { return }
        iconTask?.cancel()
        iconTask = Task { [weak self] in
            let image = await imageLoader.image(for: url)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.iconView.image = image ?? UIImage(systemName: item.defaultIconName)
            }
        }
    }
}
