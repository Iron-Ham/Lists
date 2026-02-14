import UIKit

/// A reference-type bridge that resolves `IndexPath` → `Item` for swipe action providers.
///
/// Created before `super.init()` and captured by the layout config closure. Populated
/// with `dataSource` and provider closures after init completes. This solves Swift's
/// strict initialization rules — the layout config needs a closure that references the
/// data source, but the data source isn't available until after `super.init()`.
@MainActor
final class SwipeActionBridge<SectionID: Hashable & Sendable, Item: CellViewModel> {
    var dataSource: ListDataSource<SectionID, Item>?
    var trailingProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
    var leadingProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?

    func resolveTrailing(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource?.itemIdentifier(for: indexPath) else { return nil }
        return trailingProvider?(item)
    }

    func resolveLeading(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource?.itemIdentifier(for: indexPath) else { return nil }
        return leadingProvider?(item)
    }

    /// Configures both swipe action providers on a list layout configuration.
    func configureSwipeActions(on config: inout UICollectionLayoutListConfiguration) {
        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            self?.resolveTrailing(at: indexPath)
        }
        config.leadingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            self?.resolveLeading(at: indexPath)
        }
    }
}
