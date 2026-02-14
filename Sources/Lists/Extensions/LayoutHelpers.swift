import UIKit

/// Factory methods for common `UICollectionViewCompositionalLayout` list configurations.
///
/// Use these when you need a layout for a custom ``ListDataSource`` or ``MixedListDataSource``
/// setup. The pre-built configurations (``SimpleList``, ``GroupedList``, ``OutlineList``) create
/// their own layouts automatically.
@MainActor
public enum ListLayout {
  /// Creates a plain list layout with optional header and footer modes.
  public static func plain(
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .none,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .none
  ) -> UICollectionViewCompositionalLayout {
    var config = UICollectionLayoutListConfiguration(appearance: .plain)
    config.headerMode = headerMode
    config.footerMode = footerMode
    return UICollectionViewCompositionalLayout.list(using: config)
  }

  /// Creates an inset-grouped list layout with optional header and footer modes.
  public static func insetGrouped(
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .none,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .none
  ) -> UICollectionViewCompositionalLayout {
    var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
    config.headerMode = headerMode
    config.footerMode = footerMode
    return UICollectionViewCompositionalLayout.list(using: config)
  }

  /// Creates a sidebar list layout with optional header and footer modes.
  public static func sidebar(
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .none,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .none
  ) -> UICollectionViewCompositionalLayout {
    var config = UICollectionLayoutListConfiguration(appearance: .sidebar)
    config.headerMode = headerMode
    config.footerMode = footerMode
    return UICollectionViewCompositionalLayout.list(using: config)
  }
}
