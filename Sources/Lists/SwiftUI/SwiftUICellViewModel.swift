import SwiftUI
import UIKit

// MARK: - SwiftUICellViewModel

/// A ``CellViewModel`` that uses a SwiftUI `body` to define cell content.
///
/// Conformers provide a SwiftUI `View` via `body` and optionally override
/// `accessories` to add cell accessories like disclosure indicators.
///
/// The default `configure(_:)` implementation renders `body` inside a
/// `UIHostingConfiguration`. **Do not override `configure(_:)`** — doing so
/// will cause `body` and `accessories` to be silently ignored.
public protocol SwiftUICellViewModel: CellViewModel where Cell == UICollectionViewListCell {
  associatedtype Content: View

  @MainActor
  var body: Content { get }
  @MainActor
  var accessories: [ListAccessory] { get }
}

extension SwiftUICellViewModel {
  @MainActor
  public var accessories: [ListAccessory] {
    []
  }

  @MainActor
  public func configure(_ cell: UICollectionViewListCell) {
    cell.contentConfiguration = UIHostingConfiguration { body }
    cell.accessories = accessories.map(\.uiAccessory)
  }
}
