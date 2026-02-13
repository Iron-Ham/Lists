import Foundation

struct StagedChangeset<SectionID: Hashable, ItemID: Hashable>: Sendable {
    let sectionDeletes: IndexSet
    let sectionInserts: IndexSet
    let sectionMoves: [(from: Int, to: Int)]
    let itemDeletes: [IndexPath]
    let itemInserts: [IndexPath]
    let itemMoves: [(from: IndexPath, to: IndexPath)]
    let itemReloads: [IndexPath]
    let itemReconfigures: [IndexPath]

    var isEmpty: Bool {
        sectionDeletes.isEmpty
            && sectionInserts.isEmpty
            && sectionMoves.isEmpty
            && itemDeletes.isEmpty
            && itemInserts.isEmpty
            && itemMoves.isEmpty
            && itemReloads.isEmpty
            && itemReconfigures.isEmpty
    }
}
