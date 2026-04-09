import UIKit

/// A tab configuration for FabBar.
///
/// Each tab represents an item in the tab bar with an icon and title.
/// The tab is identified by a generic `Value` type that must conform to `Hashable`.
@available(iOS 26.0, *)
public struct FabBarTab<Value: Hashable>: Identifiable {
    public var id: Value { value }

    /// The tab identifier.
    public let value: Value

    /// The title displayed below the icon.
    public let title: String

    /// The SF Symbol name for the icon. Used when `image` is nil.
    public let systemImage: String?

    /// The custom image name from a bundle. Takes precedence over `systemImage` when set.
    public let image: String?

    /// The bundle containing the custom image. Defaults to `.main` if not specified.
    public let imageBundle: Bundle?

    /// Called when the user taps this tab while it's already selected.
    /// Useful for scroll-to-top or similar behaviors.
    public let onReselect: (() -> Void)?

    /// Whether to show a badge indicator dot on this tab.
    public let showBadge: Bool

    /// The color of the badge dot. Defaults to the view's tint color.
    public let badgeColor: UIColor?

    /// Creates a tab with an SF Symbol icon.
    ///
    /// - Parameters:
    ///   - value: The tab identifier.
    ///   - title: The title displayed below the icon.
    ///   - systemImage: The SF Symbol name for the icon.
    ///   - showBadge: Whether to show a badge indicator dot.
    ///   - onReselect: Called when the user taps this tab while it's already selected.
    public init(
        value: Value,
        title: String,
        systemImage: String,
        showBadge: Bool = false,
        badgeColor: UIColor? = nil,
        onReselect: (() -> Void)? = nil
    ) {
        self.value = value
        self.title = title
        self.systemImage = systemImage
        self.image = nil
        self.imageBundle = nil
        self.onReselect = onReselect
        self.showBadge = showBadge
        self.badgeColor = badgeColor
    }

    /// Creates a tab with a custom image from a bundle.
    ///
    /// - Parameters:
    ///   - value: The tab identifier.
    ///   - title: The title displayed below the icon.
    ///   - image: The custom image name.
    ///   - imageBundle: The bundle containing the image. Defaults to `.main`.
    ///   - showBadge: Whether to show a badge indicator dot.
    ///   - onReselect: Called when the user taps this tab while it's already selected.
    public init(
        value: Value,
        title: String,
        image: String,
        imageBundle: Bundle? = nil,
        showBadge: Bool = false,
        badgeColor: UIColor? = nil,
        onReselect: (() -> Void)? = nil
    ) {
        self.value = value
        self.title = title
        self.systemImage = nil
        self.image = image
        self.imageBundle = imageBundle ?? .main
        self.onReselect = onReselect
        self.showBadge = showBadge
        self.badgeColor = badgeColor
    }
}
