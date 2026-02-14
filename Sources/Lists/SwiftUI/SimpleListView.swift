import SwiftUI
import UIKit

@MainActor
public struct SimpleListView<Item: CellViewModel>: UIViewRepresentable {
    public let items: [Item]
    public let appearance: UICollectionLayoutListConfiguration.Appearance
    public var onSelect: (@MainActor (Item) -> Void)?
    public var trailingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
    public var leadingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
    public var contextMenuProvider: (@MainActor (Item) -> UIContextMenuConfiguration?)?
    public var onRefresh: (@MainActor () async -> Void)?

    public init(
        items: [Item],
        appearance: UICollectionLayoutListConfiguration.Appearance = .plain,
        onSelect: (@MainActor (Item) -> Void)? = nil,
        trailingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)? = nil,
        leadingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)? = nil,
        contextMenuProvider: (@MainActor (Item) -> UIContextMenuConfiguration?)? = nil,
        onRefresh: (@MainActor () async -> Void)? = nil
    ) {
        self.items = items
        self.appearance = appearance
        self.onSelect = onSelect
        self.trailingSwipeActionsProvider = trailingSwipeActionsProvider
        self.leadingSwipeActionsProvider = leadingSwipeActionsProvider
        self.contextMenuProvider = contextMenuProvider
        self.onRefresh = onRefresh
    }

    public func makeUIView(context: Context) -> UICollectionView {
        let list = SimpleList<Item>(appearance: appearance)
        list.onSelect = onSelect
        list.trailingSwipeActionsProvider = trailingSwipeActionsProvider
        list.leadingSwipeActionsProvider = leadingSwipeActionsProvider
        list.contextMenuProvider = contextMenuProvider
        context.coordinator.list = list
        context.coordinator.previousItems = items
        context.coordinator.onRefresh = onRefresh

        configureRefreshControl(
            on: list.collectionView,
            onRefresh: onRefresh,
            target: context.coordinator,
            action: #selector(Coordinator.handleRefresh(_:))
        )

        context.coordinator.updateTask = Task {
            await list.setItems(items, animatingDifferences: false)
        }
        return list.collectionView
    }

    public func updateUIView(_ collectionView: UICollectionView, context: Context) {
        guard let list = context.coordinator.list else { return }
        list.onSelect = onSelect
        list.trailingSwipeActionsProvider = trailingSwipeActionsProvider
        list.leadingSwipeActionsProvider = leadingSwipeActionsProvider
        list.contextMenuProvider = contextMenuProvider
        context.coordinator.onRefresh = onRefresh

        configureRefreshControl(
            on: collectionView,
            onRefresh: onRefresh,
            target: context.coordinator,
            action: #selector(Coordinator.handleRefresh(_:))
        )

        guard items != context.coordinator.previousItems else { return }
        context.coordinator.previousItems = items
        context.coordinator.updateTask?.cancel()
        context.coordinator.updateTask = Task {
            await list.setItems(items)
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    public final class Coordinator {
        var list: SimpleList<Item>?
        var previousItems: [Item]?
        var updateTask: Task<Void, Never>?
        var onRefresh: (@MainActor () async -> Void)?
        private var refreshTask: Task<Void, Never>?

        deinit {
            updateTask?.cancel()
            refreshTask?.cancel()
        }

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            guard refreshTask == nil else { return }
            refreshTask = Task { @MainActor in
                await onRefresh?()
                sender.endRefreshing()
                refreshTask = nil
            }
        }
    }
}

// MARK: - Inline Content Convenience

public extension SimpleListView {
    init<Data: Hashable & Sendable>(
        items: [Data],
        appearance: UICollectionLayoutListConfiguration.Appearance = .plain,
        accessories: [ListAccessory] = [],
        onSelect: (@MainActor (Data) -> Void)? = nil,
        trailingSwipeActionsProvider: (@MainActor (Data) -> UISwipeActionsConfiguration?)? = nil,
        leadingSwipeActionsProvider: (@MainActor (Data) -> UISwipeActionsConfiguration?)? = nil,
        contextMenuProvider: (@MainActor (Data) -> UIContextMenuConfiguration?)? = nil,
        onRefresh: (@MainActor () async -> Void)? = nil,
        @ViewBuilder content: @escaping @MainActor (Data) -> some View
    ) where Item == InlineCellViewModel<Data> {
        let mapped = items.map { InlineCellViewModel(data: $0, accessories: accessories, content: content) }

        self.items = mapped
        self.appearance = appearance
        self.onRefresh = onRefresh

        if let onSelect {
            self.onSelect = { item in onSelect(item.data) }
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
    }
}
