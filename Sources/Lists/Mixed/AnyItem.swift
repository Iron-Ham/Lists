import UIKit

/// Type-erased wrapper for any `CellViewModel`, enabling mixed cell types in a single data source.
///
/// Performance properties:
/// - `hash(into:)`: Two `combine` calls on precomputed values — no dynamic dispatch.
/// - `==` cross-type: One `ObjectIdentifier` comparison — single pointer compare.
/// - `==` same-type: Closure call + two `as?` casts + concrete `==`.
public struct AnyItem: Hashable, Sendable {
    private let _typeID: ObjectIdentifier
    private let _cachedHash: Int
    private let _isEqual: @Sendable (any Sendable, any Sendable) -> Bool
    private let _wrapped: any Sendable
    let _dequeue: @MainActor @Sendable (UICollectionView, IndexPath, DynamicCellRegistrar) -> UICollectionViewCell

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

    /// Extract the concrete `CellViewModel` value, if it matches the requested type.
    public func `as`<T: CellViewModel>(_: T.Type) -> T? {
        _wrapped as? T
    }

    public static func == (lhs: AnyItem, rhs: AnyItem) -> Bool {
        guard lhs._typeID == rhs._typeID else { return false }
        return lhs._isEqual(lhs._wrapped, rhs._wrapped)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_typeID)
        hasher.combine(_cachedHash)
    }
}

/// Lazily creates and caches `UICollectionView.CellRegistration` instances for each `CellViewModel` type.
///
/// After the first cell of each type is dequeued, subsequent lookups are a single dictionary access.
@MainActor
final class DynamicCellRegistrar {
    private var registrations: [ObjectIdentifier: Any] = [:]

    init() {}

    func dequeue<T: CellViewModel>(
        from collectionView: UICollectionView,
        at indexPath: IndexPath,
        item: T
    ) -> UICollectionViewCell {
        let key = ObjectIdentifier(T.self)
        let registration: UICollectionView.CellRegistration<T.Cell, T>
        if let existing = registrations[key] as? UICollectionView.CellRegistration<T.Cell, T> {
            registration = existing
        } else {
            registration = UICollectionView.CellRegistration { cell, _, item in
                item.configure(cell)
            }
            registrations[key] = registration
        }
        return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
    }
}
