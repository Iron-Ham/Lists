import UIKit

@MainActor
public enum ListLayout {
    public static func plain(
        headerMode: UICollectionLayoutListConfiguration.HeaderMode = .none,
        footerMode: UICollectionLayoutListConfiguration.FooterMode = .none
    ) -> UICollectionViewCompositionalLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.headerMode = headerMode
        config.footerMode = footerMode
        return UICollectionViewCompositionalLayout.list(using: config)
    }

    public static func insetGrouped(
        headerMode: UICollectionLayoutListConfiguration.HeaderMode = .none,
        footerMode: UICollectionLayoutListConfiguration.FooterMode = .none
    ) -> UICollectionViewCompositionalLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = headerMode
        config.footerMode = footerMode
        return UICollectionViewCompositionalLayout.list(using: config)
    }

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
