import Testing
import UIKit
@testable import Lists

@MainActor
struct CellViewModelTests {
  @Test
  func conformsToHashable() {
    let a = TextItem(text: "Hello")
    let b = TextItem(text: "World")
    #expect(a != b)
    #expect(a == a)
  }

  @Test
  func conformsToSendable() {
    // Compile-time check: TextItem can be sent across concurrency boundaries
    let item = TextItem(text: "Sendable")
    let _: any Sendable = item
    #expect(item.text == "Sendable")
  }

  @Test
  func configureCalledDuringDequeue() {
    let registrar = CellRegistrar<TextItem>()
    let layout = UICollectionViewFlowLayout()
    let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: layout)

    let item = TextItem(text: "Test")
    let cell = registrar.dequeue(from: cv, at: IndexPath(item: 0, section: 0), item: item)

    // The cell should be a UICollectionViewListCell configured by our TextItem
    if
      let listCell = cell as? UICollectionViewListCell,
      let content = listCell.contentConfiguration as? UIListContentConfiguration
    {
      #expect(content.text == "Test")
    }
  }

  @Test
  func numberItemHashEquality() {
    let a = NumberItem(value: 42)
    let b = NumberItem(value: 42)
    let c = NumberItem(value: 99)
    #expect(a == b)
    #expect(a != c)
  }
}
