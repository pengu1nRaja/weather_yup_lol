//
//  HourlyCell.swift
//  weatherapp
//
//  Created by Альберт Ражапов on 02.04.2026.
//


import SnapKit
import UIKit

final class HourlyCell: UICollectionViewCell {
    static let reuseID = "HourlyCell"

    private let dayLabel = UILabel()
    private let timeLabel = UILabel()
    private let iconView = UIImageView()
    private let tempLabel = UILabel()
    private var iconTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconTask?.cancel()
        dayLabel.text = nil
        timeLabel.text = nil
        tempLabel.text = nil
        iconView.image = nil
    }
    
    private func setupUI() {
        contentView.layer.cornerRadius = 12
        contentView.backgroundColor = UIColor(white: 1.0, alpha: 0.18)

        dayLabel.textColor = UIColor(white: 1.0, alpha: 0.9)
        dayLabel.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        dayLabel.textAlignment = .center

        timeLabel.textColor = .white
        timeLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        timeLabel.textAlignment = .center

        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit

        tempLabel.textColor = .white
        tempLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        tempLabel.textAlignment = .center

        contentView.addSubview(dayLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(iconView)
        contentView.addSubview(tempLabel)

        dayLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(6)
            $0.leading.trailing.equalToSuperview().inset(6)
        }

        timeLabel.snp.makeConstraints {
            $0.top.equalTo(dayLabel.snp.bottom).offset(2)
            $0.leading.trailing.equalToSuperview().inset(6)
        }

        iconView.snp.makeConstraints {
            $0.top.equalTo(timeLabel.snp.bottom).offset(8)
            $0.centerX.equalToSuperview()
            $0.size.equalTo(26)
        }

        tempLabel.snp.makeConstraints {
            $0.top.equalTo(iconView.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview().inset(6)
        }
    }

    func configure(with item: HourlyItem, imageLoader: WeatherIconLoader) {
        dayLabel.text = item.dayText
        timeLabel.text = item.timeText
        tempLabel.text = item.temperatureText
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
