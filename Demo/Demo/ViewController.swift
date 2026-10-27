//
//  ViewController.swift
//  Demo
//
//  Created by LC on 2025/1/7.
//

import UIKit

class ViewController: UIViewController {

    private let items = ["Edit", "Delete", "Report"]
    private let rowHeight: CGFloat = 44

    private var popover: Popover?
    private var selectedItem: String?

    private let titleLabel = UILabel()
    private let hintLabel = UILabel()
    private let statusLabel = UILabel()

    /// Bubble color that stays readable in light and dark mode.
    private let bubbleColor = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 0.18, alpha: 1) : .white
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        titleLabel.text = "SwiftPopover"
        titleLabel.font = .boldSystemFont(ofSize: 28)
        titleLabel.textColor = .label

        hintLabel.text = "Same menu, anchored in different directions."
        hintLabel.font = .preferredFont(forTextStyle: .subheadline)
        hintLabel.textColor = .secondaryLabel
        hintLabel.numberOfLines = 0
        hintLabel.textAlignment = .center

        statusLabel.text = "Tap a button"
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center

        let autoButton = button("Auto", action: #selector(showAuto))
        let leftButton = button("Left", action: #selector(showLeft))
        let downButton = button("Down", action: #selector(showDown))
        let rightButton = button("Right", action: #selector(showRight))
        let upButton = button("Up", action: #selector(showUp))
        let pointButton = button("Point", action: #selector(showAtPoint))

        let safe = view.safeAreaLayoutGuide
        for item in [titleLabel, hintLabel, statusLabel, autoButton, leftButton, downButton, rightButton, upButton, pointButton] {
            item.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(item)
        }
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),

            hintLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            hintLabel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            hintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: safe.leadingAnchor, constant: 24),
            hintLabel.trailingAnchor.constraint(lessThanOrEqualTo: safe.trailingAnchor, constant: -24),

            autoButton.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 28),
            autoButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),

            leftButton.centerYAnchor.constraint(equalTo: autoButton.centerYAnchor),
            leftButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),

            downButton.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            downButton.centerYAnchor.constraint(equalTo: safe.centerYAnchor),

            rightButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            upButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            pointButton.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            rightButton.centerYAnchor.constraint(equalTo: pointButton.centerYAnchor),
            upButton.centerYAnchor.constraint(equalTo: pointButton.centerYAnchor),
            pointButton.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -20),

            statusLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8),
        ])
    }

    /// Direction is chosen from the free space. A wide menu near the corner keeps the arrow off the rounded corner.
    @objc private func showAuto(_ sender: UIButton) {
        let popover = makeMenu(width: 200)
        popover.overlayView.backgroundColor = .clear
        popover.layer.shadowColor = UIColor(red: 0.02, green: 0.24, blue: 0.13, alpha: 0.6).cgColor
        popover.layer.shadowOffset = CGSize(width: 0, height: 2)
        popover.layer.shadowRadius = 12
        popover.layer.shadowOpacity = 1
        present(popover, from: sender)
    }

    @objc private func showDown(_ sender: UIButton) {
        let popover = makeMenu(width: 140)
        popover.direction = .down
        popover.sideOffset = 20
        present(popover, from: sender)
    }

    /// Custom arrow size and corner radius, shown above a button that sits near the bottom edge.
    @objc private func showUp(_ sender: UIButton) {
        let popover = makeMenu(width: 160)
        popover.direction = .up
        popover.cornerRadius = 14
        popover.arrowSize = CGSize(width: 22, height: 12)
        present(popover, from: sender)
    }

    @objc private func showLeft(_ sender: UIButton) {
        let popover = makeMenu(width: 150)
        popover.direction = .left
        present(popover, from: sender)
    }

    @objc private func showRight(_ sender: UIButton) {
        let popover = makeMenu(width: 150)
        popover.direction = .right
        present(popover, from: sender)
    }

    /// `show(point:in:)` aims the arrow at a point instead of a view. No direction is set, so it is chosen automatically.
    @objc private func showAtPoint(_ sender: UIButton) {
        let popover = makeMenu(width: 160)
        popover.fillColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.13, green: 0.22, blue: 0.38, alpha: 1)
                : UIColor(red: 0.90, green: 0.95, blue: 1, alpha: 1)
        }
        let point = view.convert(CGPoint(x: sender.bounds.midX, y: sender.bounds.minY), from: sender)
        present(popover, at: point)
    }

    private func button(_ title: String, action: Selector) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeMenu(width: CGFloat) -> Popover {
        let tableView = UITableView(frame: CGRect(x: 0, y: 0, width: width, height: rowHeight * CGFloat(items.count)))
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = rowHeight
        tableView.isScrollEnabled = false
        tableView.backgroundColor = .clear
        tableView.sectionHeaderTopPadding = 0
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        let popover = Popover(contentView: tableView)
        popover.fillColor = bubbleColor
        return popover
    }

    private func present(_ popover: Popover, from anchor: UIView) {
        self.popover?.dismiss()
        popover.delegate = self
        self.popover = popover
        popover.show(from: anchor, in: view)
    }

    private func present(_ popover: Popover, at point: CGPoint) {
        self.popover?.dismiss()
        popover.delegate = self
        self.popover = popover
        popover.show(point: point, in: view)
    }
}

extension ViewController: PopoverDelegate {

    func willShowPopover(_ popover: Popover) {
        guard popover === self.popover else { return }
        statusLabel.text = "willShow"
    }

    func didShowPopover(_ popover: Popover) {
        guard popover === self.popover else { return }
        statusLabel.text = "didShow"
    }

    func willDismissPopover(_ popover: Popover) {
        guard popover === self.popover else { return }
        statusLabel.text = "willDismiss"
    }

    func didDismissPopover(_ popover: Popover) {
        guard popover === self.popover else { return }
        if let selectedItem {
            statusLabel.text = "didDismiss · \(selectedItem)"
            self.selectedItem = nil
        } else {
            statusLabel.text = "didDismiss"
        }
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "item")
            ?? UITableViewCell(style: .default, reuseIdentifier: "item")
        let title = items[indexPath.row]
        cell.backgroundColor = .clear
        cell.textLabel?.text = title
        cell.textLabel?.textColor = title == "Delete" ? .systemRed : .label
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedItem = items[indexPath.row]
        popover?.dismiss()
    }
}
