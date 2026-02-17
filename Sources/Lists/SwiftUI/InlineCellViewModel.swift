// ABOUTME: Type-erased CellViewModel wrapping a data value and @ViewBuilder closure.
// ABOUTME: Used by inline-content convenience inits on SwiftUI list wrappers.
import SwiftUI
import UIKit

/// A type-erased `CellViewModel` that stores a data value and a `@ViewBuilder` closure.
///
/// Used internally by the inline-content convenience initializers on `SimpleListView`,
/// `GroupedListView`, and `OutlineListView`. `Hashable`/`Equatable` is based on `data`
/// and `accessories` — the content closure is not compared.
public struct InlineCellViewModel<Data: Hashable & Sendable>: CellViewModel, Identifiable {

  // MARK: Lifecycle

  public init(
    data: Data,
    accessories: [ListAccessory] = [],
    @ViewBuilder content: @escaping @MainActor (Data) -> some View
  ) {
    self.data = data
    self.accessories = accessories
    self.content = { data in AnyView(content(data)) }
  }

  // MARK: Public

  public typealias Cell = UICollectionViewListCell

  public let data: Data

  public var id: Data {
    data
  }

  public static func ==(lhs: InlineCellViewModel, rhs: InlineCellViewModel) -> Bool {
    lhs.data == rhs.data && lhs.accessories == rhs.accessories
  }

  @MainActor
  public func configure(_ cell: UICollectionViewListCell) {
    cell.contentConfiguration = UIHostingConfiguration {
      content(data)
    }
    cell.accessories = accessories.map(\.uiAccessory)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(data)
    hasher.combine(accessories)
  }

  // MARK: Private

  private let content: @MainActor (Data) -> AnyView
  private let accessories: [ListAccessory]

}
