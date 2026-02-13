import Foundation

enum SectionedDiff {
    /// Computes a `StagedChangeset` by diffing two snapshots at both the section and item level.
    static func diff<SectionID: Hashable & Sendable, ItemID: Hashable & Sendable>(
        old: DiffableDataSourceSnapshot<SectionID, ItemID>,
        new: DiffableDataSourceSnapshot<SectionID, ItemID>
    ) -> StagedChangeset<SectionID, ItemID> {
        // 1. Diff sections
        let sectionDiff = HeckelDiff.diff(old: old.sectionIdentifiers, new: new.sectionIdentifiers)

        let sectionDeletes = IndexSet(sectionDiff.deletes)
        let sectionInserts = IndexSet(sectionDiff.inserts)
        let sectionMoves = sectionDiff.moves

        // Build sets for quick lookup of surviving sections
        let deletedSectionSet = Set(sectionDiff.deletes.map { old.sectionIdentifiers[$0] })
        let insertedSectionSet = Set(sectionDiff.inserts.map { new.sectionIdentifiers[$0] })

        // 2. Build old item location map: ItemID → IndexPath (in old snapshot)
        var oldItemLocations: [ItemID: IndexPath] = [:]
        for (sectionIdx, sectionID) in old.sectionIdentifiers.enumerated() {
            for (itemIdx, itemID) in old.itemIdentifiers(inSection: sectionID).enumerated() {
                oldItemLocations[itemID] = IndexPath(item: itemIdx, section: sectionIdx)
            }
        }

        // 3. Build new item location map: ItemID → IndexPath (in new snapshot)
        var newItemLocations: [ItemID: IndexPath] = [:]
        for (sectionIdx, sectionID) in new.sectionIdentifiers.enumerated() {
            for (itemIdx, itemID) in new.itemIdentifiers(inSection: sectionID).enumerated() {
                newItemLocations[itemID] = IndexPath(item: itemIdx, section: sectionIdx)
            }
        }

        // 4. Compute item-level changes for surviving sections
        var itemDeletes: [IndexPath] = []
        var itemInserts: [IndexPath] = []
        var itemMoves: [(from: IndexPath, to: IndexPath)] = []

        // Track all items that exist in both old and new (for move detection)
        let oldItemSet = Set(oldItemLocations.keys)
        let newItemSet = Set(newItemLocations.keys)

        // Items deleted: existed in old but not in new, AND their section wasn't deleted
        // (If the section was deleted, the section delete handles removal)
        for itemID in oldItemSet.subtracting(newItemSet) {
            guard let oldPath = oldItemLocations[itemID] else { continue }
            let sectionID = old.sectionIdentifiers[oldPath.section]
            if !deletedSectionSet.contains(sectionID) {
                itemDeletes.append(oldPath)
            }
        }

        // Items inserted: exist in new but not in old, AND their section wasn't inserted
        // (If the section was inserted, the section insert handles addition)
        for itemID in newItemSet.subtracting(oldItemSet) {
            guard let newPath = newItemLocations[itemID] else { continue }
            let sectionID = new.sectionIdentifiers[newPath.section]
            if !insertedSectionSet.contains(sectionID) {
                itemInserts.append(newPath)
            }
        }

        // Items that exist in both: check for moves
        // Build old→new section index mapping for matched sections
        var oldSectionToNew: [Int: Int] = [:]
        for match in sectionDiff.matched {
            oldSectionToNew[match.old] = match.new
        }

        for itemID in oldItemSet.intersection(newItemSet) {
            guard let oldPath = oldItemLocations[itemID],
                  let newPath = newItemLocations[itemID] else { continue }

            let oldSectionID = old.sectionIdentifiers[oldPath.section]
            let newSectionID = new.sectionIdentifiers[newPath.section]

            // Skip if either section was deleted or inserted
            if deletedSectionSet.contains(oldSectionID) || insertedSectionSet.contains(newSectionID) {
                continue
            }

            // Check if the item moved (different position in the new layout)
            if oldPath != newPath || oldSectionID != newSectionID {
                // Use old section's new position for comparison
                let mappedOldSection = oldSectionToNew[oldPath.section]
                if mappedOldSection != newPath.section || oldPath.item != newPath.item {
                    itemMoves.append((from: oldPath, to: newPath))
                }
            }
        }

        // 5. Collect reloads and reconfigures from the new snapshot (using new indices)
        var itemReloads: [IndexPath] = []
        for itemID in new.reloadedItemIdentifiers {
            if let newPath = newItemLocations[itemID] {
                itemReloads.append(newPath)
            }
        }

        var itemReconfigures: [IndexPath] = []
        for itemID in new.reconfiguredItemIdentifiers {
            if let newPath = newItemLocations[itemID] {
                itemReconfigures.append(newPath)
            }
        }

        // 6. Sort for deterministic batch update ordering
        let sortedItemDeletes = itemDeletes.sorted { ($0.section, $0.item) > ($1.section, $1.item) }
        let sortedItemInserts = itemInserts.sorted { ($0.section, $0.item) < ($1.section, $1.item) }

        return StagedChangeset(
            sectionDeletes: sectionDeletes,
            sectionInserts: sectionInserts,
            sectionMoves: sectionMoves,
            itemDeletes: sortedItemDeletes,
            itemInserts: sortedItemInserts,
            itemMoves: itemMoves,
            itemReloads: itemReloads,
            itemReconfigures: itemReconfigures
        )
    }
}
