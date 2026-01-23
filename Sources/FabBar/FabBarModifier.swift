import SwiftUI

/// View modifier that positions a FabBar at the bottom of the view.
///
/// This modifier handles all the layout details:
/// - Wraps in `.safeAreaBar(edge: .bottom)`
/// - Applies appropriate padding
/// - Ignores bottom safe area for manual positioning
/// - Hides automatically on regular horizontal size class (iPad)
@available(iOS 26.0, *)
struct FabBarModifier<Tab: Hashable>: ViewModifier {
    @Binding var selection: Tab
    let items: [FabBarItem<Tab>]
    let action: FabAction

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .safeAreaBar(edge: .bottom) {
                if horizontalSizeClass == .compact {
                    FabBar(selection: $selection, items: items, action: action)
                        .padding(.horizontal, Constants.horizontalPadding)
                        .padding(.bottom, Constants.bottomPadding)
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
    }
}

@available(iOS 26.0, *)
public extension View {
    /// Adds a FabBar to the bottom of the view.
    ///
    /// This is the recommended way to use FabBar. It handles positioning,
    /// safe area management, and automatically hides on iPad.
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
    /// .fabBar(selection: $selectedTab, items: items, action: action)
    /// ```
    ///
    /// - Parameters:
    ///   - selection: A binding to the currently selected tab.
    ///   - items: The tab items to display.
    ///   - action: The floating action button configuration.
    func fabBar<Tab: Hashable>(
        selection: Binding<Tab>,
        items: [FabBarItem<Tab>],
        action: FabAction
    ) -> some View {
        modifier(FabBarModifier(selection: selection, items: items, action: action))
    }
}
