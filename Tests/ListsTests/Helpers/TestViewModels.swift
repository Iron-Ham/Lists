@testable import Lists
import UIKit

struct TextItem: CellViewModel {
    typealias Cell = UICollectionViewListCell
    let id: UUID
    let text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }

    @MainActor func configure(_ cell: UICollectionViewListCell) {
        var content = cell.defaultContentConfiguration()
        content.text = text
        cell.contentConfiguration = content
    }

    static func == (lhs: TextItem, rhs: TextItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct NumberItem: CellViewModel {
    typealias Cell = UICollectionViewListCell
    let value: Int

    @MainActor func configure(_ cell: UICollectionViewListCell) {
        var content = cell.defaultContentConfiguration()
        content.text = "\(value)"
        cell.contentConfiguration = content
    }
}
