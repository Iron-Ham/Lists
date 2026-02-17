// ABOUTME: Opt-in protocol for automatic content change detection in data sources.
// ABOUTME: Enables auto-reconfigure when identity matches but content differs.
// MARK: - ContentEquatable

/// Opt-in protocol for automatic content change detection in diffable data sources.
///
/// When a ``CellViewModel`` conforms to `ContentEquatable`, the framework's data sources
/// automatically detect content changes between snapshots and reconfigure affected cells.
/// This eliminates the need to manually call `reconfigureItems(_:)` after content-only updates.
///
/// **When to use:** Adopt `ContentEquatable` when your ``CellViewModel`` uses identity-based
/// equality (e.g., via `Identifiable` conformance) where only `id` is compared. Without
/// `ContentEquatable`, changing properties like `title` or `subtitle` while keeping the same
/// `id` would be invisible to the diff algorithm.
///
/// **When not to use:** If your `Hashable`/`Equatable` implementation already considers all
/// visible properties, there is no benefit — the diff algorithm handles changes automatically.
///
/// ```swift
/// struct ContactItem: CellViewModel, Identifiable, ContentEquatable {
///     typealias Cell = UICollectionViewListCell
///     let id: UUID
///     var name: String
///     var avatarURL: URL?
///
///     func isContentEqual(to other: ContactItem) -> Bool {
///         name == other.name && avatarURL == other.avatarURL
///     }
///
///     func configure(_ cell: UICollectionViewListCell) { … }
/// }
/// ```
public protocol ContentEquatable: Sendable {
  /// Returns `true` when the receiver's visible content matches `other`.
  ///
  /// Called only for items whose identity already matches (same `Hashable` value).
  /// Return `false` to trigger automatic cell reconfiguration.
  func isContentEqual(to other: Self) -> Bool
}

extension ContentEquatable {
  /// Type-erased content equality check used internally by data sources.
  ///
  /// Uses Swift's implicit existential opening — when called on `any ContentEquatable`,
  /// `Self` resolves to the underlying concrete type, making the `as? Self` cast correct.
  func isContentEqualTypeErased(to other: Any) -> Bool {
    guard let other = other as? Self else { return false }
    return isContentEqual(to: other)
  }
}
