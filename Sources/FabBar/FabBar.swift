import SwiftUI

/// A customizable iOS 26 glass tab bar with a floating action button.
///
/// FabBar provides a native-looking iOS 26 tab bar where you control what goes in it,
/// including a FAB that morphs with the glass effect.
///
/// ## Usage
///
/// The recommended way to use FabBar is with the `.fabBar()` modifier:
///
/// ```swift
/// TabView(selection: $selectedTab) {
///     Tab(value: .home) {
///         HomeView()
///             .fabBarSafeAreaPadding()
///             .toolbarVisibility(.hidden, for: .tabBar)
///     }
///     // more tabs...
/// }
/// .fabBar(
///     selection: $selectedTab,
///     items: [
///         FabBarItem(tab: .home, title: "Home", systemImage: "house.fill"),
///         FabBarItem(tab: .explore, title: "Explore", systemImage: "compass"),
///         FabBarItem(tab: .profile, title: "Profile", systemImage: "person.fill"),
///     ],
///     action: FabAction(systemImage: "plus", accessibilityLabel: "Add Item") {
///         // Handle tap
///     }
/// )
/// ```
///
/// For more control over positioning, you can use the `FabBar` view directly.

@available(iOS 26.0, *)
public struct FabBar<Tab: Hashable>: View {
    /// The currently selected tab.
    @Binding public var selection: Tab

    /// The tab items to display.
    public let items: [FabBarItem<Tab>]

    /// The floating action button configuration.
    public var action: FabAction

    /// Creates a FabBar with the specified configuration.
    ///
    /// - Parameters:
    ///   - selection: A binding to the currently selected tab.
    ///   - items: The tab items to display.
    ///   - action: The floating action button configuration.
    public init(
        selection: Binding<Tab>,
        items: [FabBarItem<Tab>],
        action: FabAction
    ) {
        self._selection = selection
        self.items = items
        self.action = action
    }

    public var body: some View {
        if items.isEmpty {
            Color.clear
                .frame(height: Constants.barHeight)
                .onAppear {
                    fabBarLogger.warning("FabBar initialized with empty items array - nothing will be displayed")
                }
        } else {
            GeometryReader { geo in
                FabBarRepresentable(
                    size: geo.size,
                    items: items,
                    action: action,
                    activeTab: $selection
                )
            }
            .frame(height: Constants.barHeight)
        }
    }
}
