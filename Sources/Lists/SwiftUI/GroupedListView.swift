import SwiftUI
import UIKit

@MainActor
public struct GroupedListView<SectionID: Hashable & Sendable, Item: CellViewModel>: UIViewRepresentable {
    public let sections: [SectionModel<SectionID, Item>]
    public let appearance: UICollectionLayoutListConfiguration.Appearance
    public var onSelect: (@MainActor (Item) -> Void)?

    public init(
        sections: [SectionModel<SectionID, Item>],
        appearance: UICollectionLayoutListConfiguration.Appearance = .insetGrouped,
        onSelect: (@MainActor (Item) -> Void)? = nil
    ) {
        self.sections = sections
        self.appearance = appearance
        self.onSelect = onSelect
    }

    public func makeUIView(context: Context) -> UICollectionView {
        let list = GroupedList<SectionID, Item>(appearance: appearance)
        list.onSelect = onSelect
        context.coordinator.list = list
        context.coordinator.previousSections = sections
        Task {
            await list.setSections(sections, animatingDifferences: false)
        }
        return list.collectionView
    }

    public func updateUIView(_: UICollectionView, context: Context) {
        guard let list = context.coordinator.list else { return }
        list.onSelect = onSelect
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

    @MainActor
    public final class Coordinator {
        var list: GroupedList<SectionID, Item>?
        var previousSections: [SectionModel<SectionID, Item>]?
        var updateTask: Task<Void, Never>?
    }
}
