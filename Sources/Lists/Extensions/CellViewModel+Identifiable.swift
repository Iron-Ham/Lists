import Foundation

/// Automatic id-based `Hashable`/`Equatable` for `CellViewModel & Identifiable`.
///
/// **Important:** Only `id` is used for equality and hashing. Properties beyond `id`
/// (e.g. title, subtitle, image) are **not** considered by the diff — the algorithm
/// treats two items with the same `id` as identical even if their content differs.
///
/// To update visible cells after content-only changes, mark items for reconfigure:
/// ```swift
/// snapshot.reconfigureItems([updatedItem])
/// ```
extension CellViewModel where Self: Identifiable, ID: Hashable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
