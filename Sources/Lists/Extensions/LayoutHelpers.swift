import UIKit

/// Factory methods for common `UICollectionViewCompositionalLayout` list configurations.
///
/// Use these when you need a layout for a custom ``ListDataSource`` or ``MixedListDataSource``
/// setup. The pre-built configurations (``SimpleList``, ``GroupedList``, ``OutlineList``) create
/// their own layouts automatically.
@MainActor
public enum ListLayout {

  // MARK: Public

  /// Creates a plain list layout with optional header and footer modes.
  public static func plain(
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .none,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .none,
    showsSeparators: Bool = true
  ) -> UICollectionViewCompositionalLayout {
    makeLayout(appearance: .plain, headerMode: headerMode, footerMode: footerMode, showsSeparators: showsSeparators)
  }

  /// Creates an inset-grouped list layout with optional header and footer modes.
  public static func insetGrouped(
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .none,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .none,
    showsSeparators: Bool = true
  ) -> UICollectionViewCompositionalLayout {
    makeLayout(appearance: .insetGrouped, headerMode: headerMode, footerMode: footerMode, showsSeparators: showsSeparators)
  }

  /// Creates a sidebar list layout with optional header and footer modes.
  public static func sidebar(
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .none,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .none,
    showsSeparators: Bool = true
  ) -> UICollectionViewCompositionalLayout {
    makeLayout(appearance: .sidebar, headerMode: headerMode, footerMode: footerMode, showsSeparators: showsSeparators)
  }

  // MARK: Private

  private static func makeLayout(
    appearance: UICollectionLayoutListConfiguration.Appearance,
    headerMode: UICollectionLayoutListConfiguration.HeaderMode,
    footerMode: UICollectionLayoutListConfiguration.FooterMode,
    showsSeparators: Bool
  ) -> UICollectionViewCompositionalLayout {
    var config = UICollectionLayoutListConfiguration(appearance: appearance)
    config.headerMode = headerMode
    config.footerMode = footerMode
    config.showsSeparators = showsSeparators
    return UICollectionViewCompositionalLayout.list(using: config)
  }
}
