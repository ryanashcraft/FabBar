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
/// 3. **Accent masking**: Tracks the glass indicator's animated position via `CADisplayLink`
///    and masks accent-colored content views to the indicator rect, so content under the glass
///    appears in the accent color — matching native UITabBar behavior.
///
/// 4. **Reselection callback**: Notifies when user taps an already-selected segment.
@available(iOS 26.0, *)
final class TabBarSegmentedControl: UISegmentedControl {
    /// The segment index before touch began, used to restore on cancel and detect actual changes.
    private var originalIndex: Int?

    /// Tag used to identify injected content views within segments.
    private static let injectedViewTag = 7_777
    /// Tag used to identify accent (active-colored) content views within segments.
    private static let accentViewTag = 7_778
    private static let badgeDotTag = 7_779

    /// Stored tab content views to inject into segments (always inactive color).
    private var contentViews: [TabItemContentView] = []
    /// Accent-colored duplicates, masked to the glass indicator position.
    private var accentContentViews: [TabItemContentView] = []

    /// Display link for updating accent masks each frame.
    private var displayLink: CADisplayLink?
    /// Weak proxy to avoid CADisplayLink retain cycle.
    private var displayLinkProxy: DisplayLinkProxy?

    /// Tracks indicator position stability for display link pausing.
    private var lastIndicatorRect: CGRect = .zero
    private var stableFrameCount: Int = 0
    private static let stableFrameThreshold = 3

    /// Whether the segment-frame fallback log has already been emitted.
    private var didLogFallback = false

    /// Cached reference to the internal glass indicator view. Invalidated on segment rebuild.
    private weak var cachedIndicatorView: UIView?

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
        displayLink?.isPaused = false
        stableFrameCount = 0
        hideSegmentBackgrounds()
        hideDefaultLabels()
        injectContentViewsIfNeeded()
        updateContentViewColors()
        layoutBadgeDots()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startDisplayLink()
        } else {
            stopDisplayLink()
        }
    }

    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        // UISegmentedControl may recreate labels on layout; hide them immediately.
        hideLabelsRecursively(in: subview)
    }

    // MARK: - Content View Injection

    /// Configures the tab content views to be injected into each segment's view subtree.
    /// Base views are always inactive-colored; accent views are always active-colored and
    /// masked to the glass indicator position.
    /// Updates badge dot visibility for each segment.
    /// Badge dots are added directly to segment views above both base and accent layers.
    /// Positioning is handled separately in `layoutBadgeDots()` which runs on every layout pass.
    func updateBadges(_ badges: [(show: Bool, color: UIColor?)]) {
        let segmentViews = findSegmentViews()
        for (index, badge) in badges.enumerated() {
            guard index < segmentViews.count else { continue }
            let segmentView = segmentViews[index]

            if badge.show {
                if let existing = segmentView.viewWithTag(Self.badgeDotTag) {
                    existing.backgroundColor = badge.color ?? .tintColor
                } else {
                    let dotSize = Constants.badgeDotSize
                    let dot = UIView()
                    dot.tag = Self.badgeDotTag
                    dot.backgroundColor = badge.color ?? .tintColor
                    dot.layer.cornerRadius = dotSize / 2
                    dot.layer.zPosition = 999
                    dot.isUserInteractionEnabled = false
                    segmentView.addSubview(dot)
                }
            } else {
                segmentView.viewWithTag(Self.badgeDotTag)?.removeFromSuperview()
            }
        }
        setNeedsLayout()
    }

    /// Repositions badge dots relative to their content views.
    /// Called from `layoutSubviews` so badges stay correct across rotations and resizes.
    private func layoutBadgeDots() {
        let dotSize = Constants.badgeDotSize
        for segmentView in findSegmentViews() {
            guard let dot = segmentView.viewWithTag(Self.badgeDotTag),
                  let contentView = segmentView.viewWithTag(Self.injectedViewTag) else { continue }
            let cvFrame = contentView.frame
            dot.frame = CGRect(
                x: cvFrame.maxX - dotSize / 2 + Constants.badgeOffsetX,
                y: cvFrame.minY + Constants.badgeOffsetY,
                width: dotSize,
                height: dotSize
            )
        }
    }

    /// Configures the tab content views to be injected into each segment's view subtree.
    /// Base views are always inactive-colored; accent views are always active-colored and
    /// masked to the glass indicator position.
    func configureContentViews(_ baseViews: [TabItemContentView], accentViews: [TabItemContentView]) {
        cachedIndicatorView = nil

        // Remove previously injected views from segment subtrees.
        // Uses tag-based lookup so this works even if segments were rebuilt
        // (the old tagged views will have been removed with their parent segments).
        for segmentView in findSegmentViews() {
            segmentView.viewWithTag(Self.injectedViewTag)?.removeFromSuperview()
            segmentView.viewWithTag(Self.accentViewTag)?.removeFromSuperview()
        }
        contentViews = baseViews
        accentContentViews = accentViews
        setNeedsLayout()
    }

    /// Finds each internal segment view and injects base + accent `TabItemContentView`s as subviews.
    private func injectContentViewsIfNeeded() {
        let segmentViews = findSegmentViews()
        guard segmentViews.count == contentViews.count,
              segmentViews.count == accentContentViews.count else { return }

        for (index, segmentView) in segmentViews.enumerated() {
            segmentView.clipsToBounds = false

            // Base (inactive) content view
            if segmentView.viewWithTag(Self.injectedViewTag) == nil {
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

            // Accent (active) content view on top, masked to the glass indicator
            if segmentView.viewWithTag(Self.accentViewTag) == nil {
                let accentView = accentContentViews[index]
                accentView.tag = Self.accentViewTag
                accentView.translatesAutoresizingMaskIntoConstraints = false
                segmentView.addSubview(accentView)

                NSLayoutConstraint.activate([
                    accentView.centerXAnchor.constraint(equalTo: segmentView.centerXAnchor),
                    accentView.centerYAnchor.constraint(equalTo: segmentView.centerYAnchor),
                    accentView.widthAnchor.constraint(equalToConstant: accentView.intrinsicContentSize.width),
                    accentView.heightAnchor.constraint(equalToConstant: accentView.intrinsicContentSize.height),
                ])

                // Start fully hidden; display link will reveal via mask
                let maskLayer = CAShapeLayer()
                maskLayer.path = UIBezierPath(rect: .zero).cgPath
                accentView.layer.mask = maskLayer
            }
        }
    }

    // MARK: - Content View Colors

    /// Sets base content views to inactive color and accent content views to active color.
    /// The visual accent effect is handled by masking accent views to the glass indicator.
    private func updateContentViewColors() {
        for contentView in contentViews {
            contentView.tintColor = inactiveTintColor
        }
        for accentView in accentContentViews {
            accentView.tintColor = activeTintColor
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
        if let label = view as? UILabel,
           label.superview?.tag != Self.injectedViewTag,
           label.superview?.tag != Self.accentViewTag {
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

    // MARK: - Indicator Tracking & Accent Masking

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let proxy = DisplayLinkProxy(control: self)
        displayLinkProxy = proxy
        displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.handleDisplayLink))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
    }

    /// Finds the glass indicator view within the segmented control's internal hierarchy.
    ///
    /// Primary: finds by class name. Fallback: finds the sibling of the segments container
    /// that has subviews. The indicator has child subviews (glass rendering stack),
    /// while DestOutView is a leaf.
    private func findIndicatorView() -> UIView? {
        // Primary: class name lookup
        if let found = findDescendant(named: "_UILiquidLensView") {
            return found
        }

        // Fallback: find the sibling of the segments container that has subviews.
        // The indicator, segments container, and DestOutView share a parent wrapper.
        // The indicator has subviews (glass rendering stack); DestOutView is a leaf.
        let segments = findSegmentViews()
        guard let segmentsContainer = segments.first?.superview,
              let wrapper = segmentsContainer.superview else { return nil }

        return wrapper.subviews.first { sibling in
            sibling !== segmentsContainer && !sibling.subviews.isEmpty
        }
    }

    private func findDescendant(named className: String) -> UIView? {
        func search(in view: UIView) -> UIView? {
            for subview in view.subviews {
                if String(describing: type(of: subview)) == className {
                    return subview
                }
                if let found = search(in: subview) {
                    return found
                }
            }
            return nil
        }
        return search(in: self)
    }

    /// Returns the indicator rect by tracking the internal glass indicator view's presentation layer,
    /// or falls back to the selected segment's frame if the indicator view can't be found.
    private func currentIndicatorRect() -> CGRect {
        // Try to use the cached/found indicator view for smooth animation tracking
        if cachedIndicatorView == nil {
            cachedIndicatorView = findIndicatorView()
        }
        if let indicatorView = cachedIndicatorView {
            // Stay in the presentation layer tree for both sides of the conversion
            let presLayer = indicatorView.layer.presentation() ?? indicatorView.layer
            let selfPresLayer = self.layer.presentation() ?? self.layer
            return selfPresLayer.convert(presLayer.bounds, from: presLayer)
        }

        // Fallback: use the selected segment's frame (no animation, but always correct)
        if !didLogFallback {
            fabBarLogger.warning("Glass indicator view not found — accent masking will snap without animation. Internal UISegmentedControl hierarchy may have changed.")
            didLogFallback = true
        }
        let segments = findSegmentViews()
        if selectedSegmentIndex >= 0, selectedSegmentIndex < segments.count {
            return segments[selectedSegmentIndex].frame
        }
        return .zero
    }

    /// Called each frame to update accent view masks based on the glass indicator's animated position.
    fileprivate func updateAccentMasks() {
        let indicatorRect = currentIndicatorRect()

        // Pause display link when indicator is stationary to save power
        if indicatorRect == lastIndicatorRect {
            stableFrameCount += 1
            if stableFrameCount >= Self.stableFrameThreshold {
                displayLink?.isPaused = true
                return
            }
        } else {
            stableFrameCount = 0
            lastIndicatorRect = indicatorRect
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (index, accentView) in accentContentViews.enumerated() {
            let baseView = contentViews[index]
            updateMasks(base: baseView, accent: accentView, indicatorRect: indicatorRect)
        }

        CATransaction.commit()
    }

    private func updateMasks(base baseView: TabItemContentView, accent accentView: TabItemContentView, indicatorRect: CGRect) {
        // Use presentation layers for consistency with indicatorRect
        let accentPres = accentView.layer.presentation() ?? accentView.layer
        let selfPres = self.layer.presentation() ?? self.layer
        let viewRectInControl = selfPres.convert(accentPres.bounds, from: accentPres)

        // Convert the indicator rect into the content view's local coordinate space.
        // Using the full capsule path (not a rect intersection) ensures rounded
        // corners are preserved even when the indicator partially overlaps.
        let localIndicator = CGRect(
            x: indicatorRect.origin.x - viewRectInControl.origin.x,
            y: indicatorRect.origin.y - viewRectInControl.origin.y,
            width: indicatorRect.width,
            height: indicatorRect.height
        )
        let cornerRadius = indicatorRect.height / 2
        let capsulePath = UIBezierPath(roundedRect: localIndicator, cornerRadius: cornerRadius)

        let accentMask = accentView.layer.mask as? CAShapeLayer ?? {
            let m = CAShapeLayer()
            accentView.layer.mask = m
            return m
        }()

        // Accent: show only inside the indicator capsule
        accentMask.path = capsulePath.cgPath

        // Base: cut out the indicator capsule using even-odd fill
        if indicatorRect.intersects(viewRectInControl) {
            let baseMask = baseView.layer.mask as? CAShapeLayer ?? {
                let m = CAShapeLayer()
                baseView.layer.mask = m
                return m
            }()
            let basePath = UIBezierPath(rect: baseView.bounds)
            basePath.append(capsulePath)
            baseMask.fillRule = .evenOdd
            baseMask.path = basePath.cgPath
        } else {
            baseView.layer.mask = nil
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

        displayLink?.isPaused = false
        stableFrameCount = 0

        if shouldMoveIndicatorOnTouchDown {
            originalIndex = selectedSegmentIndex
            selectedSegmentIndex = newIndex
        }

        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            super.touchesMoved(touches, with: event)
            return
        }

        let newIndex = segmentIndex(at: touch.location(in: self))

        displayLink?.isPaused = false
        stableFrameCount = 0

        if shouldMoveIndicatorOnTouchDown && selectedSegmentIndex != newIndex {
            selectedSegmentIndex = newIndex
        }

        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        displayLink?.isPaused = false
        stableFrameCount = 0

        if shouldMoveIndicatorOnTouchDown, let originalIndex {
            if selectedSegmentIndex != originalIndex {
                sendActions(for: .valueChanged)
            } else {
                onReselect?(selectedSegmentIndex)
            }
        }
        originalIndex = nil
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        displayLink?.isPaused = false
        stableFrameCount = 0

        if shouldMoveIndicatorOnTouchDown, let originalIndex {
            selectedSegmentIndex = originalIndex
        }
        originalIndex = nil
        super.touchesCancelled(touches, with: event)
    }
}

/// Weak-reference proxy that prevents `CADisplayLink` from retaining the segmented control.
@available(iOS 26.0, *)
@MainActor
private final class DisplayLinkProxy: NSObject {
    weak var control: TabBarSegmentedControl?

    init(control: TabBarSegmentedControl) {
        self.control = control
    }

    @objc func handleDisplayLink(_ link: CADisplayLink) {
        guard let control else {
            link.invalidate()
            return
        }
        control.updateAccentMasks()
    }
}
