import Testing
import UIKit
@testable import Lists

// MARK: - SimpleTextItem

/// A CellViewModel using the new ListCellViewModel convenience protocol.
struct SimpleTextItem: ListCellViewModel, Identifiable {
  init(id: UUID = UUID(), text: String) {
    self.id = id
    self.text = text
  }

  let id: UUID
  let text: String

  @MainActor
  func configure(_ cell: UICollectionViewListCell) {
    cell.setListContent(text: text)
  }
}

// MARK: - DetailItem

/// A CellViewModel using setListContent with all parameters.
struct DetailItem: ListCellViewModel, Identifiable {
  init(id: UUID = UUID(), title: String, subtitle: String) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
  }

  let id: UUID
  let title: String
  let subtitle: String

  @MainActor
  func configure(_ cell: UICollectionViewListCell) {
    cell.setListContent(
      text: title,
      secondaryText: subtitle,
      image: UIImage(systemName: "star"),
      accessories: [.disclosureIndicator]
    )
  }
}

// MARK: - CustomItem

/// A CellViewModel using the closure-based setListContent.
struct CustomItem: ListCellViewModel, Identifiable {
  init(id: UUID = UUID(), text: String) {
    self.id = id
    self.text = text
  }

  let id: UUID
  let text: String

  @MainActor
  func configure(_ cell: UICollectionViewListCell) {
    cell.setListContent(accessories: [.checkmark]) { content in
      content.text = text
      content.textProperties.font = .preferredFont(forTextStyle: .headline)
    }
  }
}

// MARK: - ListCellViewModelTests

@MainActor
struct ListCellViewModelTests {
  @Test
  func listCellViewModelConformsToCellViewModel() {
    let item = SimpleTextItem(text: "Hello")
    let _: any CellViewModel = item
    #expect(item.text == "Hello")
  }

  @Test
  func listCellViewModelUsesListCell() {
    let registrar = CellRegistrar<SimpleTextItem>()
    let layout = UICollectionViewFlowLayout()
    let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: layout)

    let item = SimpleTextItem(text: "Test")
    let cell = registrar.dequeue(from: cv, at: IndexPath(item: 0, section: 0), item: item)

    #expect(cell is UICollectionViewListCell)
  }

  @Test
  func listCellViewModelIdentifiableHashable() {
    let id = UUID()
    let a = SimpleTextItem(id: id, text: "A")
    let b = SimpleTextItem(id: id, text: "B")
    let c = SimpleTextItem(text: "C")

    // Identifiable-based equality: same id == equal
    #expect(a == b)
    #expect(a != c)
    #expect(a.hashValue == b.hashValue)
  }

  @Test
  func listCellViewModelWorksWithSimpleList() async {
    let list = SimpleList<SimpleTextItem>()
    let items = [
      SimpleTextItem(text: "One"),
      SimpleTextItem(text: "Two"),
      SimpleTextItem(text: "Three"),
    ]

    await list.setItems(items, animatingDifferences: false)

    let snapshot = list.snapshot()
    #expect(snapshot.numberOfItems == 3)
  }
}

// MARK: - SetListContentTests

@MainActor
struct SetListContentTests {
  @Test
  func setListContentAppliesText() throws {
    let cell = UICollectionViewListCell()
    cell.setListContent(text: "Hello")

    let config = try #require(cell.contentConfiguration as? UIListContentConfiguration, "Expected UIListContentConfiguration")
    #expect(config.text == "Hello")
    #expect(config.secondaryText == nil)
    #expect(config.image == nil)
  }

  @Test
  func setListContentAppliesAllProperties() throws {
    let cell = UICollectionViewListCell()
    let image = UIImage(systemName: "star")
    cell.setListContent(
      text: "Title",
      secondaryText: "Subtitle",
      image: image,
      accessories: [.disclosureIndicator]
    )

    let config = try #require(cell.contentConfiguration as? UIListContentConfiguration, "Expected UIListContentConfiguration")
    #expect(config.text == "Title")
    #expect(config.secondaryText == "Subtitle")
    #expect(config.image != nil)
    #expect(cell.accessories.count == 1)
  }

  @Test
  func setListContentEmptyAccessoriesClearsPrevious() {
    let cell = UICollectionViewListCell()
    cell.accessories = [.disclosureIndicator()]
    cell.setListContent(text: "Hello")

    // Empty accessories array clears previous accessories (cell reuse safety)
    #expect(cell.accessories.isEmpty)
  }

  @Test
  func setListContentWithClosure() throws {
    let cell = UICollectionViewListCell()
    cell.setListContent { content in
      content.text = "Custom"
      content.textProperties.font = .preferredFont(forTextStyle: .headline)
    }

    let config = try #require(cell.contentConfiguration as? UIListContentConfiguration, "Expected UIListContentConfiguration")
    #expect(config.text == "Custom")
  }

  @Test
  func setListContentWithClosureAndAccessories() throws {
    let cell = UICollectionViewListCell()
    cell.setListContent(accessories: [.checkmark, .disclosureIndicator]) { content in
      content.text = "Test"
    }

    let config = try #require(cell.contentConfiguration as? UIListContentConfiguration, "Expected UIListContentConfiguration")
    #expect(config.text == "Test")
    #expect(cell.accessories.count == 2)
  }
}

// MARK: - SimpleListViewModifierTests

@MainActor
struct SimpleListViewModifierTests {
  @Test
  func onSelectModifier() {
    var called = false
    let view = SimpleListView(items: [SimpleTextItem(text: "A")])
      .onSelect { _ in called = true }

    #expect(view.onSelect != nil)
    view.onSelect?(SimpleTextItem(text: "A"))
    #expect(called)
  }

  @Test
  func onDeleteModifier() {
    var deleted: SimpleTextItem?
    let view = SimpleListView(items: [SimpleTextItem(text: "A")])
      .onDelete { item in deleted = item }

    let item = SimpleTextItem(text: "B")
    view.onDelete?(item)
    #expect(deleted == item)
  }

  @Test
  func onRefreshModifier() {
    let view = SimpleListView(items: [SimpleTextItem(text: "A")])
      .onRefresh { }

    #expect(view.onRefresh != nil)
  }

  @Test
  func editingModifier() {
    let view = SimpleListView(items: [SimpleTextItem(text: "A")])
      .editing(true)

    #expect(view.isEditing == true)
  }

  @Test
  func allowsMultipleSelectionModifier() {
    let view = SimpleListView(items: [SimpleTextItem(text: "A")])
      .allowsMultipleSelection()

    #expect(view.allowsMultipleSelection == true)
  }

  @Test
  func chainingMultipleModifiers() {
    var selectCalled = false
    var deleteCalled = false

    let view = SimpleListView(items: [SimpleTextItem(text: "A")])
      .onSelect { _ in selectCalled = true }
      .onDelete { _ in deleteCalled = true }
      .editing(true)
      .allowsMultipleSelection()
      .onRefresh { }

    #expect(view.onSelect != nil)
    #expect(view.onDelete != nil)
    #expect(view.onRefresh != nil)
    #expect(view.isEditing == true)
    #expect(view.allowsMultipleSelection == true)

    view.onSelect?(SimpleTextItem(text: "A"))
    view.onDelete?(SimpleTextItem(text: "A"))
    #expect(selectCalled)
    #expect(deleteCalled)
  }

  @Test
  func modifiersDoNotMutateOriginal() {
    let original = SimpleListView(items: [SimpleTextItem(text: "A")])
    let modified = original.onSelect { _ in }

    #expect(original.onSelect == nil)
    #expect(modified.onSelect != nil)
  }
}

// MARK: - GroupedListViewModifierTests

@MainActor
struct GroupedListViewModifierTests {
  @Test
  func onSelectModifier() {
    var called = false
    let view = GroupedListView(
      sections: [SectionModel(id: "s1", items: [SimpleTextItem(text: "A")])]
    )
    .onSelect { _ in called = true }

    view.onSelect?(SimpleTextItem(text: "A"))
    #expect(called)
  }

  @Test
  func headerContentProviderModifier() {
    var calledWith: String?
    let view = GroupedListView(
      sections: [SectionModel(id: "s1", items: [SimpleTextItem(text: "A")])]
    )
    .headerContentProvider { sectionID -> UIContentConfiguration? in
      calledWith = sectionID
      return nil
    }

    _ = view.headerContentProvider?("test")
    #expect(calledWith == "test")
  }

  @Test
  func chainingMultipleModifiers() {
    let view = GroupedListView(
      sections: [SectionModel(id: "s1", items: [SimpleTextItem(text: "A")])]
    )
    .onSelect { _ in }
    .onDelete { _ in }
    .editing(true)
    .onRefresh { }
    .headerContentProvider { _ in nil }
    .footerContentProvider { _ in nil }

    #expect(view.onSelect != nil)
    #expect(view.onDelete != nil)
    #expect(view.isEditing == true)
    #expect(view.onRefresh != nil)
    #expect(view.headerContentProvider != nil)
    #expect(view.footerContentProvider != nil)
  }
}

// MARK: - OutlineListViewModifierTests

@MainActor
struct OutlineListViewModifierTests {
  @Test
  func onSelectModifier() {
    var called = false
    let view = OutlineListView(
      items: [OutlineItem(item: SimpleTextItem(text: "A"))]
    )
    .onSelect { _ in called = true }

    view.onSelect?(SimpleTextItem(text: "A"))
    #expect(called)
  }

  @Test
  func chainingMultipleModifiers() {
    let view = OutlineListView(
      items: [OutlineItem(item: SimpleTextItem(text: "A"))]
    )
    .onSelect { _ in }
    .onDelete { _ in }
    .editing(true)
    .allowsMultipleSelection()
    .onRefresh { }

    #expect(view.onSelect != nil)
    #expect(view.onDelete != nil)
    #expect(view.isEditing == true)
    #expect(view.allowsMultipleSelection == true)
    #expect(view.onRefresh != nil)
  }
}

// MARK: - PullToRefreshTests

@MainActor
struct PullToRefreshTests {
  @Test
  func simpleListOnRefreshAddsRefreshControl() {
    let list = SimpleList<SimpleTextItem>()
    #expect(list.collectionView.refreshControl == nil)

    list.onRefresh = { }
    #expect(list.collectionView.refreshControl != nil)
  }

  @Test
  func simpleListClearingOnRefreshRemovesRefreshControl() {
    let list = SimpleList<SimpleTextItem>()
    list.onRefresh = { }
    #expect(list.collectionView.refreshControl != nil)

    list.onRefresh = nil
    #expect(list.collectionView.refreshControl == nil)
  }

  @Test
  func groupedListOnRefreshAddsRefreshControl() {
    let list = GroupedList<String, SimpleTextItem>()
    #expect(list.collectionView.refreshControl == nil)

    list.onRefresh = { }
    #expect(list.collectionView.refreshControl != nil)
  }

  @Test
  func outlineListOnRefreshAddsRefreshControl() {
    let list = OutlineList<SimpleTextItem>()
    #expect(list.collectionView.refreshControl == nil)

    list.onRefresh = { }
    #expect(list.collectionView.refreshControl != nil)
  }
}
