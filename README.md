# SwiftPopover

![Swift](https://img.shields.io/badge/Swift-5.3%2B-orange.svg)
![Platform](https://img.shields.io/badge/Platform-iOS%2011.0%2B-lightgrey.svg)
![Version](https://img.shields.io/badge/Version-1.1.0-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![SPM](https://img.shields.io/badge/SPM-supported-brightgreen.svg)
![CocoaPods](https://img.shields.io/badge/CocoaPods-supported-blueviolet.svg)

## Overview

A popover for iOS that draws a bubble and an arrow around any content view.

- **From a view** — `show(from:in:)` points the arrow at a view and follows it when the container resizes
- **From a point** — `show(point:in:)` points the arrow at a point in the container
- **Direction** — `.up`, `.down`, `.left`, `.right`, or automatic when `direction` is `nil`

## Features

- **Any content** — the bubble is sized from the content view's `frame.size`, not counting the arrow
- **Automatic placement** — `.down` when the content fits below the anchor, otherwise the vertical side with more room
- **Screen edges** — the bubble stays inside the container, and the arrow base stays off the rounded corners
- **Overlay** — a full-screen view behind the popover dismisses it on tap
- **Animation** — a spring when showing, a scale when dismissing
- **Delegate** — optional callbacks before and after showing and dismissing
- **Rotation** — a popover shown from a view lays itself out again when the container size changes
- **VoiceOver** — the escape gesture calls `dismiss()`

## Requirements

- iOS 11.0+
- Swift 5.3+

## Installation

### CocoaPods

```ruby
pod 'SwiftPopover'
```

Then run:

```bash
pod install
```

The CocoaPods module name is `SwiftPopover`:

```swift
import SwiftPopover
```

### Swift Package Manager

In Xcode: **File → Add Packages…** and enter:

```
https://github.com/iLiuChang/Popover.git
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/iLiuChang/Popover.git", from: "1.1.0")
]
```

The package module name is `Popover`:

```swift
import Popover
```

### Manual

1. Download the Swift files in the `Sources` folder
2. Drag them into your Xcode project

## Usage

The samples below use `import Popover`. With CocoaPods, use `import SwiftPopover` instead.

### Show from a View

The content view's `frame.size` at the time `show` is called is the size of the bubble. Give the content a clear background so `fillColor` shows through.

```swift
import Popover

let tableView = UITableView(frame: CGRect(x: 0, y: 0, width: 200, height: 132))
tableView.dataSource = self
tableView.delegate = self
tableView.isScrollEnabled = false
tableView.backgroundColor = .clear

let popover = Popover(contentView: tableView)
popover.delegate = self
popover.show(from: sender, in: view)
```

`direction` is `nil` here, so the popover appears below the button when there is room and above it otherwise. Showing it again removes the current popover immediately and presents the new one.

### Direction

```swift
popover.direction = .up
popover.arrowSpacing = 20
popover.show(from: sender, in: view)
```

| `PopoverDirection` | Placement |
|---|---|
| `.up` | Above the anchor, arrow on the bottom edge |
| `.down` | Below the anchor, arrow on the top edge |
| `.left` | To the left of the anchor, arrow on the right edge |
| `.right` | To the right of the anchor, arrow on the left edge |

`arrowSpacing` is the gap between the anchor view and the arrow tip. It applies only to `show(from:in:)`.

### Show at a Point

```swift
let point = view.convert(CGPoint(x: sender.bounds.midX, y: sender.bounds.minY), from: sender)
popover.show(point: point, in: view)
```

The arrow tip is placed on `point`. `arrowSpacing` is not applied, and the popover does not follow a view when the container resizes.

### Appearance

```swift
popover.fillColor = .white
popover.cornerRadius = 14
popover.arrowSize = CGSize(width: 22, height: 12)
popover.edgeMargin = 20
popover.showDuration = 0.6
popover.dismissDuration = 0.3
popover.springDamping = 0.7
popover.initialSpringVelocity = 3
```

`arrowSize.width` is the arrow's base and `arrowSize.height` is how far it sticks out. `arrowSize = .zero` draws no arrow. `edgeMargin` is the minimum distance kept between the bubble and the container edges when the bubble fits.

The bubble is drawn in the popover's bounds, so a shadow goes on its layer:

```swift
popover.layer.shadowColor = UIColor(red: 0.02, green: 0.24, blue: 0.13, alpha: 0.6).cgColor
popover.layer.shadowOffset = CGSize(width: 0, height: 2)
popover.layer.shadowRadius = 12
popover.layer.shadowOpacity = 1
```

### Overlay

`showOverlay` adds `overlayView` behind the popover. Its default color is black at 20% opacity, and tapping it calls `dismiss()`.

```swift
popover.overlayView.backgroundColor = .clear
```

To keep the popover open when the overlay is tapped:

```swift
popover.overlayView.removeTarget(popover, action: #selector(Popover.dismiss), for: .touchUpInside)
```

Set `showOverlay = false` to skip the overlay entirely.

### Dismiss

```swift
popover.dismiss()
```

`dismiss()` does nothing when the popover is not shown or is already dismissing. VoiceOver's escape gesture calls it too.

### Delegate

Every `PopoverDelegate` method is optional.

```swift
func willShowPopover(_ popover: Popover) {}
func didShowPopover(_ popover: Popover) {}
func willDismissPopover(_ popover: Popover) {}
func didDismissPopover(_ popover: Popover) {}
```

`didShowPopover` is not called if the popover starts dismissing before the show animation finishes.

## API Reference

### Popover

| Property / Method | Description |
|---|---|
| `init(contentView:)` | Hosts `contentView`. Its `frame.size` when `show` is called sets the bubble size, not counting the arrow. |
| `arrowSize` | Arrow base (`width`) and length (`height`). Defaults to `(16, 10)`. `.zero` hides the arrow. |
| `showDuration` | Show animation duration, in seconds. Defaults to `0.6`. |
| `dismissDuration` | Dismiss animation duration, in seconds. Defaults to `0.3`. |
| `cornerRadius` | Corner radius of the bubble and the content view. Defaults to `6`. |
| `edgeMargin` | Minimum distance from the container edges when the bubble fits. Defaults to `20`. |
| `direction` | Side of the anchor the bubble appears on. `nil` chooses `.down` or `.up` on each layout. |
| `fillColor` | Fill of the bubble, including the arrow. Defaults to white. |
| `showOverlay` | Adds `overlayView` behind the popover while it is shown. Defaults to `true`. |
| `springDamping` | Damping of the show animation, from 0 to 1. Defaults to `0.7`. |
| `initialSpringVelocity` | Initial velocity of the show animation. Defaults to `3`. |
| `arrowSpacing` | Gap between the anchor view and the arrow tip. Used by `show(from:in:)` only. Defaults to `6`. |
| `delegate` | Receives show and dismiss callbacks. |
| `overlayView` | Full-screen control behind the popover. Tapping it calls `dismiss()`. |
| `show(from:in:)` | Shows the popover pointing at a view. Follows that view when `in` resizes. |
| `show(point:in:)` | Shows the popover with the arrow tip at a point in `in`. |
| `dismiss()` | Hides the popover and removes it. Does nothing if it is hidden or already dismissing. |

### PopoverDirection

| Case | Description |
|---|---|
| `.up` | Above the anchor, arrow on the bottom edge pointing down. |
| `.down` | Below the anchor, arrow on the top edge pointing up. |
| `.left` | To the left of the anchor, arrow on the right edge pointing right. |
| `.right` | To the right of the anchor, arrow on the left edge pointing left. |

### PopoverDelegate

| Method | Description |
|---|---|
| `willShowPopover(_:)` | Called right before the show animation starts. |
| `didShowPopover(_:)` | Called after the show animation finishes. Skipped if dismissal starts first. |
| `willDismissPopover(_:)` | Called right before the dismiss animation starts. |
| `didDismissPopover(_:)` | Called after the popover has been removed. |

## Architecture

`Popover` is a `UIView`. `show(from:in:)` converts the anchor view's bounds into the container and keeps a weak reference to that view. `show(point:in:)` anchors to a zero-size rectangle at the given point.

The bubble, including the arrow, is one `UIBezierPath` filled in `draw(_:)`. The content view is pinned inside that path with constraints, leaving `arrowSize.height` on the arrow's edge. The path is built clockwise around the bubble. The arrow base is shifted along the edge so it does not enter a rounded corner, while the tip still points at the anchor.

When `direction` is `nil`, the popover uses `.down` if the content fits below the anchor, and otherwise the vertical side with more free space. `.left` and `.right` are used only when set explicitly. If the bubble fits inside the container, its origin is clamped so it stays at least `edgeMargin` points away from the edges. A bubble larger than the container is centered on that axis.

An invisible subview matches the container's bounds. When the container's size changes, a popover shown with `show(from:in:)` converts the anchor view again and lays itself out. Each presentation has an identifier, so a completion handler from an older show or dismiss animation cannot remove the popover that is on screen.

## License

MIT License. See [LICENSE](LICENSE) for details.
