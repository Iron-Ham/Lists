import ListKit
import UIKit

@MainActor
public final class GroupedList<SectionID: Hashable & Sendable, Item: CellViewModel>: NSObject, UICollectionViewDelegate {
    public let collectionView: UICollectionView
    private let dataSource: ListDataSource<SectionID, Item>
    private var sectionHeaders: [SectionID: String] = [:]
    private var sectionFooters: [SectionID: String] = [:]
    private var applyTask: Task<Void, Never>?

    public var onSelect: (@MainActor (Item) -> Void)?

    public init(appearance: UICollectionLayoutListConfiguration.Appearance = .insetGrouped) {
        var config = UICollectionLayoutListConfiguration(appearance: appearance)
        config.headerMode = .supplementary
        config.footerMode = .supplementary
        let layout = UICollectionViewCompositionalLayout.list(using: config)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        dataSource = ListDataSource(collectionView: collectionView)
        super.init()
        collectionView.delegate = self
        setupSupplementaryViews()
    }

    public func setSections(_ sections: [SectionModel<SectionID, Item>], animatingDifferences: Bool = true) async {
        let previousTask = applyTask
        let task = Task { @MainActor in
            _ = await previousTask?.value
            self.sectionHeaders.removeAll()
            self.sectionFooters.removeAll()
            for section in sections {
                if let header = section.header {
                    self.sectionHeaders[section.id] = header
                }
                if let footer = section.footer {
                    self.sectionFooters[section.id] = footer
                }
            }
            await self.dataSource.apply(sections, animatingDifferences: animatingDifferences)
        }
        applyTask = task
        await task.value
    }

    public func snapshot() -> DiffableDataSourceSnapshot<SectionID, Item> {
        dataSource.snapshot()
    }

    // MARK: - UICollectionViewDelegate

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        onSelect?(item)
    }

    // MARK: - Private

    private func setupSupplementaryViews() {
        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] supplementaryView, _, indexPath in
            guard let self else { return }
            let snapshot = dataSource.snapshot()
            let sectionID = snapshot.sectionIdentifiers[indexPath.section]
            var content = UIListContentConfiguration.groupedHeader()
            content.text = sectionHeaders[sectionID]
            supplementaryView.contentConfiguration = content
        }

        let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] supplementaryView, _, indexPath in
            guard let self else { return }
            let snapshot = dataSource.snapshot()
            let sectionID = snapshot.sectionIdentifiers[indexPath.section]
            var content = UIListContentConfiguration.groupedFooter()
            content.text = sectionFooters[sectionID]
            supplementaryView.contentConfiguration = content
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            case UICollectionView.elementKindSectionFooter:
                collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
            default:
                nil
            }
        }
    }
}
