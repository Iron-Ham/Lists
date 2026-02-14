import Foundation

enum SectionedDiff {
  /// Computes a `StagedChangeset` by diffing two snapshots at both the section and item level.
  ///
  /// Uses per-section HeckelDiff for surviving sections, skipping sections whose items
  /// haven't changed. Cross-section item moves are detected by reconciling per-section
  /// deletes and inserts.
  static func diff<SectionID: Hashable & Sendable, ItemID: Hashable & Sendable>(
    old: DiffableDataSourceSnapshot<SectionID, ItemID>,
    new: DiffableDataSourceSnapshot<SectionID, ItemID>
  ) -> StagedChangeset<SectionID, ItemID> {
    // 1. Diff sections
    let sectionDiff = HeckelDiff.diff(old: old.sectionIdentifiers, new: new.sectionIdentifiers)

    let sectionDeletes = IndexSet(sectionDiff.deletes)
    let sectionInserts = IndexSet(sectionDiff.inserts)
    let sectionMoves = sectionDiff.moves

    // 2. Per-section item diffing for matched (surviving) sections.
    //    For each matched pair, compare item arrays — skip if identical.
    //    Otherwise run HeckelDiff per-section and collect operations.
    var itemDeletes = [IndexPath]()
    var itemInserts = [IndexPath]()
    var itemMoves = [(from: IndexPath, to: IndexPath)]()

    // Cross-section moves are only possible when multiple sections exist.
    // Single-section snapshots skip dictionary allocation entirely.
    let crossSectionPossible = old.numberOfSections > 1 || new.numberOfSections > 1

    // Items that HeckelDiff reports as deleted/inserted within surviving sections.
    // An item deleted from section A and inserted into section B = cross-section move.
    var crossDeleteCandidates = [ItemID: IndexPath]()
    var crossInsertCandidates = [ItemID: IndexPath]()

    for match in sectionDiff.matched {
      let oldSectionIdx = match.old
      let newSectionIdx = match.new
      let oldSectionID = old.sectionIdentifiers[oldSectionIdx]
      let newSectionID = new.sectionIdentifiers[newSectionIdx]

      let oldItems = old.itemIdentifiers(inSection: oldSectionID)
      let newItems = new.itemIdentifiers(inSection: newSectionID)

      // Fast path: identical items → no changes in this section
      if oldItems == newItems {
        continue
      }

      let itemDiff = HeckelDiff.diff(old: oldItems, new: newItems)

      // Within-section moves
      for move in itemDiff.moves {
        itemMoves.append((
          from: IndexPath(item: move.from, section: oldSectionIdx),
          to: IndexPath(item: move.to, section: newSectionIdx)
        ))
      }

      if crossSectionPossible {
        // Per-section deletes: real deletes or cross-section move sources
        for deleteIdx in itemDiff.deletes {
          let itemID = oldItems[deleteIdx]
          crossDeleteCandidates[itemID] = IndexPath(item: deleteIdx, section: oldSectionIdx)
        }

        // Per-section inserts: real inserts or cross-section move destinations
        for insertIdx in itemDiff.inserts {
          let itemID = newItems[insertIdx]
          crossInsertCandidates[itemID] = IndexPath(item: insertIdx, section: newSectionIdx)
        }
      } else {
        // Single section — deletes and inserts are final, no cross-section reconciliation needed
        for deleteIdx in itemDiff.deletes {
          itemDeletes.append(IndexPath(item: deleteIdx, section: oldSectionIdx))
        }
        for insertIdx in itemDiff.inserts {
          itemInserts.append(IndexPath(item: insertIdx, section: newSectionIdx))
        }
      }
    }

    // 3. Reconcile cross-section moves between surviving sections.
    //    Items deleted from one section and inserted into another → cross-section move.
    if crossSectionPossible {
      for (itemID, fromPath) in crossDeleteCandidates {
        if let toPath = crossInsertCandidates.removeValue(forKey: itemID) {
          itemMoves.append((from: fromPath, to: toPath))
        } else {
          itemDeletes.append(fromPath)
        }
      }
      // Remaining insert candidates are real inserts
      itemInserts.append(contentsOf: crossInsertCandidates.values)
    }

    // 4. Collect section reloads — only for sections that survive (exist in both old and new).
    //    Uses NEW indices since reloads are applied after the batch update.
    var sectionReloads = IndexSet()
    if !new.reloadedSectionIdentifiers.isEmpty {
      for sectionID in new.reloadedSectionIdentifiers {
        if
          let newIdx = new.index(ofSection: sectionID),
          old.index(ofSection: sectionID) != nil
        {
          sectionReloads.insert(newIdx)
        }
      }
    }

    // 5. Collect item reloads and reconfigures from the new snapshot
    var itemReloads = [IndexPath]()
    var itemReconfigures = [IndexPath]()

    if !new.reloadedItemIdentifiers.isEmpty || !new.reconfiguredItemIdentifiers.isEmpty {
      itemReloads.reserveCapacity(new.reloadedItemIdentifiers.count)
      itemReconfigures.reserveCapacity(new.reconfiguredItemIdentifiers.count)

      for (sectionIdx, sectionID) in new.sectionIdentifiers.enumerated() {
        for (itemIdx, itemID) in new.itemIdentifiers(inSection: sectionID).enumerated() {
          if new.reloadedItemIdentifiers.contains(itemID) {
            itemReloads.append(IndexPath(item: itemIdx, section: sectionIdx))
          }
          if new.reconfiguredItemIdentifiers.contains(itemID) {
            itemReconfigures.append(IndexPath(item: itemIdx, section: sectionIdx))
          }
        }
      }
    }

    // 6. Sort for deterministic batch update ordering
    // Deletes descending (process from end to start), inserts ascending
    let sortedItemDeletes = itemDeletes.sorted { ($0.section, $0.item) > ($1.section, $1.item) }
    let sortedItemInserts = itemInserts.sorted { ($0.section, $0.item) < ($1.section, $1.item) }

    return StagedChangeset(
      sectionDeletes: sectionDeletes,
      sectionInserts: sectionInserts,
      sectionMoves: sectionMoves,
      sectionReloads: sectionReloads,
      itemDeletes: sortedItemDeletes,
      itemInserts: sortedItemInserts,
      itemMoves: itemMoves,
      itemReloads: itemReloads,
      itemReconfigures: itemReconfigures
    )
  }
}
