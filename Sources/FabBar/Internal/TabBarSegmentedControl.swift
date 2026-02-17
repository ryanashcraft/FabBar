import UIKit

/// A UISegmentedControl subclass customized for use as a tab bar replacement.
///
/// This subclass provides four key customizations:
///
/// 1. **Hidden images**: Hides all background/separator images while preserving the selected segment indicator.
///
/// 2. **Immediate glass effect on touch down**: By default, UISegmentedControl only shows
///    the interactive glass hover effect when dragging from the currently selected segment.
///    This subclass overrides touch handling to move the indicator immediately on touch down,
///    which triggers the glass effect animation for any segment tap—matching the behavior
///    of UITabBar. The actual selection change is deferred until touch up via `sendActions(for:)`.
///
/// 3. **Reselection callback**: Notifies when user taps an already-selected segment.
@available(iOS 26.0, *)
final class TabBarSegmentedControl: UISegmentedControl {
    /// The segment index before touch began, used to restore on cancel and detect actual changes.
    private var originalIndex: Int?

    override init(items: [Any]?) {
        super.init(items: items)
        // Note: .tabBar trait doesn't affect VoiceOver announcements on UISegmentedControl,
        // but it's set here for semantic correctness since this control functions as a tab bar.
        accessibilityTraits = .tabBar
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Called when user taps the already-selected segment.
    var onReselect: ((Int) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        hideSegmentBackgrounds()
    }

    // MARK: - Background Image Hiding

    /// Hides all segment background and separator images.
    ///
    /// UISegmentedControl uses UIImageView subviews for backgrounds, separators,
    /// and selection indicators. We hide all of them because:
    /// - The glass effect comes from UIGlassEffect on the parent view, not from these images
    /// - Segmented control comes with a default background tint which we don't want to mimic the standard tab bar appearance
    private func hideSegmentBackgrounds() {
        for subview in subviews where subview is UIImageView {
            subview.alpha = 0
        }
    }

    private func segmentIndex(at point: CGPoint) -> Int {
        guard numberOfSegments > 0 else { return 0 }
        let segmentWidth = bounds.width / CGFloat(numberOfSegments)
        return min(max(Int(point.x / segmentWidth), 0), numberOfSegments - 1)
    }

    /// Whether to use custom touch handling for immediate glass effect feedback.
    /// Disabled for accessibility content sizes to preserve standard behavior.
    private var useCustomTouchHandling: Bool {
        !traitCollection.preferredContentSizeCategory.isAccessibilityCategory
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard useCustomTouchHandling, let touch = touches.first else {
            super.touchesBegan(touches, with: event)
            return
        }

        originalIndex = selectedSegmentIndex
        let newIndex = segmentIndex(at: touch.location(in: self))
        selectedSegmentIndex = newIndex
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard useCustomTouchHandling, let touch = touches.first else {
            super.touchesMoved(touches, with: event)
            return
        }

        let newIndex = segmentIndex(at: touch.location(in: self))
        if selectedSegmentIndex != newIndex {
            selectedSegmentIndex = newIndex
        }
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard useCustomTouchHandling else {
            super.touchesEnded(touches, with: event)
            return
        }

        if let originalIndex {
            if selectedSegmentIndex != originalIndex {
                sendActions(for: .valueChanged)
            } else {
                // User tapped the already-selected segment
                onReselect?(selectedSegmentIndex)
            }
        }
        originalIndex = nil
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard useCustomTouchHandling else {
            super.touchesCancelled(touches, with: event)
            return
        }

        if let originalIndex {
            selectedSegmentIndex = originalIndex
        }
        originalIndex = nil
        super.touchesCancelled(touches, with: event)
    }
}
