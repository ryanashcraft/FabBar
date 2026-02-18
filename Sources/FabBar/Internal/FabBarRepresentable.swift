import SwiftUI
import UIKit

/// A UIViewRepresentable that wraps a TabBarSegmentedControl for tab bar functionality.
/// Since UISegmentedControl doesn't support both title and image at the same time, we create pre-rendered tab images
/// that mimic the appearance of SwiftUI's tab items, allowing for both icons and text in each segment. This preserves
/// UIKit's touch handling and glass effects while allowing full control over rendering.
@available(iOS 26.0, *)
struct FabBarRepresentable<Value: Hashable>: UIViewRepresentable {
    var tabs: [FabBarTab<Value>]
    var action: FabBarAction

    @Binding var activeTab: Value

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> GlassTabBarView {
        // Create some images to pre-fill the segmented control with, so it allocates the right number of segments.
        // We'll replace these with our custom-rendered images immediately after.
        let images = tabs.compactMap { _ in
            UIImage(systemName: "circle")
        }
        let control = TabBarSegmentedControl(items: images)
        control.showsLargeContentViewer = false
        let selectedIndex = tabs.firstIndex { $0.value == activeTab } ?? 0
        control.selectedSegmentIndex = selectedIndex

        control.setTitleTextAttributes([.foregroundColor: UIColor.tintColor], for: .selected)

        applySegmentImages(
            to: control,
            scale: context.environment.displayScale,
            isForAccessibilityPopover: false
        )

        control.onPrepareAccessibilityPopover = { [weak control] in
            guard let control else { return }
            applySegmentImages(
                to: control,
                scale: context.environment.displayScale,
                isForAccessibilityPopover: true
            )
        }

        control.onPostAccessibilityPopoverTraitChange = { [weak control] in
            guard let control else { return }
            applySegmentImages(
                to: control,
                scale: context.environment.displayScale,
                isForAccessibilityPopover: false
            )
        }

        control.selectedSegmentTintColor = segmentTintColor(for: control.traitCollection)

        control.addTarget(context.coordinator, action: #selector(context.coordinator.tabSelected(_:)), for: .valueChanged)

        // Handle reselection (tapping already-selected segment)
        let coordinator = context.coordinator
        control.onReselect = { index in
            if index >= 0 && index < coordinator.parent.tabs.count {
                coordinator.parent.tabs[index].onReselect?()
            }
        }

        // Wrap in glass tab bar view with segmented control and FAB
        let container = GlassTabBarView(
            segmentedControl: control,
            action: action
        )

        return container
    }

    func updateUIView(_ uiView: GlassTabBarView, context: Context) {
        context.coordinator.parent = self

        let control = uiView.segmentedControl
        control.selectedSegmentTintColor = segmentTintColor(for: uiView.traitCollection)
        let newIndex = tabs.firstIndex { $0.value == activeTab } ?? 0
        let selectionChanged = control.selectedSegmentIndex != newIndex
        if selectionChanged {
            control.selectedSegmentIndex = newIndex
        }
    }

    private func segmentTintColor(for traitCollection: UITraitCollection) -> UIColor {
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return .label.withAlphaComponent(0.15)
        default:
            return .label.withAlphaComponent(0.08)
        }
    }

    private func applySegmentImages(to control: UISegmentedControl, scale: CGFloat, isForAccessibilityPopover: Bool) {
        let horizontalPadding = horizontalPadding(for: tabs.count)

        for (index, tab) in tabs.enumerated() {
            if let composedImage = composedSegmentImage(
                for: tab,
                horizontalPadding: horizontalPadding,
                scale: scale,
                isForAccessibilityPopover: isForAccessibilityPopover
            ) {
                composedImage.accessibilityIdentifier = tab.title
                control.setImage(composedImage, forSegmentAt: index)
            }
        }
    }

    /// Determines horizontal padding for tab content based on the number of tabs.
    ///
    /// This ensures that tab bars with fewer items look as close as possible to the standard iOS tab bar style, which
    /// has more padding around items when there are fewer of them. Also ensures that tab items are not squeezed when
    /// there are many of them.
    private func horizontalPadding(for tabCount: Int) -> CGFloat {
        switch tabCount {
        case 1 ... 3:
            return 24
        case 4:
            return 8
        default:
            return 0
        }
    }

    /// Renders a single tab segment image that combines icon + title into one bitmap for `UISegmentedControl`.
    ///
    /// `isForAccessibilityPopover` uses higher rasterization scale so the system accessibility popover preview
    /// remains crisp. Normal tab-bar rendering uses regular scale to avoid downscaling blur in the control itself.
    private func composedSegmentImage(
        for tab: FabBarTab<Value>,
        horizontalPadding: CGFloat,
        scale: CGFloat,
        isForAccessibilityPopover: Bool
    ) -> UIImage? {
        let font = UIFont.systemFont(ofSize: Constants.tabTitleFontSize, weight: .medium)
        let textSize = (tab.title as NSString).size(withAttributes: [.font: font])

        let config = UIImage.SymbolConfiguration(
            pointSize: Constants.tabIconPointSize,
            weight: .medium,
            scale: .large
        )

        let image: UIImage?
        if let imageName = tab.image {
            let bundle = tab.imageBundle ?? .main
            image = UIImage(named: imageName, in: bundle, with: config)
        } else if let systemName = tab.systemImage {
            image = UIImage(systemName: systemName, withConfiguration: config)
        } else {
            image = nil
        }

        guard let icon = image else { return nil }

        let contentWidth = max(icon.size.width, textSize.width)
        let width = contentWidth + (horizontalPadding * 2)
        let imageAreaHeight: CGFloat = Constants.iconViewSize
        let height = imageAreaHeight + textSize.height
        let size = CGSize(width: width, height: height)

        let format = UIGraphicsImageRendererFormat.default()

        let targetScale = if isForAccessibilityPopover {
            // Render at higher scale for the accessibility popover, since the tab items are way larger there
            scale * 3
        } else {
            scale
        }

        format.scale = targetScale

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            let imageX = (width - icon.size.width) / 2
            let imageY = (imageAreaHeight - icon.size.height) / 2
            let imageRect = CGRect(x: imageX, y: imageY, width: icon.size.width, height: icon.size.height)
            icon.draw(in: imageRect)

            let textX = (width - textSize.width) / 2
            let textPoint = CGPoint(x: textX, y: imageAreaHeight)
            (tab.title as NSString).draw(at: textPoint, withAttributes: [.font: font])
        }
    }

    @MainActor
    class Coordinator: NSObject {
        var parent: FabBarRepresentable<Value>

        init(parent: FabBarRepresentable<Value>) {
            self.parent = parent
        }

        @objc func tabSelected(_ control: UISegmentedControl) {
            let index = control.selectedSegmentIndex
            if index >= 0 && index < parent.tabs.count {
                parent.activeTab = parent.tabs[index].value
            }
        }
    }
}
