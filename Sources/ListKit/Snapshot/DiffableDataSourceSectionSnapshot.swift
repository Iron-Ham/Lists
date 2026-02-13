public struct DiffableDataSourceSectionSnapshot<ItemIdentifierType: Hashable & Sendable>: Sendable {
    // MARK: - Internal Storage

    public private(set) var items: [ItemIdentifierType] = []
    private var parentMap: [ItemIdentifierType: ItemIdentifierType] = [:]
    private var childrenMap: [ItemIdentifierType: [ItemIdentifierType]] = [:]
    private var expandedItems: Set<ItemIdentifierType> = []

    // MARK: - Initialization

    public init() {}

    // MARK: - Mutations

    public mutating func append(_ items: [ItemIdentifierType], to parent: ItemIdentifierType? = nil) {
        if let parent {
            // Append as children of parent
            var children = childrenMap[parent] ?? []
            children.append(contentsOf: items)
            childrenMap[parent] = children

            for item in items {
                parentMap[item] = parent
            }

            // Insert in flat list after parent and its existing children
            guard let parentIndex = self.items.firstIndex(of: parent) else { return }

            // Find the last descendant of parent
            var insertIndex = parentIndex + 1
            while insertIndex < self.items.count {
                if isDescendant(self.items[insertIndex], of: parent) {
                    insertIndex += 1
                } else {
                    break
                }
            }

            self.items.insert(contentsOf: items, at: insertIndex)
        } else {
            // Append as root items
            self.items.append(contentsOf: items)
        }
    }

    public mutating func insert(_ items: [ItemIdentifierType], before item: ItemIdentifierType) {
        guard let index = self.items.firstIndex(of: item) else { return }

        self.items.insert(contentsOf: items, at: index)

        // Update parent/children maps if the reference item has a parent
        if let parent = parentMap[item] {
            for newItem in items {
                parentMap[newItem] = parent
            }

            if var siblings = childrenMap[parent], let siblingIndex = siblings.firstIndex(of: item) {
                siblings.insert(contentsOf: items, at: siblingIndex)
                childrenMap[parent] = siblings
            }
        }
    }

    public mutating func insert(_ items: [ItemIdentifierType], after item: ItemIdentifierType) {
        guard let index = self.items.firstIndex(of: item) else { return }

        // Find the end of this item's descendants
        var insertIndex = index + 1
        while insertIndex < self.items.count {
            if isDescendant(self.items[insertIndex], of: item) {
                insertIndex += 1
            } else {
                break
            }
        }

        self.items.insert(contentsOf: items, at: insertIndex)

        // Update parent/children maps if the reference item has a parent
        if let parent = parentMap[item] {
            for newItem in items {
                parentMap[newItem] = parent
            }

            if var siblings = childrenMap[parent], let siblingIndex = siblings.firstIndex(of: item) {
                siblings.insert(contentsOf: items, at: siblingIndex + 1)
                childrenMap[parent] = siblings
            }
        }
    }

    public mutating func delete(_ items: [ItemIdentifierType]) {
        for item in items {
            deleteRecursive(item)
        }
    }

    // MARK: - Queries

    public func parent(of item: ItemIdentifierType) -> ItemIdentifierType? {
        parentMap[item]
    }

    public func snapshot(of item: ItemIdentifierType, includingParent: Bool = false) -> DiffableDataSourceSectionSnapshot {
        var newSnapshot = DiffableDataSourceSectionSnapshot()

        if includingParent {
            newSnapshot.items.append(item)
        }

        // Add all descendants
        addDescendants(of: item, to: &newSnapshot)

        // Copy relevant maps
        for snapshotItem in newSnapshot.items {
            if let parent = parentMap[snapshotItem] {
                newSnapshot.parentMap[snapshotItem] = parent
            }
            if let children = childrenMap[snapshotItem] {
                newSnapshot.childrenMap[snapshotItem] = children
            }
            if expandedItems.contains(snapshotItem) {
                newSnapshot.expandedItems.insert(snapshotItem)
            }
        }

        return newSnapshot
    }

    public func contains(_ item: ItemIdentifierType) -> Bool {
        items.contains(item)
    }

    public func level(of item: ItemIdentifierType) -> Int {
        var level = 0
        var current = item
        while let parent = parentMap[current] {
            level += 1
            current = parent
        }
        return level
    }

    public func isVisible(_ item: ItemIdentifierType) -> Bool {
        var current = item
        while let parent = parentMap[current] {
            if !expandedItems.contains(parent) {
                return false
            }
            current = parent
        }
        return true
    }

    public func isExpanded(_ item: ItemIdentifierType) -> Bool {
        expandedItems.contains(item)
    }

    // MARK: - Expand/Collapse

    public mutating func expand(_ items: [ItemIdentifierType]) {
        expandedItems.formUnion(items)
    }

    public mutating func collapse(_ items: [ItemIdentifierType]) {
        expandedItems.subtract(items)
    }

    // MARK: - Computed Properties

    public var rootItems: [ItemIdentifierType] {
        items.filter { parentMap[$0] == nil }
    }

    public var visibleItems: [ItemIdentifierType] {
        items.filter { isVisible($0) }
    }

    // MARK: - Private Helpers

    private mutating func deleteRecursive(_ item: ItemIdentifierType) {
        // Delete all children first
        if let children = childrenMap[item] {
            for child in children {
                deleteRecursive(child)
            }
        }

        // Remove from parent's children list
        if let parent = parentMap[item] {
            childrenMap[parent]?.removeAll { $0 == item }
        }

        // Clean up maps
        parentMap.removeValue(forKey: item)
        childrenMap.removeValue(forKey: item)
        expandedItems.remove(item)

        // Remove from flat list
        items.removeAll { $0 == item }
    }

    private func isDescendant(_ item: ItemIdentifierType, of ancestor: ItemIdentifierType) -> Bool {
        var current = item
        while let parent = parentMap[current] {
            if parent == ancestor {
                return true
            }
            current = parent
        }
        return false
    }

    private func addDescendants(of item: ItemIdentifierType, to snapshot: inout DiffableDataSourceSectionSnapshot) {
        guard let children = childrenMap[item] else { return }

        for child in children {
            snapshot.items.append(child)
            addDescendants(of: child, to: &snapshot)
        }
    }
}
