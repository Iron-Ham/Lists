import SwiftUI
import UIKit

@MainActor
public struct OutlineListView<Item: CellViewModel>: UIViewRepresentable {
    public let items: [OutlineItem<Item>]
    public let appearance: UICollectionLayoutListConfiguration.Appearance
    public var onSelect: (@MainActor (Item) -> Void)?

    public init(
        items: [OutlineItem<Item>],
        appearance: UICollectionLayoutListConfiguration.Appearance = .sidebar,
        onSelect: (@MainActor (Item) -> Void)? = nil
    ) {
        self.items = items
        self.appearance = appearance
        self.onSelect = onSelect
    }

    public func makeUIView(context: Context) -> UICollectionView {
        let list = OutlineList<Item>(appearance: appearance)
        list.onSelect = onSelect
        context.coordinator.list = list
        context.coordinator.previousItems = items
        Task {
            await list.setItems(items, animatingDifferences: false)
        }
        return list.collectionView
    }

    public func updateUIView(_: UICollectionView, context: Context) {
        guard let list = context.coordinator.list else { return }
        list.onSelect = onSelect
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
        var list: OutlineList<Item>?
        var previousItems: [OutlineItem<Item>]?
        var updateTask: Task<Void, Never>?
    }
}
