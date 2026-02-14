import UIKit

// MARK: - AnyItem

/// Type-erased wrapper for any `CellViewModel`, enabling mixed cell types in a single data source.
///
/// Performance properties:
/// - `hash(into:)`: Two `combine` calls on precomputed values — no dynamic dispatch.
/// - `==` cross-type: One `ObjectIdentifier` comparison — single pointer compare.
/// - `==` same-type: Closure call + two `as?` casts + concrete `==`.
public struct AnyItem: Hashable, Sendable {

  // MARK: Lifecycle

  /// Wraps a concrete `CellViewModel` value in a type-erased container.
  public init<T: CellViewModel>(_ item: T) {
    _typeID = ObjectIdentifier(T.self)
    _cachedHash = item.hashValue
    _isEqual = { lhs, rhs in
      guard let lhs = lhs as? T, let rhs = rhs as? T else { return false }
      return lhs == rhs
    }
    _wrapped = item
    _dequeue = { collectionView, indexPath, registrar in
      registrar.dequeue(from: collectionView, at: indexPath, item: item)
    }
  }

  // MARK: Public

  public static func ==(lhs: AnyItem, rhs: AnyItem) -> Bool {
    guard lhs._typeID == rhs._typeID else { return false }
    return lhs._isEqual(lhs._wrapped, rhs._wrapped)
  }

  /// Extract the concrete `CellViewModel` value, if it matches the requested type.
  public func `as`<T: CellViewModel>(_: T.Type) -> T? {
    _wrapped as? T
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(_typeID)
    hasher.combine(_cachedHash)
  }

  // MARK: Internal

  let _dequeue: @MainActor @Sendable (UICollectionView, IndexPath, DynamicCellRegistrar) -> UICollectionViewCell

  // MARK: Private

  private let _typeID: ObjectIdentifier
  private let _cachedHash: Int
  private let _isEqual: @Sendable (any Sendable, any Sendable) -> Bool
  private let _wrapped: any Sendable

}

// MARK: - DynamicCellRegistrar

/// Lazily registers cell classes and dequeues cells for each `CellViewModel` type.
///
/// Uses traditional `register`/`dequeueReusableCell` instead of `CellRegistration`
/// because `CellRegistration` cannot be created inside a cell provider callback.
/// After the first cell of each type is registered, subsequent lookups are a set membership check.
@MainActor
final class DynamicCellRegistrar {

  // MARK: Lifecycle

  init() { }

  // MARK: Internal

  func dequeue<T: CellViewModel>(
    from collectionView: UICollectionView,
    at indexPath: IndexPath,
    item: T
  ) -> UICollectionViewCell {
    let key = ObjectIdentifier(T.Cell.self)
    if !registeredTypes.contains(key) {
      collectionView.register(T.Cell.self, forCellWithReuseIdentifier: String(reflecting: T.Cell.self))
      registeredTypes.insert(key)
    }
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: String(reflecting: T.Cell.self),
      for: indexPath
    )
    if let typedCell = cell as? T.Cell {
      item.configure(typedCell)
    }
    return cell
  }

  // MARK: Private

  private var registeredTypes = Set<ObjectIdentifier>()

}
