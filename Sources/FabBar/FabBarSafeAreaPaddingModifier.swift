import SwiftUI

/// View modifier that applies bottom safe area padding to clear the FabBar.
@available(iOS 26.0, *)
struct FabBarSafeAreaPaddingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.safeAreaPadding(.bottom, Constants.barHeight + Constants.bottomPadding)
    }
}

@available(iOS 26.0, *)
public extension View {
    /// Applies bottom safe area padding to clear the FabBar.
    ///
    /// Use this on scrollable content within each tab to ensure
    /// content isn't hidden behind the FabBar.
    ///
    /// ```swift
    /// Tab(value: .home) {
    ///     HomeView()
    ///         .fabBarSafeAreaPadding()
    ///         .toolbarVisibility(.hidden, for: .tabBar)
    /// }
    /// ```
    func fabBarSafeAreaPadding() -> some View {
        modifier(FabBarSafeAreaPaddingModifier())
    }
}
