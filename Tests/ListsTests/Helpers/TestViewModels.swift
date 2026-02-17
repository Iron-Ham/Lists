// ABOUTME: Shared test fixtures: TextItem (UUID-based) and NumberItem (value-based) CellViewModels.
// ABOUTME: Used across ListsTests for snapshot, DSL, and configuration testing.
import UIKit
@testable import Lists

// MARK: - TextItem

struct TextItem: CellViewModel {

  // MARK: Lifecycle

  init(id: UUID = UUID(), text: String) {
    self.id = id
    self.text = text
  }

  // MARK: Internal

  typealias Cell = UICollectionViewListCell

  let id: UUID
  let text: String

  static func ==(lhs: TextItem, rhs: TextItem) -> Bool {
    lhs.id == rhs.id
  }

  @MainActor
  func configure(_ cell: UICollectionViewListCell) {
    var content = cell.defaultContentConfiguration()
    content.text = text
    cell.contentConfiguration = content
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

// MARK: - NumberItem

struct NumberItem: CellViewModel {
  typealias Cell = UICollectionViewListCell

  let value: Int

  @MainActor
  func configure(_ cell: UICollectionViewListCell) {
    var content = cell.defaultContentConfiguration()
    content.text = "\(value)"
    cell.contentConfiguration = content
  }
}
