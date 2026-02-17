// ABOUTME: Core CellViewModel protocol: Hashable + Sendable + cell configuration.
// ABOUTME: Also defines CellRegistrar for automatic UICollectionView.CellRegistration.
import UIKit

// MARK: - CellViewModel

/// A value type that pairs a data model with a `UICollectionViewCell` subclass.
///
/// Implement ``configure(_:)`` to populate cell content. The framework handles
/// cell registration and dequeuing automatically.
///
/// Conform to `Identifiable` to get free `Hashable`/`Equatable` based on `id`,
/// which is what the diff algorithm uses to track identity across snapshots.
public protocol CellViewModel: Hashable, Sendable {
  /// The cell class this view model configures.
  associatedtype Cell: UICollectionViewCell

  /// Populates the given cell with the view model's data.
  @MainActor
  func configure(_ cell: Cell)
}

// MARK: - CellRegistrar

@MainActor
final class CellRegistrar<Item: CellViewModel> {

  // MARK: Lifecycle

  init() {
    registration = UICollectionView.CellRegistration { cell, _, item in
      item.configure(cell)
    }
  }

  // MARK: Internal

  let registration: UICollectionView.CellRegistration<Item.Cell, Item>

  func dequeue(from collectionView: UICollectionView, at indexPath: IndexPath, item: Item) -> UICollectionViewCell {
    collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
  }
}
