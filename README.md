# FabBar

A customizable iOS 26 glass tab bar with a floating action button.

![FabBar Screenshot](Assets/fabbar-screenshot.png)

## Why FabBar?

Many apps have a primary action that users perform frequently: composing a social media post, logging a meal, creating a task. Placing this action at the bottom of the screen keeps it in the thumb zone and always visible, reducing friction for the most common user flow.

With iOS 26's tab bar, developers can disguise a search tab as a primary action, but this approach has several issues:

- VoiceOver reads it as a tab, not a button
- Requires intercepting tab changes and undoing them, which is potentially brittle
- Not customizable beyond the icon

Developers have another option: placing a custom floating action button above the tab bar. Typically, this is placed on the right side of the screen. However, with iOS 26's centered tab bar, this creates an awkward layout. With fewer than four tabs, there's negative space on either side of the bar, and placing a FAB on the trailing edge creates unbalanced empty space below it. And there's no way to customize the native tab bar's placement or sizing to work around this.

FabBar provides one solution: recreate the tab bar entirely for full control.

## How It Works

The key challenge in recreating the tab bar is the interactive glass effect on touch down and drag. This effect is only available to tab bars and one other component: segmented controls. FabBar uses a segmented control as its foundation, hiding the default labels and overlaying custom tab item views.

Why UIKit instead of pure SwiftUI? FabBar manipulates UISegmentedControl's internal view hierarchy to hide the native labels and overlay custom views. This isn't possible with SwiftUI's Picker. Additionally, mixing custom UIKit controls with SwiftUI's `.glassEffect()` causes framerate issues during touch interactions.

This approach could be brittle across OS updates. See Known Limitations below for other tradeoffs.

Credit to [Kavsoft](https://youtu.be/wfHIe8GpKAU?si=ASViL-OuhqQwEWzr) for the original idea of using a segmented control to imitate a tab bar.

## Requirements

- iOS 26.0+
- Swift 6.0+

## Installation

Add FabBar as a Swift Package dependency:

```swift
dependencies: [
    .package(url: "https://github.com/ryanashcraft/FabBar.git", from: "1.0.0")
]
```

## Usage

```swift
import FabBar

enum AppTab: Hashable {
    case home, explore, profile
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: AppTab.home) {
                HomeView()
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.explore) {
                ExploreView()
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.profile) {
                ProfileView()
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .safeAreaBar(edge: .bottom) {
            FabBar(
                selection: $selectedTab,
                items: [
                    FabBarItem(tab: .home, title: "Home", systemImage: "house.fill"),
                    FabBarItem(tab: .explore, title: "Explore", systemImage: "compass"),
                    FabBarItem(tab: .profile, title: "Profile", systemImage: "person.fill"),
                ],
                action: FabAction(
                    systemImage: "plus",
                    accessibilityLabel: "Add Item"
                ) {
                    // Handle FAB tap
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 21)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
```

### Custom Images

Use custom images from your asset catalog instead of SF Symbols:

```swift
FabBarItem(
    tab: .library,
    title: "Library",
    image: "custom.library.icon",
    imageBundle: .main
)
```

### Tab Reselection

Handle when users tap an already-selected tab (useful for scroll-to-top):

```swift
FabBarItem(
    tab: .home,
    title: "Home",
    systemImage: "house.fill",
    onReselect: {
        // User tapped this tab while it was already selected
        scrollToTop()
    }
)
```

### Layout Considerations

FabBar doesn't dictate how you position it in your layout. Here's what you'll typically need to handle:

**1. Hide the native tab bar** on each tab's content:

```swift
Tab(value: .home) {
    HomeView()
        .toolbarVisibility(.hidden, for: .tabBar)
}
```

**2. Position FabBar at the bottom** using `.safeAreaBar` and ignore the bottom safe area so you can control positioning manually:

```swift
TabView(selection: $selectedTab) {
    // tabs...
}
.safeAreaBar(edge: .bottom) {
    FabBar(...)
        .padding(.horizontal, 16)
        .padding(.bottom, 21)  // Clear the home indicator
}
.ignoresSafeArea(.container, edges: .bottom)
```

**3. Add bottom padding to scrollable content** so it clears the tab bar. The total margin needed is `FabBar.height` plus your bottom padding:

```swift
let bottomMargin = FabBar<MyTab>.height + 21  // 62 + 21 = 83

ScrollView {
    // content...
}
.safeAreaPadding(.bottom, bottomMargin)
```

Consider creating a shared constant or environment value for this margin so it stays consistent across your app.

**4. iPad considerations**: On larger screens, you likely want to hide the FabBar and rely on the native tab bar. Check `horizontalSizeClass` to conditionally show FabBar only on compact widths.

## Known Limitations

**Color clipping during drag:** The native iOS 26 tab bar uses the glass bubble as a real-time clipping mask. Icon and text show the active tint inside the bubble and inactive tint outside, even mid-drag. FabBar highlights tabs fully when the bubble moves over them rather than clipping. Most noticeable during slow drags between tabs.

**Accessibility large text mode:** Native tab bars show a full-screen overlay on touch down when using accessibility text sizes. FabBar uses a segmented control internally, which shows a popover instead.

![Large Text Mode](Assets/large-text-mode.png)

## License

MIT License. See [LICENSE](LICENSE) for details.
