//
//  SkeletonOverlayView.swift
//  weatherapp
//
//  Created by Альберт Ражапов on 02.04.2026.
//


import UIKit

final class SkeletonOverlayView: UIView {
    private let cornerRadius: CGFloat
    private let shimmerLayer = CAGradientLayer()
    private let maskLayer = CALayer()
    private var isAnimating = false

    init(cornerRadius: CGFloat = 14) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = UIColor(white: 1.0, alpha: 0.08)
        layer.cornerRadius = cornerRadius
        clipsToBounds = true
    }

    override init(frame: CGRect) {
        self.cornerRadius = 14
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = UIColor(white: 1.0, alpha: 0.08)
        layer.cornerRadius = cornerRadius
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shimmerLayer.frame = bounds
        maskLayer.frame = bounds
        maskLayer.cornerRadius = cornerRadius
    }

    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true

        shimmerLayer.colors = [
            UIColor(white: 1.0, alpha: 0.08).cgColor,
            UIColor(white: 1.0, alpha: 0.22).cgColor,
            UIColor(white: 1.0, alpha: 0.08).cgColor
        ]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.locations = [0, 0.5, 1]

        if shimmerLayer.superlayer == nil { layer.addSublayer(shimmerLayer) }
        shimmerLayer.mask = maskLayer

        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = 1.1
        animation.repeatCount = .infinity
        shimmerLayer.add(animation, forKey: "shimmer")
    }

    func stopAnimating() {
        isAnimating = false
        shimmerLayer.removeAllAnimations()
        shimmerLayer.removeFromSuperlayer()
    }
}
