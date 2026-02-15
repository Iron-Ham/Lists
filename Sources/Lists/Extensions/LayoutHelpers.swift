import UIKit

/// Factory methods for common `UICollectionViewCompositionalLayout` list configurations.
///
/// Use these when you need a layout for a custom ``ListDataSource`` or ``MixedListDataSource``
/// setup. The pre-built configurations (``SimpleList``, ``GroupedList``, ``OutlineList``) create
/// their own layouts automatically.
///
/// - Note: The `separatorColor` parameter applies a uniform color to all separators.
///   For per-item separator customization, use ``SimpleList``, ``GroupedList``, or
///   ``OutlineList`` which support both global color and per-item handlers via
///   their `separatorHandler` property.
@MainActor
public enum ListLayout {

  // MARK: Public

  /// Creates a plain list layout with optional header and footer modes.
  public static func plain(
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .none,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .none,
    showsSeparators: Bool = true,
    separatorColor: UIColor? = nil,
    backgroundColor: UIColor? = nil,
    headerTopPadding: CGFloat? = nil
  ) -> UICollectionViewCompositionalLayout {
    makeLayout(
      appearance: .plain,
      headerMode: headerMode,
      footerMode: footerMode,
      showsSeparators: showsSeparators,
      separatorColor: separatorColor,
      backgroundColor: backgroundColor,
      headerTopPadding: headerTopPadding
    )
  }

  /// Creates a grouped list layout with optional header and footer modes.
  public static func grouped(
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .none,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .none,
    showsSeparators: Bool = true,
    separatorColor: UIColor? = nil,
    backgroundColor: UIColor? = nil,
    headerTopPadding: CGFloat? = nil
  ) -> UICollectionViewCompositionalLayout {
    makeLayout(
      appearance: .grouped,
      headerMode: headerMode,
      footerMode: footerMode,
      showsSeparators: showsSeparators,
      separatorColor: separatorColor,
      backgroundColor: backgroundColor,
      headerTopPadding: headerTopPadding
    )
  }

  /// Creates an inset-grouped list layout with optional header and footer modes.
  public static func insetGrouped(
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .none,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .none,
    showsSeparators: Bool = true,
    separatorColor: UIColor? = nil,
    backgroundColor: UIColor? = nil,
    headerTopPadding: CGFloat? = nil
  ) -> UICollectionViewCompositionalLayout {
    makeLayout(
      appearance: .insetGrouped,
      headerMode: headerMode,
      footerMode: footerMode,
      showsSeparators: showsSeparators,
      separatorColor: separatorColor,
      backgroundColor: backgroundColor,
      headerTopPadding: headerTopPadding
    )
  }

  /// Creates a sidebar list layout with optional header and footer modes.
  public static func sidebar(
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .none,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .none,
    showsSeparators: Bool = true,
    separatorColor: UIColor? = nil,
    backgroundColor: UIColor? = nil,
    headerTopPadding: CGFloat? = nil
  ) -> UICollectionViewCompositionalLayout {
    makeLayout(
      appearance: .sidebar,
      headerMode: headerMode,
      footerMode: footerMode,
      showsSeparators: showsSeparators,
      separatorColor: separatorColor,
      backgroundColor: backgroundColor,
      headerTopPadding: headerTopPadding
    )
  }

  /// Creates a sidebar-plain list layout with optional header and footer modes.
  public static func sidebarPlain(
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .none,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .none,
    showsSeparators: Bool = true,
    separatorColor: UIColor? = nil,
    backgroundColor: UIColor? = nil,
    headerTopPadding: CGFloat? = nil
  ) -> UICollectionViewCompositionalLayout {
    makeLayout(
      appearance: .sidebarPlain,
      headerMode: headerMode,
      footerMode: footerMode,
      showsSeparators: showsSeparators,
      separatorColor: separatorColor,
      backgroundColor: backgroundColor,
      headerTopPadding: headerTopPadding
    )
  }

  // MARK: Private

  private static func makeLayout(
    appearance: UICollectionLayoutListConfiguration.Appearance,
    headerMode: UICollectionLayoutListConfiguration.HeaderMode,
    footerMode: UICollectionLayoutListConfiguration.FooterMode,
    showsSeparators: Bool,
    separatorColor: UIColor?,
    backgroundColor: UIColor?,
    headerTopPadding: CGFloat?
  ) -> UICollectionViewCompositionalLayout {
    var config = UICollectionLayoutListConfiguration(appearance: appearance)
    config.headerMode = headerMode
    config.footerMode = footerMode
    config.showsSeparators = showsSeparators
    if let backgroundColor {
      config.backgroundColor = backgroundColor
    }
    if let headerTopPadding {
      config.headerTopPadding = headerTopPadding
    }
    if let separatorColor {
      config.itemSeparatorHandler = { _, sectionConfig in
        var modified = sectionConfig
        modified.color = separatorColor
        return modified
      }
    }
    return UICollectionViewCompositionalLayout.list(using: config)
  }
}
