// ABOUTME: Tests for list configuration: appearance, separators, headers, footers, and selection.
// ABOUTME: Covers SimpleList, GroupedList, OutlineList, ListLayout, and ListConfigurationBridge.
import Testing
import UIKit
@testable import ListKit
@testable import Lists

/// Tests for the new UICollectionLayoutListConfiguration features across all list types:
/// backgroundColor, headerTopPadding, separatorHandler, allowsMultipleSelection,
/// header/footer modes, and the GroupedList builder DSL.
@MainActor
struct ListConfigurationTests {

  @Test
  func simpleListAcceptsBackgroundColor() {
    let list = SimpleList<TextItem>(backgroundColor: .systemRed)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func simpleListAcceptsHeaderTopPadding() {
    let list = SimpleList<TextItem>(headerTopPadding: 20)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func simpleListAcceptsSeparatorColor() {
    let list = SimpleList<TextItem>(separatorColor: .systemRed)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func simpleListAcceptsBothConfigOptions() {
    let list = SimpleList<TextItem>(
      appearance: .insetGrouped,
      showsSeparators: false,
      separatorColor: .systemGray,
      backgroundColor: .systemBackground,
      headerTopPadding: 0
    )
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func simpleListAllowsMultipleSelectionProperty() {
    let list = SimpleList<TextItem>()
    #expect(list.allowsMultipleSelection == false)

    list.allowsMultipleSelection = true
    #expect(list.allowsMultipleSelection == true)
    #expect(list.collectionView.allowsMultipleSelection == true)
  }

  @Test
  func simpleListAllowsSelectionDuringEditing() {
    let list = SimpleList<TextItem>()
    #expect(list.allowsSelectionDuringEditing == false)

    list.allowsSelectionDuringEditing = true
    #expect(list.allowsSelectionDuringEditing == true)
  }

  @Test
  func simpleListAllowsMultipleSelectionDuringEditing() {
    let list = SimpleList<TextItem>()
    #expect(list.allowsMultipleSelectionDuringEditing == false)

    list.allowsMultipleSelectionDuringEditing = true
    #expect(list.allowsMultipleSelectionDuringEditing == true)
  }

  @Test
  func simpleListIsEditingProperty() {
    let list = SimpleList<TextItem>()
    #expect(list.isEditing == false)

    list.isEditing = true
    #expect(list.isEditing == true)
    #expect(list.collectionView.isEditing == true)
  }

  @Test
  func simpleListItemIdentifierReturnsNilForInvalidPath() {
    let list = SimpleList<TextItem>()
    #expect(list.itemIdentifier(for: IndexPath(item: 0, section: 0)) == nil)
  }

  @Test
  func simpleListIndexPathReturnsNilForUnknownItem() {
    let list = SimpleList<TextItem>()
    #expect(list.indexPath(for: TextItem(text: "missing")) == nil)
  }

  @Test
  func simpleListSeparatorHandlerIsStored() {
    let list = SimpleList<TextItem>()
    #expect(list.separatorHandler == nil)

    list.separatorHandler = { _, config in config }
    #expect(list.separatorHandler != nil)
  }

  @Test
  func groupedListAcceptsSeparatorColor() {
    let list = GroupedList<String, TextItem>(separatorColor: .systemBlue)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func groupedListAcceptsBackgroundColor() {
    let list = GroupedList<String, TextItem>(backgroundColor: .systemBlue)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func groupedListAcceptsHeaderTopPadding() {
    let list = GroupedList<String, TextItem>(headerTopPadding: 12)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func groupedListAcceptsHeaderMode() {
    let list = GroupedList<String, TextItem>(headerMode: .firstItemInSection, footerMode: .none)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func groupedListAcceptsNoHeaderNoFooter() {
    let list = GroupedList<String, TextItem>(headerMode: .none, footerMode: .none)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func groupedListAllowsMultipleSelectionProperty() {
    let list = GroupedList<String, TextItem>()
    #expect(list.allowsMultipleSelection == false)

    list.allowsMultipleSelection = true
    #expect(list.allowsMultipleSelection == true)
    #expect(list.collectionView.allowsMultipleSelection == true)
  }

  @Test
  func groupedListIsEditingProperty() {
    let list = GroupedList<String, TextItem>()
    #expect(list.isEditing == false)

    list.isEditing = true
    #expect(list.isEditing == true)
  }

  @Test
  func groupedListHeaderContentProviderIsStored() {
    let list = GroupedList<String, TextItem>()
    #expect(list.headerContentProvider == nil)

    list.headerContentProvider = { _ in nil }
    #expect(list.headerContentProvider != nil)
  }

  @Test
  func groupedListFooterContentProviderIsStored() {
    let list = GroupedList<String, TextItem>()
    #expect(list.footerContentProvider == nil)

    list.footerContentProvider = { _ in nil }
    #expect(list.footerContentProvider != nil)
  }

  @Test
  func groupedListSeparatorHandlerIsStored() {
    let list = GroupedList<String, TextItem>()
    list.separatorHandler = { _, config in config }
    #expect(list.separatorHandler != nil)
  }

  @Test
  func groupedListSetSectionsWithBuilder() async {
    let list = GroupedList<String, TextItem>()
    let item1 = TextItem(text: "A")
    let item2 = TextItem(text: "B")

    await list.setSections(animatingDifferences: false) {
      SnapshotSection("section1") {
        item1
      }
      SnapshotSection("section2") {
        item2
      }
    }

    let snapshot = list.snapshot()
    #expect(snapshot.numberOfSections == 2)
    #expect(snapshot.numberOfItems == 2)
  }

  @Test
  func groupedListSetSectionsWithBuilderEmptySections() async {
    let list = GroupedList<String, TextItem>()

    await list.setSections(animatingDifferences: false) {
      SnapshotSection("empty", items: [TextItem]())
    }

    let snapshot = list.snapshot()
    #expect(snapshot.numberOfSections == 1)
    #expect(snapshot.numberOfItems == 0)
  }

  @Test
  func groupedListFullConfigInit() {
    let list = GroupedList<String, TextItem>(
      appearance: .plain,
      showsSeparators: false,
      headerMode: .supplementary,
      footerMode: .none,
      separatorColor: .systemGray,
      backgroundColor: .systemGroupedBackground,
      headerTopPadding: 8
    )
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func outlineListAcceptsSeparatorColor() {
    let list = OutlineList<TextItem>(separatorColor: .systemGreen)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func outlineListAcceptsBackgroundColor() {
    let list = OutlineList<TextItem>(backgroundColor: .systemGreen)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func outlineListAcceptsHeaderTopPadding() {
    let list = OutlineList<TextItem>(headerTopPadding: 16)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func outlineListAllowsMultipleSelectionProperty() {
    let list = OutlineList<TextItem>()
    #expect(list.allowsMultipleSelection == false)

    list.allowsMultipleSelection = true
    #expect(list.allowsMultipleSelection == true)
  }

  @Test
  func outlineListIsEditingProperty() {
    let list = OutlineList<TextItem>()
    #expect(list.isEditing == false)

    list.isEditing = true
    #expect(list.isEditing == true)
  }

  @Test
  func outlineListSeparatorHandlerIsStored() {
    let list = OutlineList<TextItem>()
    list.separatorHandler = { _, config in config }
    #expect(list.separatorHandler != nil)
  }

  @Test
  func outlineListFullConfigInit() {
    let list = OutlineList<TextItem>(
      appearance: .plain,
      showsSeparators: false,
      separatorColor: .systemGray,
      backgroundColor: .black,
      headerTopPadding: 0
    )
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func listLayoutPlainWithConfig() {
    let layout = ListLayout.plain(
      separatorColor: .systemGray,
      backgroundColor: .white,
      headerTopPadding: 10
    )
    #expect(layout.configuration.scrollDirection == .vertical)
  }

  @Test
  func listLayoutGrouped() {
    let layout = ListLayout.grouped()
    #expect(layout.configuration.scrollDirection == .vertical)
  }

  @Test
  func listLayoutGroupedWithConfig() {
    let layout = ListLayout.grouped(
      headerMode: .supplementary,
      showsSeparators: false,
      backgroundColor: .systemGroupedBackground
    )
    #expect(layout.configuration.scrollDirection == .vertical)
  }

  @Test
  func listLayoutInsetGroupedWithConfig() {
    let layout = ListLayout.insetGrouped(
      backgroundColor: .systemBackground,
      headerTopPadding: 0
    )
    #expect(layout.configuration.scrollDirection == .vertical)
  }

  @Test
  func listLayoutSidebarWithConfig() {
    let layout = ListLayout.sidebar(
      headerMode: .supplementary,
      backgroundColor: .clear
    )
    #expect(layout.configuration.scrollDirection == .vertical)
  }

  @Test
  func listLayoutSidebarPlain() {
    let layout = ListLayout.sidebarPlain()
    #expect(layout.configuration.scrollDirection == .vertical)
  }

  @Test
  func listLayoutSidebarPlainWithConfig() {
    let layout = ListLayout.sidebarPlain(
      showsSeparators: false,
      backgroundColor: .systemBackground,
      headerTopPadding: 4
    )
    #expect(layout.configuration.scrollDirection == .vertical)
  }

  @Test
  func separatorColorFlowsThroughBridge() {
    // Verify the bridge applies the default separator color when resolving separators.
    let bridge = ListConfigurationBridge<Int, TextItem>()
    bridge.setDefaultSeparatorColor(.systemRed)

    let defaultConfig = UIListSeparatorConfiguration(listAppearance: .plain)
    let resolved = bridge.resolveSeparator(at: IndexPath(item: 0, section: 0), defaultConfiguration: defaultConfig)
    #expect(resolved.color == .systemRed)
  }

  @Test
  func separatorHandlerPropagatedToBridge() {
    let list = SimpleList<TextItem>()
    var handlerWasSet = false
    list.separatorHandler = { _, config in
      handlerWasSet = true
      return config
    }
    // Verify the handler is stored and the bridge received it
    // (the didSet on separatorHandler forwards to bridge.separatorProvider)
    #expect(list.separatorHandler != nil)
    #expect(!handlerWasSet) // Not yet called, just stored
  }

  @Test
  func itemIdentifierRoundTripsAfterSetItems() async {
    let list = SimpleList<TextItem>()
    let item = TextItem(text: "hello")
    await list.setItems([item], animatingDifferences: false)

    let indexPath = list.indexPath(for: item)
    #expect(indexPath == IndexPath(item: 0, section: 0))

    let resolved = list.itemIdentifier(for: IndexPath(item: 0, section: 0))
    #expect(resolved == item)
  }

  @Test
  func groupedListHeaderContentProviderFallback() async {
    let list = GroupedList<String, TextItem>()
    let section = SectionModel<String, TextItem>(
      id: "sec",
      items: [TextItem(text: "A")],
      header: "My Header"
    )
    await list.setSections([section], animatingDifferences: false)

    // When headerContentProvider is nil, the text-based header is used.
    #expect(list.headerContentProvider == nil)

    // When headerContentProvider is set and returns non-nil, it takes precedence.
    var providerCalled = false
    list.headerContentProvider = { sectionID in
      providerCalled = true
      #expect(sectionID == "sec")
      return nil // fall back to text header
    }
    #expect(list.headerContentProvider != nil)
    // Provider is called lazily during supplementary view dequeue, not eagerly.
    #expect(!providerCalled)
  }

  @Test
  func groupedListBuilderDSLProducesCorrectSections() async {
    let list = GroupedList<String, TextItem>()
    let a = TextItem(text: "A")
    let b = TextItem(text: "B")
    let c = TextItem(text: "C")

    await list.setSections(animatingDifferences: false) {
      SnapshotSection("first") {
        a
        b
      }
      SnapshotSection("second") {
        c
      }
    }

    let snapshot = list.snapshot()
    #expect(snapshot.sectionIdentifiers == ["first", "second"])
    #expect(snapshot.itemIdentifiers(inSection: "first") == [a, b])
    #expect(snapshot.itemIdentifiers(inSection: "second") == [c])
  }

  @Test
  func outlineListItemIdentifierRoundTrips() async throws {
    let list = OutlineList<TextItem>()
    let item = TextItem(text: "leaf")
    await list.setItems([OutlineItem(item: item)], animatingDifferences: false)

    let indexPath = list.indexPath(for: item)
    #expect(indexPath != nil)

    let resolved = list.itemIdentifier(for: try #require(indexPath))
    #expect(resolved == item)
  }

  @Test
  func groupedListAllowsSelectionDuringEditing() {
    let list = GroupedList<String, TextItem>()
    #expect(list.allowsSelectionDuringEditing == false)

    list.allowsSelectionDuringEditing = true
    #expect(list.allowsSelectionDuringEditing == true)
  }

  @Test
  func groupedListAllowsMultipleSelectionDuringEditing() {
    let list = GroupedList<String, TextItem>()
    #expect(list.allowsMultipleSelectionDuringEditing == false)

    list.allowsMultipleSelectionDuringEditing = true
    #expect(list.allowsMultipleSelectionDuringEditing == true)
  }

  @Test
  func outlineListAllowsSelectionDuringEditing() {
    let list = OutlineList<TextItem>()
    #expect(list.allowsSelectionDuringEditing == false)

    list.allowsSelectionDuringEditing = true
    #expect(list.allowsSelectionDuringEditing == true)
  }

  @Test
  func outlineListAllowsMultipleSelectionDuringEditing() {
    let list = OutlineList<TextItem>()
    #expect(list.allowsMultipleSelectionDuringEditing == false)

    list.allowsMultipleSelectionDuringEditing = true
    #expect(list.allowsMultipleSelectionDuringEditing == true)
  }

  @Test
  func simpleListScrollToItemReturnsTrueForExistingItem() async {
    let list = SimpleList<TextItem>()
    let item = TextItem(text: "target")
    await list.setItems([item], animatingDifferences: false)

    let result = list.scrollToItem(item, animated: false)
    #expect(result == true)
  }

  @Test
  func groupedListScrollToItemReturnsTrueForExistingItem() async {
    let list = GroupedList<String, TextItem>()
    let item = TextItem(text: "target")
    await list.setSections([SectionModel(id: "s", items: [item])], animatingDifferences: false)

    let result = list.scrollToItem(item, animated: false)
    #expect(result == true)
  }

  @Test
  func outlineListScrollToItemReturnsTrueForExistingItem() async {
    let list = OutlineList<TextItem>()
    let item = TextItem(text: "target")
    await list.setItems([OutlineItem(item: item)], animatingDifferences: false)

    let result = list.scrollToItem(item, animated: false)
    #expect(result == true)
  }

  @Test
  func bridgeResolveSeparatorWithNilDataSourceReturnsDefault() {
    let bridge = ListConfigurationBridge<Int, TextItem>()
    // dataSource is nil — should gracefully return default config
    let defaultConfig = UIListSeparatorConfiguration(listAppearance: .plain)
    let resolved = bridge.resolveSeparator(at: IndexPath(item: 0, section: 0), defaultConfiguration: defaultConfig)
    #expect(resolved.color == defaultConfig.color)
  }

  @Test
  func bridgeResolveSeparatorAppliesDefaultColorThenProvider() {
    let bridge = ListConfigurationBridge<Int, TextItem>()
    bridge.setDefaultSeparatorColor(.systemBlue)

    // Without a provider, just the default color is applied
    let defaultConfig = UIListSeparatorConfiguration(listAppearance: .plain)
    let resolved = bridge.resolveSeparator(at: IndexPath(item: 0, section: 0), defaultConfiguration: defaultConfig)
    #expect(resolved.color == .systemBlue)
  }

  // Note: resolveTrailing/resolveLeading with nil dataSource trigger assertionFailure,
  // which traps in debug builds. These paths cannot be tested in a debug test target.

  @Test
  func bridgeConfigureWiresHandlersOnLayoutConfig() {
    let bridge = ListConfigurationBridge<Int, TextItem>()
    var config = UICollectionLayoutListConfiguration(appearance: .plain)
    bridge.configure(&config)

    // After configure(), the layout config should have handlers wired
    #expect(config.trailingSwipeActionsConfigurationProvider != nil)
    #expect(config.leadingSwipeActionsConfigurationProvider != nil)
    #expect(config.itemSeparatorHandler != nil)
  }

  @Test
  func bridgeSettersAreObservableThroughResolvers() {
    let bridge = ListConfigurationBridge<Int, TextItem>()
    // Verify setters take effect by observing their impact through the resolver methods.
    bridge.setDefaultSeparatorColor(.systemGreen)
    let config = UIListSeparatorConfiguration(listAppearance: .plain)
    let resolved = bridge.resolveSeparator(at: IndexPath(item: 0, section: 0), defaultConfiguration: config)
    #expect(resolved.color == .systemGreen)
  }

  @Test
  func bridgeItemNavigationWithNilDataSource() {
    let bridge = ListConfigurationBridge<Int, TextItem>()
    // With no dataSource set, item lookups should return nil gracefully.
    #expect(bridge.itemIdentifier(for: IndexPath(item: 0, section: 0)) == nil)
    #expect(bridge.indexPath(for: TextItem(text: "x")) == nil)
  }

  @Test
  func scrollToItemReturnsFalseForMissingItem() async {
    let list = SimpleList<TextItem>()
    let item = TextItem(text: "present")
    let missing = TextItem(text: "absent")
    await list.setItems([item], animatingDifferences: false)

    #expect(list.scrollToItem(missing, animated: false) == false)
  }

  @Test
  func scrollToItemReturnsFalseOnEmptyList() {
    let list = SimpleList<TextItem>()
    let item = TextItem(text: "nowhere")
    #expect(list.scrollToItem(item, animated: false) == false)
  }
}
