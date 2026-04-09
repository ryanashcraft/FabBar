import os
import UIKit

/// Centralized constants for FabBar components.
///
/// All magic numbers are documented here with rationale for their values.
@available(iOS 26.0, *)
enum Constants {
    // MARK: - Bar Dimensions

    /// Height of the entire tab bar.
    /// Matches the standard iOS tab bar height for visual consistency.
    static let barHeight: CGFloat = 62

    /// Spacing between the segmented control and FAB.
    static let fabSpacing: CGFloat = 8

    // MARK: - Layout Padding

    /// Horizontal padding for FabBar positioning.
    static let horizontalPadding: CGFloat = 21

    /// Bottom padding for FabBar positioning.
    /// Provides clearance above the home indicator.
    static let bottomPadding: CGFloat = 21

    /// Padding inside the glass container around the segmented control.
    static let contentPadding: CGFloat = 2

    // MARK: - Icon Sizing

    /// Point size for tab bar icons (SF Symbols).
    /// Uses medium weight at large scale to match SwiftUI's .imageScale(.large).
    static let tabIconPointSize: CGFloat = 18

    /// Point size for the FAB button icon.
    static let fabIconPointSize: CGFloat = 20

    /// Fixed size for the icon image view container.
    /// Provides consistent touch target and visual alignment.
    static let iconViewSize: CGFloat = 28

    // MARK: - Typography

    /// Font size for tab item titles.
    /// Matches Apple HIG recommendations for tab bar labels.
    static let tabTitleFontSize: CGFloat = 10

    // MARK: - Segment Sizing

    /// Fixed segment width used when there are fewer than 3 tabs.
    /// With 3+ tabs, segments auto-distribute to fill the available space.
    static let fewTabsSegmentWidth: CGFloat = 98

    // MARK: - Badge

    /// Diameter of the badge indicator dot.
    static let badgeDotSize: CGFloat = 8

    /// Offset from the top-trailing corner of the icon area.
    static let badgeOffsetX: CGFloat = 2
    static let badgeOffsetY: CGFloat = 2
}

/// Logger for FabBar warnings and diagnostics.
let fabBarLogger = Logger(subsystem: "com.ryanashcraft.FabBar", category: "FabBar")
