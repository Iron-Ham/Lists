import SwiftUI
import UIKit

// MARK: - GroupedListView

/// A SwiftUI wrapper around ``GroupedList`` for displaying sectioned lists with headers and footers.
///
/// Supports selection, swipe actions, context menus, and pull-to-refresh. Also provides
/// an inline content initializer that accepts a `@ViewBuilder`.
@MainActor
public struct GroupedListView<SectionID: Hashable & Sendable, Item: CellViewModel>: UIViewRepresentable {

  // MARK: Lifecycle

  public init(
    sections: [SectionModel<SectionID, Item>],
    appearance: UICollectionLayoutListConfiguration.Appearance = .insetGrouped,
    showsSeparators: Bool = true,
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .supplementary,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .supplementary,
    separatorColor: UIColor? = nil,
    backgroundColor: UIColor? = nil,
    headerTopPadding: CGFloat? = nil,
    allowsMultipleSelection: Bool = false,
    allowsSelectionDuringEditing: Bool = false,
    allowsMultipleSelectionDuringEditing: Bool = false,
    isEditing: Bool = false,
    onSelect: (@MainActor (Item) -> Void)? = nil,
    onDeselect: (@MainActor (Item) -> Void)? = nil,
    onDelete: (@MainActor (Item) -> Void)? = nil,
    trailingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)? = nil,
    leadingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)? = nil,
    contextMenuProvider: (@MainActor (Item) -> UIContextMenuConfiguration?)? = nil,
    separatorHandler: (@MainActor (Item, UIListSeparatorConfiguration) -> UIListSeparatorConfiguration)? = nil,
    headerContentProvider: (@MainActor (SectionID) -> UIContentConfiguration?)? = nil,
    footerContentProvider: (@MainActor (SectionID) -> UIContentConfiguration?)? = nil,
    onRefresh: (@MainActor () async -> Void)? = nil
  ) {
    self.sections = sections
    self.appearance = appearance
    self.showsSeparators = showsSeparators
    self.headerMode = headerMode
    self.footerMode = footerMode
    self.separatorColor = separatorColor
    self.backgroundColor = backgroundColor
    self.headerTopPadding = headerTopPadding
    self.allowsMultipleSelection = allowsMultipleSelection
    self.allowsSelectionDuringEditing = allowsSelectionDuringEditing
    self.allowsMultipleSelectionDuringEditing = allowsMultipleSelectionDuringEditing
    self.isEditing = isEditing
    self.onSelect = onSelect
    self.onDeselect = onDeselect
    self.onDelete = onDelete
    self.trailingSwipeActionsProvider = trailingSwipeActionsProvider
    self.leadingSwipeActionsProvider = leadingSwipeActionsProvider
    self.contextMenuProvider = contextMenuProvider
    self.separatorHandler = separatorHandler
    self.headerContentProvider = headerContentProvider
    self.footerContentProvider = footerContentProvider
    self.onRefresh = onRefresh
  }

  // MARK: Public

  @MainActor
  public final class Coordinator {

    // MARK: Lifecycle

    deinit {
      updateTask?.cancel()
      refreshTask?.cancel()
    }

    // MARK: Internal

    var list: GroupedList<SectionID, Item>?
    var previousSections: [SectionModel<SectionID, Item>]?
    var updateTask: Task<Void, Never>?
    var onRefresh: (@MainActor () async -> Void)?

    // Layout-immutable properties captured at creation time for debug validation.
    var initialAppearance: UICollectionLayoutListConfiguration.Appearance?
    var initialShowsSeparators: Bool?
    var initialHeaderMode: UICollectionLayoutListConfiguration.HeaderMode?
    var initialFooterMode: UICollectionLayoutListConfiguration.FooterMode?
    var initialSeparatorColor: UIColor??
    var initialBackgroundColor: UIColor??
    var initialHeaderTopPadding: CGFloat??

    @objc
    func handleRefresh(_ sender: UIRefreshControl) {
      guard refreshTask == nil else { return }
      refreshTask = Task { @MainActor in
        await onRefresh?()
        sender.endRefreshing()
        refreshTask = nil
      }
    }

    // MARK: Private

    private var refreshTask: Task<Void, Never>?

  }

  /// The sections to display, including their items, headers, and footers.
  public let sections: [SectionModel<SectionID, Item>]
  /// The visual appearance of the list.
  ///
  /// - Important: Applied only when the view is first created. Subsequent SwiftUI state
  ///   changes to this value will not update the existing collection view layout.
  public let appearance: UICollectionLayoutListConfiguration.Appearance
  /// Whether separators are shown between rows.
  ///
  /// - Important: Applied only when the view is first created. Subsequent SwiftUI state
  ///   changes to this value will not update the existing collection view layout.
  public let showsSeparators: Bool
  /// How section headers are displayed.
  ///
  /// - Important: Applied only when the view is first created. Subsequent SwiftUI state
  ///   changes to this value will not update the existing collection view layout.
  public let headerMode: UICollectionLayoutListConfiguration.HeaderMode
  /// How section footers are displayed.
  ///
  /// - Important: Applied only when the view is first created. Subsequent SwiftUI state
  ///   changes to this value will not update the existing collection view layout.
  public let footerMode: UICollectionLayoutListConfiguration.FooterMode
  /// A global tint color applied to all item separators.
  ///
  /// - Important: Applied only when the view is first created. Subsequent SwiftUI state
  ///   changes to this value will not update the existing collection view layout.
  public let separatorColor: UIColor?
  /// An optional background color for the list.
  ///
  /// - Important: Applied only when the view is first created. Subsequent SwiftUI state
  ///   changes to this value will not update the existing collection view layout.
  public let backgroundColor: UIColor?
  /// Extra padding above each section header.
  ///
  /// - Important: Applied only when the view is first created. Subsequent SwiftUI state
  ///   changes to this value will not update the existing collection view layout.
  public let headerTopPadding: CGFloat?
  /// Whether the list allows multiple simultaneous selections.
  public let allowsMultipleSelection: Bool
  /// Whether selection is allowed during editing mode.
  public let allowsSelectionDuringEditing: Bool
  /// Whether multiple selection is allowed during editing mode.
  public let allowsMultipleSelectionDuringEditing: Bool
  /// Whether the list is in editing mode.
  public let isEditing: Bool
  /// Called when the user taps an item.
  public var onSelect: (@MainActor (Item) -> Void)?
  /// Called when the user deselects an item (relevant when `allowsMultipleSelection` is enabled).
  public var onDeselect: (@MainActor (Item) -> Void)?
  /// Called when the user swipe-deletes an item. When set and ``trailingSwipeActionsProvider``
  /// is `nil`, a trailing destructive "Delete" swipe action is provided automatically.
  public var onDelete: (@MainActor (Item) -> Void)?
  /// Closure that returns trailing swipe actions for a given item.
  public var trailingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns leading swipe actions for a given item.
  public var leadingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns a context menu configuration for a given item.
  public var contextMenuProvider: (@MainActor (Item) -> UIContextMenuConfiguration?)?
  /// Per-item separator customization handler.
  public var separatorHandler: (@MainActor (Item, UIListSeparatorConfiguration) -> UIListSeparatorConfiguration)?
  /// Closure that returns a custom content configuration for a section header.
  public var headerContentProvider: (@MainActor (SectionID) -> UIContentConfiguration?)?
  /// Closure that returns a custom content configuration for a section footer.
  public var footerContentProvider: (@MainActor (SectionID) -> UIContentConfiguration?)?
  /// An async closure invoked on pull-to-refresh.
  public var onRefresh: (@MainActor () async -> Void)?

  public static func dismantleUIView(_: UICollectionView, coordinator: Coordinator) {
    coordinator.updateTask?.cancel()
    coordinator.updateTask = nil
    coordinator.list = nil
  }

  public func makeUIView(context: Context) -> UICollectionView {
    let list = GroupedList<SectionID, Item>(
      appearance: appearance,
      showsSeparators: showsSeparators,
      headerMode: headerMode,
      footerMode: footerMode,
      separatorColor: separatorColor,
      backgroundColor: backgroundColor,
      headerTopPadding: headerTopPadding
    )
    list.onSelect = onSelect
    list.onDeselect = onDeselect
    list.onDelete = onDelete
    list.trailingSwipeActionsProvider = trailingSwipeActionsProvider
    list.leadingSwipeActionsProvider = leadingSwipeActionsProvider
    list.contextMenuProvider = contextMenuProvider
    list.separatorHandler = separatorHandler
    list.headerContentProvider = headerContentProvider
    list.footerContentProvider = footerContentProvider
    list.allowsMultipleSelection = allowsMultipleSelection
    list.allowsSelectionDuringEditing = allowsSelectionDuringEditing
    list.allowsMultipleSelectionDuringEditing = allowsMultipleSelectionDuringEditing
    list.isEditing = isEditing
    context.coordinator.list = list
    context.coordinator.previousSections = sections
    context.coordinator.onRefresh = onRefresh
    context.coordinator.initialAppearance = appearance
    context.coordinator.initialShowsSeparators = showsSeparators
    context.coordinator.initialHeaderMode = headerMode
    context.coordinator.initialFooterMode = footerMode
    context.coordinator.initialSeparatorColor = separatorColor
    context.coordinator.initialBackgroundColor = backgroundColor
    context.coordinator.initialHeaderTopPadding = headerTopPadding

    configureRefreshControl(
      on: list.collectionView,
      onRefresh: onRefresh,
      target: context.coordinator,
      action: #selector(Coordinator.handleRefresh(_:))
    )

    context.coordinator.updateTask = Task {
      await list.setSections(sections, animatingDifferences: false)
    }
    return list.collectionView
  }

  public func updateUIView(_ collectionView: UICollectionView, context: Context) {
    guard let list = context.coordinator.list else {
      assertionFailure("Coordinator.list is nil during updateUIView — possible lifecycle issue")
      return
    }
    assertLayoutPropertiesUnchanged(context.coordinator)
    list.onSelect = onSelect
    list.onDeselect = onDeselect
    list.onDelete = onDelete
    list.trailingSwipeActionsProvider = trailingSwipeActionsProvider
    list.leadingSwipeActionsProvider = leadingSwipeActionsProvider
    list.contextMenuProvider = contextMenuProvider
    list.separatorHandler = separatorHandler
    list.headerContentProvider = headerContentProvider
    list.footerContentProvider = footerContentProvider
    list.allowsMultipleSelection = allowsMultipleSelection
    list.allowsSelectionDuringEditing = allowsSelectionDuringEditing
    list.allowsMultipleSelectionDuringEditing = allowsMultipleSelectionDuringEditing
    list.isEditing = isEditing
    context.coordinator.onRefresh = onRefresh

    configureRefreshControl(
      on: collectionView,
      onRefresh: onRefresh,
      target: context.coordinator,
      action: #selector(Coordinator.handleRefresh(_:))
    )

    guard sections != context.coordinator.previousSections else { return }
    context.coordinator.previousSections = sections
    context.coordinator.updateTask?.cancel()
    context.coordinator.updateTask = Task {
      await list.setSections(sections)
    }
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  // MARK: Private

  private func assertLayoutPropertiesUnchanged(_ coordinator: Coordinator) {
    assert(
      coordinator.initialAppearance == appearance
        && coordinator.initialShowsSeparators == showsSeparators
        && coordinator.initialHeaderMode == headerMode
        && coordinator.initialFooterMode == footerMode
        && coordinator.initialSeparatorColor == separatorColor
        && coordinator.initialBackgroundColor == backgroundColor
        && coordinator.initialHeaderTopPadding == headerTopPadding,
      "GroupedListView layout properties (appearance, showsSeparators, headerMode, footerMode, separatorColor, backgroundColor, headerTopPadding) cannot be changed after creation — UICollectionLayoutListConfiguration is immutable once the layout is built"
    )
  }

}

// MARK: - Inline Content Convenience

extension GroupedListView {
  public init<Data: Hashable & Sendable>(
    sections: [SectionModel<SectionID, Data>],
    appearance: UICollectionLayoutListConfiguration.Appearance = .insetGrouped,
    showsSeparators: Bool = true,
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .supplementary,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .supplementary,
    separatorColor: UIColor? = nil,
    backgroundColor: UIColor? = nil,
    headerTopPadding: CGFloat? = nil,
    allowsMultipleSelection: Bool = false,
    allowsSelectionDuringEditing: Bool = false,
    allowsMultipleSelectionDuringEditing: Bool = false,
    isEditing: Bool = false,
    accessories: [ListAccessory] = [],
    onSelect: (@MainActor (Data) -> Void)? = nil,
    onDeselect: (@MainActor (Data) -> Void)? = nil,
    onDelete: (@MainActor (Data) -> Void)? = nil,
    trailingSwipeActionsProvider: (@MainActor (Data) -> UISwipeActionsConfiguration?)? = nil,
    leadingSwipeActionsProvider: (@MainActor (Data) -> UISwipeActionsConfiguration?)? = nil,
    contextMenuProvider: (@MainActor (Data) -> UIContextMenuConfiguration?)? = nil,
    separatorHandler: (@MainActor (Data, UIListSeparatorConfiguration) -> UIListSeparatorConfiguration)? = nil,
    headerContentProvider: (@MainActor (SectionID) -> UIContentConfiguration?)? = nil,
    footerContentProvider: (@MainActor (SectionID) -> UIContentConfiguration?)? = nil,
    onRefresh: (@MainActor () async -> Void)? = nil,
    @ViewBuilder content: @escaping @MainActor (Data) -> some View
  ) where Item == InlineCellViewModel<Data> {
    let mapped: [SectionModel<SectionID, InlineCellViewModel<Data>>] = sections.map { section in
      SectionModel(
        id: section.id,
        items: section.items.map { InlineCellViewModel(data: $0, accessories: accessories, content: content) },
        header: section.header,
        footer: section.footer
      )
    }
    self.sections = mapped
    self.appearance = appearance
    self.showsSeparators = showsSeparators
    self.headerMode = headerMode
    self.footerMode = footerMode
    self.separatorColor = separatorColor
    self.backgroundColor = backgroundColor
    self.headerTopPadding = headerTopPadding
    self.allowsMultipleSelection = allowsMultipleSelection
    self.allowsSelectionDuringEditing = allowsSelectionDuringEditing
    self.allowsMultipleSelectionDuringEditing = allowsMultipleSelectionDuringEditing
    self.isEditing = isEditing
    self.headerContentProvider = headerContentProvider
    self.footerContentProvider = footerContentProvider
    self.onRefresh = onRefresh

    if let onSelect {
      self.onSelect = { item in onSelect(item.data) }
    }
    if let onDeselect {
      self.onDeselect = { item in onDeselect(item.data) }
    }
    if let onDelete {
      self.onDelete = { item in onDelete(item.data) }
    }
    if let trailingSwipeActionsProvider {
      self.trailingSwipeActionsProvider = { item in trailingSwipeActionsProvider(item.data) }
    }
    if let leadingSwipeActionsProvider {
      self.leadingSwipeActionsProvider = { item in leadingSwipeActionsProvider(item.data) }
    }
    if let contextMenuProvider {
      self.contextMenuProvider = { item in contextMenuProvider(item.data) }
    }
    if let separatorHandler {
      self.separatorHandler = { item, config in separatorHandler(item.data, config) }
    }
  }
}
