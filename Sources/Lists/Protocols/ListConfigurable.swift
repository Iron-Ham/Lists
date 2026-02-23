// ABOUTME: Shared protocol for common collection view convenience APIs.
// ABOUTME: Provides default implementations for selection, scrolling, and computed properties.
import ListKit
import UIKit

// MARK: - ListConfigurable

/// A protocol that provides common convenience APIs for list configurations.
///
/// `ListConfigurable` eliminates API duplication across ``SimpleList``, ``GroupedList``,
/// and ``OutlineList`` by deriving convenience members from just four requirements:
/// the collection view, a snapshot accessor, and item/index-path lookups.
///
/// ## Conforming Types
///
/// Conformance requires four members (all already public on each configuration):
/// - `collectionView` — the underlying `UICollectionView`
/// - `snapshot()` — returns a copy of the current diffable data source snapshot
/// - `itemIdentifier(for:)` — resolves an `IndexPath` to an item
/// - `indexPath(for:)` — resolves an item to an `IndexPath`
@MainActor
public protocol ListConfigurable: AnyObject {
  associatedtype SectionID: Hashable & Sendable
  associatedtype Item: CellViewModel

  /// The underlying collection view managed by this list configuration.
  var collectionView: UICollectionView { get }

  /// Returns a copy of the current snapshot.
  func snapshot() -> DiffableDataSourceSnapshot<SectionID, Item>

  /// Returns the item at the given index path, or `nil` if out of bounds.
  func itemIdentifier(for indexPath: IndexPath) -> Item?

  /// Returns the index path for the specified item, or `nil` if not found.
  func indexPath(for item: Item) -> IndexPath?
}

// MARK: - Default Implementations

extension ListConfigurable {

  /// A view displayed behind the list content.
  ///
  /// The view is placed as the collection view's `backgroundView`. Visibility is managed
  /// automatically by the list configuration after each data mutation.
  public var backgroundView: UIView? {
    get { collectionView.backgroundView }
    set { collectionView.backgroundView = newValue }
  }

  /// Whether the list allows multiple simultaneous selections.
  ///
  /// When `true`, tapping an item does not automatically deselect other items.
  public var allowsMultipleSelection: Bool {
    get { collectionView.allowsMultipleSelection }
    set { collectionView.allowsMultipleSelection = newValue }
  }

  /// Whether selection is allowed during editing mode.
  public var allowsSelectionDuringEditing: Bool {
    get { collectionView.allowsSelectionDuringEditing }
    set { collectionView.allowsSelectionDuringEditing = newValue }
  }

  /// Whether multiple selection is allowed during editing mode.
  public var allowsMultipleSelectionDuringEditing: Bool {
    get { collectionView.allowsMultipleSelectionDuringEditing }
    set { collectionView.allowsMultipleSelectionDuringEditing = newValue }
  }

  /// Whether the list is in editing mode.
  ///
  /// When `true`, cells may display editing controls such as delete and reorder accessories.
  public var isEditing: Bool {
    get { collectionView.isEditing }
    set { collectionView.isEditing = newValue }
  }

  /// The total number of items across all sections.
  public var numberOfItems: Int {
    snapshot().numberOfItems
  }

  /// The number of sections in the list.
  public var numberOfSections: Int {
    snapshot().numberOfSections
  }

  /// The currently selected items, derived from the collection view's selected index paths.
  public var selectedItems: [Item] {
    (collectionView.indexPathsForSelectedItems ?? []).compactMap { itemIdentifier(for: $0) }
  }

  /// Programmatically selects the specified item.
  ///
  /// - Parameters:
  ///   - item: The item to select.
  ///   - scrollPosition: Where to scroll after selecting. Pass `[]` for no scrolling.
  ///   - animated: Whether the selection should be animated.
  /// - Returns: `true` if the item was found and selected, `false` if not present.
  @discardableResult
  public func selectItem(
    _ item: Item,
    at scrollPosition: UICollectionView.ScrollPosition = [],
    animated: Bool = true
  ) -> Bool {
    guard let indexPath = indexPath(for: item) else { return false }
    collectionView.selectItem(at: indexPath, animated: animated, scrollPosition: scrollPosition)
    return true
  }

  /// Programmatically deselects the specified item.
  ///
  /// - Parameters:
  ///   - item: The item to deselect.
  ///   - animated: Whether the deselection should be animated.
  /// - Returns: `true` if the item was found and deselected, `false` if not present.
  @discardableResult
  public func deselectItem(_ item: Item, animated: Bool = true) -> Bool {
    guard let indexPath = indexPath(for: item) else { return false }
    collectionView.deselectItem(at: indexPath, animated: animated)
    return true
  }

  /// Returns whether the specified item is currently selected.
  public func isSelected(_ item: Item) -> Bool {
    guard let indexPath = indexPath(for: item) else { return false }
    return collectionView.indexPathsForSelectedItems?.contains(indexPath) ?? false
  }

  /// Deselects all currently selected items.
  ///
  /// - Parameter animated: Whether the deselection should be animated.
  public func deselectAll(animated: Bool = true) {
    for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
      collectionView.deselectItem(at: indexPath, animated: animated)
    }
  }

  /// Scrolls to the top of the list.
  public func scrollToTop(animated: Bool = true) {
    let topOffset = CGPoint(x: 0, y: -collectionView.adjustedContentInset.top)
    collectionView.setContentOffset(topOffset, animated: animated)
  }

  /// Scrolls to the bottom of the list.
  ///
  /// - Note: This method reads `contentSize` and `bounds`, which are zero before the
  ///   collection view has performed layout. Call after the view appears or after
  ///   `layoutIfNeeded()` to ensure correct behavior.
  public func scrollToBottom(animated: Bool = true) {
    let contentHeight = collectionView.contentSize.height
    let frameHeight = collectionView.bounds.height
    let bottomInset = collectionView.adjustedContentInset.bottom
    guard contentHeight > frameHeight else { return }
    let bottomOffset = CGPoint(x: 0, y: contentHeight - frameHeight + bottomInset)
    collectionView.setContentOffset(bottomOffset, animated: animated)
  }

  /// Programmatically scrolls to the specified item.
  ///
  /// - Returns: `true` if the item was found in the current snapshot and the scroll was
  ///   initiated, `false` if the item is not present.
  @discardableResult
  public func scrollToItem(
    _ item: Item,
    at scrollPosition: UICollectionView.ScrollPosition = .centeredVertically,
    animated: Bool = true
  ) -> Bool {
    guard let indexPath = indexPath(for: item) else { return false }
    collectionView.scrollToItem(at: indexPath, at: scrollPosition, animated: animated)
    return true
  }
}
