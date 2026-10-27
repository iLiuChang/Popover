//
//  Popover.swift
//  SwiftPopover
//
//  Created by LC on 2025/1/7.
//

import UIKit

/// The side of the anchor on which the popover appears.
public enum PopoverDirection {
    /// Above the anchor, with the arrow on the bottom edge pointing down.
    case up
    /// Below the anchor, with the arrow on the top edge pointing up.
    case down
    /// To the left of the anchor, with the arrow on the right edge pointing right.
    case left
    /// To the right of the anchor, with the arrow on the left edge pointing left.
    case right
}

/// Receives lifecycle callbacks from a `Popover`. All methods are optional.
public protocol PopoverDelegate : AnyObject {
    /// Called right before the show animation starts.
    func willShowPopover(_ popover: Popover)
    /// Called right before the dismiss animation starts.
    func willDismissPopover(_ popover: Popover)
    /// Called after the show animation finishes. Not called if the popover starts dismissing first.
    func didShowPopover(_ popover: Popover)
    /// Called after the popover has been removed from the view hierarchy.
    func didDismissPopover(_ popover: Popover)
}

public extension PopoverDelegate {
    func willShowPopover(_ popover: Popover) {}
    func willDismissPopover(_ popover: Popover) {}
    func didShowPopover(_ popover: Popover) {}
    func didDismissPopover(_ popover: Popover) {}
}

/// A bubble with an arrow that displays a custom content view next to an anchor.
open class Popover: UIView {

    /// Size of the arrow. `width` is the length of the arrow's base along the bubble edge,
    /// `height` is how far the arrow sticks out of the bubble. Use `.zero` to hide the arrow.
    open var arrowSize: CGSize = CGSize(width: 16.0, height: 10.0)

    /// Duration of the show animation, in seconds.
    open var showDuration: TimeInterval = 0.6

    /// Duration of the dismiss animation, in seconds.
    open var dismissDuration: TimeInterval = 0.3

    /// Corner radius of the bubble and of the content view.
    open var cornerRadius: CGFloat = 6.0

    /// Minimum distance between the bubble and the edges of the container, when the bubble fits.
    open var edgeMargin: CGFloat = 20

    /// The side of the anchor on which the popover appears.
    ///
    /// When `nil`, `.down` or `.up` is picked automatically every time the popover is laid out:
    /// `.down` if the content fits below the anchor, otherwise whichever side has more room.
    open var direction: PopoverDirection?

    /// Fill color of the bubble, including the arrow.
    open var fillColor: UIColor = UIColor.white

    /// Whether `overlayView` is added behind the popover while it is shown.
    open var showOverlay: Bool = true

    /// Damping ratio of the spring show animation, from 0 to 1.
    open var springDamping: CGFloat = 0.7

    /// Initial velocity of the spring show animation.
    open var initialSpringVelocity: CGFloat = 3

    /// Gap between the anchor view and the tip of the arrow. Only used by `show(from:in:)`.
    open var arrowSpacing: CGFloat = 6

    /// The object that receives show and dismiss callbacks.
    open weak var delegate: PopoverDelegate?

    /// Full-screen view placed behind the popover when `showOverlay` is `true`.
    ///
    /// Tapping it calls `dismiss()`. To keep the popover open on outside taps, remove that target:
    /// `overlayView.removeTarget(popover, action: #selector(Popover.dismiss), for: .touchUpInside)`.
    public let overlayView = UIControl()

    private let contentView: UIView
    private let layoutObserver = LayoutObserverView()
    private weak var containerView: UIView?
    private weak var sourceView: UIView?
    private var anchorRect: CGRect = .zero
    private var anchorOffset: CGFloat = 0
    private var contentSize: CGSize = .zero
    private var currentDirection: PopoverDirection = .down
    private var arrowTip: CGPoint = .zero
    private var contentConstraints: [NSLayoutConstraint] = []
    private var presentationID = 0
    private var isDismissing = false

    /// Creates a popover that hosts `contentView`.
    ///
    /// - Parameter contentView: The view displayed inside the bubble. Its `frame.size` at the time
    ///   `show` is called determines the size of the bubble, not counting the arrow.
    public init(contentView: UIView) {
        self.contentView = contentView
        super.init(frame: .zero)
        self.contentView.backgroundColor = UIColor.clear
        self.backgroundColor = .clear
        self.isOpaque = false
        self.contentMode = .redraw
        self.accessibilityViewIsModal = true

        self.overlayView.backgroundColor = UIColor(white: 0.0, alpha: 0.2)
        self.overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.overlayView.addTarget(self, action: #selector(dismiss), for: .touchUpInside)

        self.layoutObserver.isUserInteractionEnabled = false
        self.layoutObserver.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.layoutObserver.onSizeChange = { [weak self] in
            self?.containerDidResize()
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the popover with its arrow pointing at `fromView`.
    ///
    /// If the popover is already visible, it is removed immediately and shown again at the new position.
    /// The popover follows `fromView` when the size of `inView` changes, for example on rotation.
    ///
    /// - Parameters:
    ///   - fromView: The anchor view. It must be in the same window as `inView`.
    ///   - inView: The container the popover is added to, usually the view controller's view.
    open func show(from fromView: UIView, in inView: UIView) {
        let rect = inView.convert(fromView.bounds, from: fromView)
        self.present(anchorRect: rect, offset: self.arrowSpacing, sourceView: fromView, in: inView)
    }

    /// Shows the popover with the tip of its arrow at `point`.
    ///
    /// If the popover is already visible, it is removed immediately and shown again at the new position.
    ///
    /// - Parameters:
    ///   - point: The position of the arrow tip, in the coordinate space of `inView`.
    ///   - inView: The container the popover is added to, usually the view controller's view.
    open func show(point: CGPoint, in inView: UIView) {
        self.present(anchorRect: CGRect(origin: point, size: .zero), offset: 0, sourceView: nil, in: inView)
    }

    /// Dismisses the popover with VoiceOver's escape gesture.
    open override func accessibilityPerformEscape() -> Bool {
        self.dismiss()
        return true
    }

    /// Hides the popover with an animation and removes it from the view hierarchy.
    ///
    /// Does nothing if the popover is not shown or is already being dismissed.
    @objc open func dismiss() {
        guard self.superview != nil, !self.isDismissing else {
            return
        }
        self.isDismissing = true
        self.delegate?.willDismissPopover(self)
        let id = self.presentationID
        UIView.animate(withDuration: self.dismissDuration, delay: 0,
                       options: .beginFromCurrentState,
                       animations: {
            self.transform = CGAffineTransform(scaleX: 0.0001, y: 0.0001)
            self.overlayView.alpha = 0
        }) { _ in
            guard id == self.presentationID else {
                return
            }
            self.isDismissing = false
            self.cleanUp()
            self.delegate?.didDismissPopover(self)
        }
    }

    override open func draw(_ rect: CGRect) {
        super.draw(rect)
        self.fillColor.setFill()
        self.bubblePath().fill()
    }
}

private extension Popover {

    func present(anchorRect: CGRect, offset: CGFloat, sourceView: UIView?, in container: UIView) {
        if self.superview != nil {
            self.removeImmediately()
        }

        self.presentationID += 1
        self.isDismissing = false
        self.containerView = container
        self.sourceView = sourceView
        self.anchorRect = anchorRect
        self.anchorOffset = offset
        self.contentSize = self.contentView.frame.size

        self.layoutObserver.frame = container.bounds
        container.addSubview(self.layoutObserver)
        if self.showOverlay {
            self.overlayView.frame = container.bounds
            self.overlayView.alpha = 0
            container.addSubview(self.overlayView)
        }

        self.contentView.layer.cornerRadius = self.cornerRadius
        self.contentView.layer.masksToBounds = true
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.contentView)
        container.addSubview(self)

        self.transform = .identity
        self.updateLayout()
        self.layoutIfNeeded()

        self.transform = CGAffineTransform(scaleX: 0.0001, y: 0.0001)
        self.delegate?.willShowPopover(self)
        let id = self.presentationID
        UIView.animate(
            withDuration: self.showDuration,
            delay: 0,
            usingSpringWithDamping: self.springDamping,
            initialSpringVelocity: self.initialSpringVelocity,
            options: UIView.AnimationOptions(),
            animations: {
                self.transform = CGAffineTransform.identity
            }) { _ in
                guard id == self.presentationID, !self.isDismissing else {
                    return
                }
                self.delegate?.didShowPopover(self)
            }
        if self.showOverlay {
            UIView.animate(
                withDuration: self.showDuration / 3,
                delay: 0,
                options: .curveLinear,
                animations: {
                    self.overlayView.alpha = 1
                }, completion: nil)
        }
    }

    func removeImmediately() {
        if !self.isDismissing {
            self.delegate?.willDismissPopover(self)
        }
        self.isDismissing = false
        self.cleanUp()
        self.layer.removeAllAnimations()
        self.overlayView.layer.removeAllAnimations()
        self.delegate?.didDismissPopover(self)
    }

    func cleanUp() {
        // Invalidate completion handlers of animations that are still running.
        self.presentationID += 1
        NSLayoutConstraint.deactivate(self.contentConstraints)
        self.contentConstraints = []
        self.contentView.removeFromSuperview()
        self.overlayView.removeFromSuperview()
        self.layoutObserver.removeFromSuperview()
        self.removeFromSuperview()
        self.transform = CGAffineTransform.identity
        self.containerView = nil
        self.sourceView = nil
    }

    func containerDidResize() {
        // Wait for the container's subviews (including the anchor view) to finish their own layout.
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.superview != nil, !self.isDismissing,
                  let container = self.containerView else {
                return
            }
            if let source = self.sourceView, source.window != nil, source.window == container.window {
                self.anchorRect = container.convert(source.bounds, from: source)
            }
            self.updateLayout()
        }
    }

    func updateLayout() {
        guard let container = self.containerView else {
            return
        }
        let containerBounds = container.bounds
        let direction = self.resolvedDirection(in: containerBounds)
        self.currentDirection = direction

        let point = self.arrowPoint(for: direction)
        var size = self.contentSize
        let origin: CGPoint
        switch direction {
        case .up:
            size.height += self.arrowSize.height
            origin = CGPoint(
                x: self.clamped(point.x - size.width * 0.5, length: size.width,
                                lower: containerBounds.minX, upper: containerBounds.maxX),
                y: point.y - size.height)
        case .down:
            size.height += self.arrowSize.height
            origin = CGPoint(
                x: self.clamped(point.x - size.width * 0.5, length: size.width,
                                lower: containerBounds.minX, upper: containerBounds.maxX),
                y: point.y)
        case .left:
            size.width += self.arrowSize.height
            origin = CGPoint(
                x: point.x - size.width,
                y: self.clamped(point.y - size.height * 0.5, length: size.height,
                                lower: containerBounds.minY, upper: containerBounds.maxY))
        case .right:
            size.width += self.arrowSize.height
            origin = CGPoint(
                x: point.x,
                y: self.clamped(point.y - size.height * 0.5, length: size.height,
                                lower: containerBounds.minY, upper: containerBounds.maxY))
        }
        self.arrowTip = CGPoint(x: point.x - origin.x, y: point.y - origin.y)

        var anchorPoint: CGPoint
        switch direction {
        case .up:
            anchorPoint = CGPoint(x: self.arrowTip.x / size.width, y: 1)
        case .down:
            anchorPoint = CGPoint(x: self.arrowTip.x / size.width, y: 0)
        case .left:
            anchorPoint = CGPoint(x: 1, y: self.arrowTip.y / size.height)
        case .right:
            anchorPoint = CGPoint(x: 0, y: self.arrowTip.y / size.height)
        }
        if self.arrowSize == .zero || size.width <= 0 || size.height <= 0 {
            anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }
        anchorPoint.x = min(max(anchorPoint.x, 0), 1)
        anchorPoint.y = min(max(anchorPoint.y, 0), 1)

        // Position through bounds and center, which stay valid while a transform is applied.
        self.layer.anchorPoint = anchorPoint
        self.bounds = CGRect(origin: .zero, size: size)
        self.center = CGPoint(x: origin.x + anchorPoint.x * size.width,
                              y: origin.y + anchorPoint.y * size.height)

        self.updateContentConstraints()
        self.setNeedsDisplay()
    }

    func resolvedDirection(in containerBounds: CGRect) -> PopoverDirection {
        if let direction = self.direction {
            return direction
        }
        let requiredHeight = self.contentSize.height + self.arrowSize.height + self.anchorOffset
        let spaceBelow = containerBounds.maxY - self.anchorRect.maxY
        let spaceAbove = self.anchorRect.minY - containerBounds.minY
        if spaceBelow >= requiredHeight || spaceBelow >= spaceAbove {
            return .down
        }
        return .up
    }

    func arrowPoint(for direction: PopoverDirection) -> CGPoint {
        let rect = self.anchorRect
        switch direction {
        case .up:
            return CGPoint(x: rect.midX, y: rect.minY - self.anchorOffset)
        case .down:
            return CGPoint(x: rect.midX, y: rect.maxY + self.anchorOffset)
        case .left:
            return CGPoint(x: rect.minX - self.anchorOffset, y: rect.midY)
        case .right:
            return CGPoint(x: rect.maxX + self.anchorOffset, y: rect.midY)
        }
    }

    func clamped(_ value: CGFloat, length: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        let available = upper - lower
        guard length < available else {
            return lower + (available - length) * 0.5
        }
        let margin = min(self.edgeMargin, (available - length) * 0.5)
        return min(max(value, lower + margin), upper - length - margin)
    }

    func updateContentConstraints() {
        NSLayoutConstraint.deactivate(self.contentConstraints)
        let extent = self.arrowSize.height
        var insets = UIEdgeInsets.zero
        switch self.currentDirection {
        case .up:
            insets.bottom = extent
        case .down:
            insets.top = extent
        case .left:
            insets.right = extent
        case .right:
            insets.left = extent
        }
        self.contentConstraints = [
            self.contentView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: insets.left),
            self.contentView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -insets.right),
            self.contentView.topAnchor.constraint(equalTo: self.topAnchor, constant: insets.top),
            self.contentView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -insets.bottom)
        ]
        NSLayoutConstraint.activate(self.contentConstraints)
    }

    func bubblePath() -> UIBezierPath {
        let direction = self.currentDirection
        let extent = self.arrowSize.height
        var body = self.bounds
        switch direction {
        case .up:
            body.size.height -= extent
        case .down:
            body.origin.y += extent
            body.size.height -= extent
        case .left:
            body.size.width -= extent
        case .right:
            body.origin.x += extent
            body.size.width -= extent
        }

        let path = UIBezierPath()
        guard body.width > 0, body.height > 0 else {
            return path
        }
        let radius = max(0, min(self.cornerRadius, body.width * 0.5, body.height * 0.5))

        // Keep the arrow base off the rounded corners; the tip still points at the anchor.
        let isHorizontalEdge = direction == .up || direction == .down
        let edgeStart = isHorizontalEdge ? body.minX : body.minY
        let edgeEnd = isHorizontalEdge ? body.maxX : body.maxY
        let halfBase = min(self.arrowSize.width * 0.5, (edgeEnd - edgeStart) * 0.5 - radius)
        let hasArrow = extent > 0 && halfBase > 0
        let tipAlongEdge = isHorizontalEdge ? self.arrowTip.x : self.arrowTip.y
        let baseCenter = min(max(tipAlongEdge, edgeStart + radius + halfBase), edgeEnd - radius - halfBase)
        let tip: CGPoint
        switch direction {
        case .up:
            tip = CGPoint(x: min(max(self.arrowTip.x, self.bounds.minX), self.bounds.maxX), y: self.bounds.maxY)
        case .down:
            tip = CGPoint(x: min(max(self.arrowTip.x, self.bounds.minX), self.bounds.maxX), y: self.bounds.minY)
        case .left:
            tip = CGPoint(x: self.bounds.maxX, y: min(max(self.arrowTip.y, self.bounds.minY), self.bounds.maxY))
        case .right:
            tip = CGPoint(x: self.bounds.minX, y: min(max(self.arrowTip.y, self.bounds.minY), self.bounds.maxY))
        }

        func addArrow(on side: PopoverDirection, from start: CGPoint, to end: CGPoint) {
            guard hasArrow, direction == side else {
                return
            }
            path.addLine(to: start)
            path.addLine(to: tip)
            path.addLine(to: end)
        }

        // Clockwise, starting at the end of the top-left corner.
        path.move(to: CGPoint(x: body.minX + radius, y: body.minY))
        addArrow(on: .down,
                 from: CGPoint(x: baseCenter - halfBase, y: body.minY),
                 to: CGPoint(x: baseCenter + halfBase, y: body.minY))
        path.addLine(to: CGPoint(x: body.maxX - radius, y: body.minY))
        path.addArc(withCenter: CGPoint(x: body.maxX - radius, y: body.minY + radius),
                    radius: radius, startAngle: -.pi * 0.5, endAngle: 0, clockwise: true)

        addArrow(on: .left,
                 from: CGPoint(x: body.maxX, y: baseCenter - halfBase),
                 to: CGPoint(x: body.maxX, y: baseCenter + halfBase))
        path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - radius))
        path.addArc(withCenter: CGPoint(x: body.maxX - radius, y: body.maxY - radius),
                    radius: radius, startAngle: 0, endAngle: .pi * 0.5, clockwise: true)

        addArrow(on: .up,
                 from: CGPoint(x: baseCenter + halfBase, y: body.maxY),
                 to: CGPoint(x: baseCenter - halfBase, y: body.maxY))
        path.addLine(to: CGPoint(x: body.minX + radius, y: body.maxY))
        path.addArc(withCenter: CGPoint(x: body.minX + radius, y: body.maxY - radius),
                    radius: radius, startAngle: .pi * 0.5, endAngle: .pi, clockwise: true)

        addArrow(on: .right,
                 from: CGPoint(x: body.minX, y: baseCenter + halfBase),
                 to: CGPoint(x: body.minX, y: baseCenter - halfBase))
        path.addLine(to: CGPoint(x: body.minX, y: body.minY + radius))
        path.addArc(withCenter: CGPoint(x: body.minX + radius, y: body.minY + radius),
                    radius: radius, startAngle: .pi, endAngle: .pi * 1.5, clockwise: true)

        path.close()
        return path
    }
}

/// Invisible view that tracks the container's size through autoresizing.
private final class LayoutObserverView: UIView {

    var onSizeChange: (() -> Void)?
    private var lastSize: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        guard self.bounds.size != self.lastSize else {
            return
        }
        self.lastSize = self.bounds.size
        self.onSizeChange?()
    }
}
