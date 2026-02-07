import SwiftUI
import UIKit

/// A UIViewRepresentable that wraps a TabBarSegmentedControl for tab bar functionality.
/// The segmented control's labels are hidden and replaced with custom UIKit label views,
/// preserving UIKit's touch handling and glass effects while allowing full control over rendering.
@available(iOS 26.0, *)
struct FabBarRepresentable<Value: Hashable>: UIViewRepresentable {
    var tabs: [FabBarTab<Value>]
    var action: FabBarAction

    @Binding var activeTab: Value

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> GlassTabBarView {
        // Use system images for segment sizing - labels will be hidden
        let images = tabs.compactMap { _ in
            UIImage(systemName: "circle")
        }
        let control = TabBarSegmentedControl(items: images)
        control.showsLargeContentViewer = false
        let selectedIndex = tabs.firstIndex { $0.value == activeTab } ?? 0
        control.selectedSegmentIndex = selectedIndex

        control.setTitleTextAttributes([.foregroundColor: UIColor.tintColor], for: .selected)

        // Set titles for accessibility
        for (index, tab) in tabs.enumerated() {
            control.setTitle(tab.title, forSegmentAt: index)
            if let composedImage = composedSegmentImage(for: tab) {
                control.setImage(composedImage, forSegmentAt: index)
            }
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

    private func composedSegmentImage(for tab: FabBarTab<Value>) -> UIImage? {
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

        let spacing: CGFloat = 4
        let horizontalPadding: CGFloat = 24
        let contentWidth = max(icon.size.width, textSize.width)
        let width = contentWidth + (horizontalPadding * 2)
        let height = icon.size.height + spacing + textSize.height
        let size = CGSize(width: width, height: height)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let imageX = (width - icon.size.width) / 2
            let imageRect = CGRect(x: imageX, y: 0, width: icon.size.width, height: icon.size.height)
            icon.draw(in: imageRect)

            let textX = (width - textSize.width) / 2
            let textPoint = CGPoint(x: textX, y: icon.size.height + spacing)
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
