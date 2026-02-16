import UIKit

/// A convenience refinement of ``CellViewModel`` that defaults the cell type to `UICollectionViewListCell`.
///
/// Most list cells use `UICollectionViewListCell`, making the `typealias Cell` declaration
/// pure boilerplate. `ListCellViewModel` eliminates it:
///
/// ```swift
/// // Before:
/// struct ContactItem: CellViewModel, Identifiable {
///     typealias Cell = UICollectionViewListCell
///     let id: UUID
///     let name: String
///     func configure(_ cell: UICollectionViewListCell) { ... }
/// }
///
/// // After:
/// struct ContactItem: ListCellViewModel, Identifiable {
///     let id: UUID
///     let name: String
///     func configure(_ cell: UICollectionViewListCell) { ... }
/// }
/// ```
///
/// For cells that need a custom `UICollectionViewCell` subclass, use ``CellViewModel`` directly.
public protocol ListCellViewModel: CellViewModel where Cell == UICollectionViewListCell { }
