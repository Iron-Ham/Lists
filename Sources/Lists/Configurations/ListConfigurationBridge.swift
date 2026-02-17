// ABOUTME: Shared bridge resolving IndexPath-to-Item for layout config handlers.
// ABOUTME: Centralizes delegate logic (swipe, separator, selection) across list types.
@preconcurrency import UIKit

/// A reference-type bridge that resolves `IndexPath` -> `Item` for layout configuration handlers
/// and centralizes shared delegate logic across all list types.
///
/// Created before `super.init()` and captured by the layout config closures. Populated
/// with `dataSource` and provider closures after init completes. This solves Swift's
/// strict initialization rules -- the layout config needs closures that reference the
/// data source, but the data source isn't available until after `super.init()`.
///
/// ## Ownership Model
///
/// The owning list class holds a strong reference to this bridge. The bridge's closures
/// (trailing/leading providers, separator handler) capture the list weakly via `[weak self]`
/// in the list's initializer, preventing retain cycles. Layout configuration closures also
/// capture this bridge weakly, so deallocation of the list allows the entire chain to be freed.
@MainActor
final class ListConfigurationBridge<SectionID: Hashable & Sendable, Item: CellViewModel> {

  // MARK: Internal

  /// Sets the data source reference. Called once during the owning list's initializer,
  /// after `super.init()` completes.
  func setDataSource(_ dataSource: ListDataSource<SectionID, Item>) {
    self.dataSource = dataSource
  }

  /// Sets the global separator color. Called during the owning list's initializer.
  func setDefaultSeparatorColor(_ color: UIColor?) {
    defaultSeparatorColor = color
  }

  /// Sets the trailing swipe action provider closure.
  func setTrailingProvider(_ provider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?) {
    trailingProvider = provider
  }

  /// Sets the leading swipe action provider closure.
  func setLeadingProvider(_ provider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?) {
    leadingProvider = provider
  }

  /// Sets the per-item separator customization handler.
  func setSeparatorProvider(_ provider: (@MainActor (Item, UIListSeparatorConfiguration) -> UIListSeparatorConfiguration)?) {
    separatorProvider = provider
  }

  /// Configures swipe action providers and separator handler on a list layout configuration.
  ///
  /// The closures use `MainActor.assumeIsolated` to assert the runtime invariant that
  /// UIKit always invokes these on the main thread. This satisfies Swift 6 strict
  /// concurrency checking without requiring the closure signatures to change.
  func configure(_ config: inout UICollectionLayoutListConfiguration) {
    config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
      MainActor.assumeIsolated {
        self?.resolveTrailing(at: indexPath)
      }
    }
    config.leadingSwipeActionsConfigurationProvider = { [weak self] indexPath in
      MainActor.assumeIsolated {
        self?.resolveLeading(at: indexPath)
      }
    }
    config.itemSeparatorHandler = { [weak self] indexPath, defaultConfig in
      MainActor.assumeIsolated {
        self?.resolveSeparator(at: indexPath, defaultConfiguration: defaultConfig) ?? defaultConfig
      }
    }
  }

  /// Handles a `didSelectItemAt` delegate call: auto-deselects in single-selection mode,
  /// resolves the item, and forwards to the provided callback.
  func handleDidSelect(
    in collectionView: UICollectionView,
    at indexPath: IndexPath,
    onSelect: (@MainActor (Item) -> Void)?
  ) {
    if !collectionView.allowsMultipleSelection {
      collectionView.deselectItem(at: indexPath, animated: true)
    }
    guard let item = dataSource?.itemIdentifier(for: indexPath) else {
      assertionFailure("Item not found for indexPath \(indexPath)")
      collectionView.deselectItem(at: indexPath, animated: true)
      return
    }
    onSelect?(item)
  }

  /// Handles a `didDeselectItemAt` delegate call.
  func handleDidDeselect(
    at indexPath: IndexPath,
    onDeselect: (@MainActor (Item) -> Void)?
  ) {
    guard let item = dataSource?.itemIdentifier(for: indexPath) else {
      assertionFailure("Item not found for indexPath \(indexPath)")
      return
    }
    onDeselect?(item)
  }

  /// Handles a `contextMenuConfigurationForItemAt` delegate call.
  func handleContextMenu(
    at indexPath: IndexPath,
    provider: (@MainActor (Item) -> UIContextMenuConfiguration?)?
  ) -> UIContextMenuConfiguration? {
    guard let item = dataSource?.itemIdentifier(for: indexPath) else {
      assertionFailure("Item not found for indexPath \(indexPath)")
      return nil
    }
    return provider?(item)
  }

  /// Returns the item at the given index path, or `nil` if out of bounds.
  func itemIdentifier(for indexPath: IndexPath) -> Item? {
    dataSource?.itemIdentifier(for: indexPath)
  }

  /// Returns the index path for the specified item, or `nil` if not found.
  func indexPath(for item: Item) -> IndexPath? {
    dataSource?.indexPath(for: item)
  }

  /// Returns the section identifier for the given section index.
  func sectionIdentifier(for index: Int) -> SectionID? {
    dataSource?.sectionIdentifier(for: index)
  }

  /// Returns the index of the specified section identifier.
  func index(for sectionIdentifier: SectionID) -> Int? {
    dataSource?.index(for: sectionIdentifier)
  }

  /// Programmatically scrolls to the specified item.
  ///
  /// - Returns: `true` if the item was found and the scroll was initiated, `false` if the
  ///   item is not present in the current snapshot.
  @discardableResult
  func scrollToItem(
    _ item: Item,
    in collectionView: UICollectionView,
    at scrollPosition: UICollectionView.ScrollPosition = .centeredVertically,
    animated: Bool = true
  ) -> Bool {
    guard let indexPath = dataSource?.indexPath(for: item) else { return false }
    collectionView.scrollToItem(at: indexPath, at: scrollPosition, animated: animated)
    return true
  }

  /// Programmatically selects the specified item.
  ///
  /// - Returns: `true` if the item was found and selected, `false` if not present.
  @discardableResult
  func selectItem(
    _ item: Item,
    in collectionView: UICollectionView,
    at scrollPosition: UICollectionView.ScrollPosition = [],
    animated: Bool = true
  ) -> Bool {
    guard let indexPath = dataSource?.indexPath(for: item) else { return false }
    collectionView.selectItem(at: indexPath, animated: animated, scrollPosition: scrollPosition)
    return true
  }

  /// Programmatically deselects the specified item.
  ///
  /// - Returns: `true` if the item was found and deselected, `false` if not present.
  @discardableResult
  func deselectItem(
    _ item: Item,
    in collectionView: UICollectionView,
    animated: Bool = true
  ) -> Bool {
    guard let indexPath = dataSource?.indexPath(for: item) else { return false }
    collectionView.deselectItem(at: indexPath, animated: animated)
    return true
  }

  /// Returns whether the specified item is currently selected.
  func isSelected(_ item: Item, in collectionView: UICollectionView) -> Bool {
    guard let indexPath = dataSource?.indexPath(for: item) else { return false }
    return collectionView.indexPathsForSelectedItems?.contains(indexPath) ?? false
  }

  /// Handles a `shouldSelectItemAt` delegate call.
  func handleShouldSelect(
    at indexPath: IndexPath,
    shouldSelect: (@MainActor (Item) -> Bool)?
  ) -> Bool {
    guard let shouldSelect else { return true }
    guard let item = dataSource?.itemIdentifier(for: indexPath) else {
      assertionFailure("Item not found for indexPath \(indexPath)")
      return true
    }
    return shouldSelect(item)
  }

  /// Scrolls to the top of the collection view.
  func scrollToTop(in collectionView: UICollectionView, animated: Bool) {
    let topOffset = CGPoint(x: 0, y: -collectionView.adjustedContentInset.top)
    collectionView.setContentOffset(topOffset, animated: animated)
  }

  /// Scrolls to the bottom of the collection view.
  func scrollToBottom(in collectionView: UICollectionView, animated: Bool) {
    let contentHeight = collectionView.contentSize.height
    let frameHeight = collectionView.bounds.height
    let bottomInset = collectionView.adjustedContentInset.bottom
    guard contentHeight > frameHeight else { return }
    let bottomOffset = CGPoint(x: 0, y: contentHeight - frameHeight + bottomInset)
    collectionView.setContentOffset(bottomOffset, animated: animated)
  }

  /// Resolves the separator configuration for an item.
  ///
  /// Uses optional chaining for `dataSource` rather than `assertionFailure` because
  /// `itemSeparatorHandler` can be invoked during early layout passes before `dataSource`
  /// is populated. Falls back to the default (or global-color) configuration.
  func resolveSeparator(
    at indexPath: IndexPath,
    defaultConfiguration: UIListSeparatorConfiguration
  ) -> UIListSeparatorConfiguration {
    var config = defaultConfiguration
    if let defaultSeparatorColor {
      config.color = defaultSeparatorColor
    }
    guard let item = dataSource?.itemIdentifier(for: indexPath) else { return config }
    return separatorProvider?(item, config) ?? config
  }

  // MARK: Private

  private var dataSource: ListDataSource<SectionID, Item>?
  private var trailingProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  private var leadingProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  private var defaultSeparatorColor: UIColor?
  private var separatorProvider: (@MainActor (Item, UIListSeparatorConfiguration) -> UIListSeparatorConfiguration)?

  /// Swipe action providers use `assertionFailure` for a nil `dataSource` because they
  /// should never be invoked before `setDataSource(_:)` is called -- unlike the separator
  /// handler which may fire during early layout passes.
  private func resolveTrailing(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard let dataSource else {
      assertionFailure("ListConfigurationBridge.dataSource is nil when resolving trailing swipe action")
      return nil
    }
    guard let item = dataSource.itemIdentifier(for: indexPath) else {
      assertionFailure("Item not found at \(indexPath)")
      return nil
    }
    return trailingProvider?(item)
  }

  private func resolveLeading(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard let dataSource else {
      assertionFailure("ListConfigurationBridge.dataSource is nil when resolving leading swipe action")
      return nil
    }
    guard let item = dataSource.itemIdentifier(for: indexPath) else {
      assertionFailure("Item not found at \(indexPath)")
      return nil
    }
    return leadingProvider?(item)
  }
}
