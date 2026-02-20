import UIKit

/// A UISegmentedControl subclass customized for use as a tab bar replacement.
///
/// This subclass provides four key customizations:
///
/// 1. **Injected segment content**: Replaces the default segment labels with custom `TabItemContentView`
///    instances injected directly into each segment's view subtree. These views render via `draw(_:)` at
///    the current graphics context scale and support `NSCoding`, so the system accessibility popover
///    (which archives/unarchives segment content) gets crisp rendering at its native resolution.
///
/// 2. **Immediate glass effect on touch down**: By default, UISegmentedControl only shows
///    the interactive glass hover effect when dragging from the currently selected segment.
///    This subclass overrides touch handling to move the indicator immediately on touch down,
///    which triggers the glass effect animation for any segment tap—matching the behavior
///    of UITabBar. The actual selection change is deferred until touch up via `sendActions(for:)`.
///
/// 3. **Highlight tracking**: Reports which segment is visually highlighted during touch,
///    updating injected content view colors to match the glass indicator position.
///
/// 4. **Reselection callback**: Notifies when user taps an already-selected segment.
@available(iOS 26.0, *)
final class TabBarSegmentedControl: UISegmentedControl {
    /// The segment index before touch began, used to restore on cancel and detect actual changes.
    private var originalIndex: Int?

    /// Tag used to identify injected content views within segments.
    private static let injectedViewTag = 7_777

    /// Stored tab content views to inject into segments.
    private var contentViews: [TabItemContentView] = []

    /// The committed selected index for color purposes.
    private var colorSelectedIndex: Int = 0

    /// The index currently highlighted during touch, or nil when not touching.
    private var highlightedIndex: Int?

    /// Tint color for the selected/highlighted tab's content view.
    /// Set to a concrete color (not the dynamic `.tintColor`) to avoid auto-dimming during sheet presentation.
    var activeTintColor: UIColor = .tintColor {
        didSet { updateContentViewColors() }
    }

    /// Tint color for unselected tab content views.
    var inactiveTintColor: UIColor = .label {
        didSet { updateContentViewColors() }
    }

    /// Called when user taps the already-selected segment.
    var onReselect: ((Int) -> Void)?

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

    override func layoutSubviews() {
        super.layoutSubviews()
        hideSegmentBackgrounds()
        hideDefaultLabels()
        injectContentViewsIfNeeded()
        updateContentViewColors()
    }

    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        // UISegmentedControl may recreate labels on layout; hide them immediately.
        hideLabelsRecursively(in: subview)
    }

    // MARK: - Selection & Highlight

    /// Updates the committed selected index and refreshes content view colors.
    func setSelectedIndex(_ index: Int, animated: Bool) {
        colorSelectedIndex = index
        if highlightedIndex == nil {
            updateContentViewColors(animated: animated)
        }
    }

    /// Updates the highlighted index during touch interaction.
    private func setHighlightedIndex(_ index: Int?) {
        highlightedIndex = index
        updateContentViewColors(animated: true)
    }

    // MARK: - Content View Injection

    /// Configures the tab content views to be injected into each segment's view subtree.
    func configureContentViews(_ views: [TabItemContentView]) {
        contentViews = views
        setNeedsLayout()
    }

    /// Finds each internal segment view and injects a `TabItemContentView` as a subview.
    private func injectContentViewsIfNeeded() {
        let segmentViews = findSegmentViews()
        guard segmentViews.count == contentViews.count else { return }

        for (index, segmentView) in segmentViews.enumerated() {
            // Skip if already injected
            if segmentView.viewWithTag(Self.injectedViewTag) != nil {
                continue
            }

            let contentView = contentViews[index]
            contentView.tag = Self.injectedViewTag
            contentView.translatesAutoresizingMaskIntoConstraints = false
            segmentView.addSubview(contentView)

            NSLayoutConstraint.activate([
                contentView.centerXAnchor.constraint(equalTo: segmentView.centerXAnchor),
                contentView.centerYAnchor.constraint(equalTo: segmentView.centerYAnchor),
                contentView.widthAnchor.constraint(equalToConstant: contentView.intrinsicContentSize.width),
                contentView.heightAnchor.constraint(equalToConstant: contentView.intrinsicContentSize.height),
            ])
        }
    }

    // MARK: - Content View Colors

    /// Updates each content view's tint color based on highlight/selection state.
    private func updateContentViewColors(animated: Bool = false) {
        let activeIndex = highlightedIndex ?? colorSelectedIndex

        for (index, contentView) in contentViews.enumerated() {
            let color = index == activeIndex ? activeTintColor : inactiveTintColor
            if contentView.tintColor != color {
                if animated {
                    UIView.animate(withDuration: Constants.colorTransitionDuration) {
                        contentView.tintColor = color
                    }
                } else {
                    contentView.tintColor = color
                }
            }
        }
    }

    // MARK: - Segment Discovery

    /// Recursively finds the internal UISegment views within the control's hierarchy.
    /// In iOS 26, segments are nested several levels deep inside container views.
    private func findSegmentViews() -> [UIView] {
        var segments: [UIView] = []
        findSegments(in: self, results: &segments)
        return segments.sorted { $0.frame.origin.x < $1.frame.origin.x }
    }

    private func findSegments(in view: UIView, results: inout [UIView]) {
        for subview in view.subviews {
            if String(describing: type(of: subview)) == "UISegment" {
                results.append(subview)
            } else {
                findSegments(in: subview, results: &results)
            }
        }
    }

    // MARK: - Label Hiding

    /// Hides all default UILabels recursively within the segmented control.
    /// Skips labels inside our injected content views (identified by parent tag).
    private func hideDefaultLabels() {
        hideLabelsRecursively(in: self)
    }

    private func hideLabelsRecursively(in view: UIView) {
        if let label = view as? UILabel, label.superview?.tag != Self.injectedViewTag {
            label.isHidden = true
        }
        for subview in view.subviews {
            hideLabelsRecursively(in: subview)
        }
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

    // MARK: - Touch Handling

    private func segmentIndex(at point: CGPoint) -> Int {
        guard numberOfSegments > 0 else { return 0 }
        let segmentWidth = bounds.width / CGFloat(numberOfSegments)
        return min(max(Int(point.x / segmentWidth), 0), numberOfSegments - 1)
    }

    /// Whether to override `selectedSegmentIndex` on touch down for immediate glass indicator movement.
    /// Disabled for accessibility content sizes because it interferes with the segment popover behavior.
    private var shouldMoveIndicatorOnTouchDown: Bool {
        !traitCollection.preferredContentSizeCategory.isAccessibilityCategory
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            super.touchesBegan(touches, with: event)
            return
        }

        let newIndex = segmentIndex(at: touch.location(in: self))

        if shouldMoveIndicatorOnTouchDown {
            originalIndex = selectedSegmentIndex
            selectedSegmentIndex = newIndex
        }

        setHighlightedIndex(newIndex)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            super.touchesMoved(touches, with: event)
            return
        }

        let newIndex = segmentIndex(at: touch.location(in: self))

        if shouldMoveIndicatorOnTouchDown && selectedSegmentIndex != newIndex {
            selectedSegmentIndex = newIndex
        }

        setHighlightedIndex(newIndex)
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if shouldMoveIndicatorOnTouchDown, let originalIndex {
            if selectedSegmentIndex != originalIndex {
                sendActions(for: .valueChanged)
            } else {
                onReselect?(selectedSegmentIndex)
            }
        }
        originalIndex = nil
        setHighlightedIndex(nil)
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if shouldMoveIndicatorOnTouchDown, let originalIndex {
            selectedSegmentIndex = originalIndex
        }
        originalIndex = nil
        setHighlightedIndex(nil)
        super.touchesCancelled(touches, with: event)
    }
}
