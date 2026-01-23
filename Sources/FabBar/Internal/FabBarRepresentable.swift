import SwiftUI
import UIKit

/// A UIViewRepresentable that wraps a HiddenLabelSegmentedControl for tab bar functionality.
/// The segmented control's labels are hidden and replaced with custom UIKit label views,
/// preserving UIKit's touch handling and glass effects while allowing full control over rendering.
@available(iOS 26.0, *)
struct FabBarRepresentable<Tab: Hashable>: UIViewRepresentable {
    var size: CGSize
    var items: [FabBarItem<Tab>]
    var barTint: UIColor = .label.withAlphaComponent(0.08)
    var inactiveTint: UIColor = .label
    var action: FabAction

    @Binding var activeTab: Tab
    var onReselect: ((Tab) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> GlassTabBarContainer<Tab> {
        // Use system images for segment sizing - labels will be hidden
        let images = items.compactMap { _ in
            UIImage(systemName: "circle")
        }
        let control = HiddenLabelSegmentedControl(items: images)
        control.showsLargeContentViewer = false
        let selectedIndex = items.firstIndex { $0.tab == activeTab } ?? 0
        control.selectedSegmentIndex = selectedIndex

        // Set titles for accessibility
        for (index, item) in items.enumerated() {
            control.setTitle(item.title, forSegmentAt: index)
        }

        control.selectedSegmentTintColor = barTint

        control.addTarget(context.coordinator, action: #selector(context.coordinator.tabSelected(_:)), for: .valueChanged)

        // Handle reselection (tapping already-selected segment)
        let coordinator = context.coordinator
        control.onReselect = { index in
            if index >= 0 && index < coordinator.parent.items.count {
                coordinator.parent.onReselect?(coordinator.parent.items[index].tab)
            }
        }

        // Wrap in glass tab bar container with segmented control, labels overlay, and FAB
        let container = GlassTabBarContainer(
            segmentedControl: control,
            tabItems: items,
            selectedIndex: selectedIndex,
            action: action
        )

        // Set label colors
        container.labelsOverlay.inactiveTintColor = inactiveTint

        return container
    }

    func updateUIView(_ uiView: GlassTabBarContainer<Tab>, context _: Context) {
        let control = uiView.segmentedControl
        let newIndex = items.firstIndex { $0.tab == activeTab } ?? 0
        let selectionChanged = control.selectedSegmentIndex != newIndex
        if selectionChanged {
            control.selectedSegmentIndex = newIndex
        }

        // Always update the labels overlay's selected index - the segmented control
        // may already have the correct index from touch handling, but the overlay
        // needs to know the final selection for when onHighlightEnd is called
        uiView.labelsOverlay.setSelectedIndex(newIndex, animated: false)

        // Keep VoiceOver focus on the tab bar after selection changes
        if selectionChanged {
            UIAccessibility.post(notification: .screenChanged, argument: control)
        }
    }

    func sizeThatFits(_: ProposedViewSize, uiView _: GlassTabBarContainer<Tab>, context _: Context) -> CGSize? {
        return size
    }

    @MainActor
    class Coordinator: NSObject {
        var parent: FabBarRepresentable<Tab>
        init(parent: FabBarRepresentable<Tab>) {
            self.parent = parent
        }

        @objc func tabSelected(_ control: UISegmentedControl) {
            let index = control.selectedSegmentIndex
            if index >= 0 && index < parent.items.count {
                parent.activeTab = parent.items[index].tab
            }
        }
    }
}
