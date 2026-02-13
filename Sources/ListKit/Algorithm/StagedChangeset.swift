import Foundation

struct StagedChangeset<SectionID: Hashable, ItemID: Hashable>: Sendable {
    let sectionDeletes: IndexSet
    let sectionInserts: IndexSet
    let sectionMoves: [(from: Int, to: Int)]
    let sectionReloads: IndexSet
    let itemDeletes: [IndexPath]
    let itemInserts: [IndexPath]
    let itemMoves: [(from: IndexPath, to: IndexPath)]
    let itemReloads: [IndexPath]
    let itemReconfigures: [IndexPath]

    var isEmpty: Bool {
        sectionDeletes.isEmpty
            && sectionInserts.isEmpty
            && sectionMoves.isEmpty
            && sectionReloads.isEmpty
            && itemDeletes.isEmpty
            && itemInserts.isEmpty
            && itemMoves.isEmpty
            && itemReloads.isEmpty
            && itemReconfigures.isEmpty
    }

    var hasStructuralChanges: Bool {
        !sectionDeletes.isEmpty
            || !sectionInserts.isEmpty
            || !sectionMoves.isEmpty
            || !itemDeletes.isEmpty
            || !itemInserts.isEmpty
            || !itemMoves.isEmpty
    }
}

extension StagedChangeset: Equatable {
    static func == (lhs: StagedChangeset, rhs: StagedChangeset) -> Bool {
        lhs.sectionDeletes == rhs.sectionDeletes
            && lhs.sectionInserts == rhs.sectionInserts
            && lhs.sectionMoves.count == rhs.sectionMoves.count
            && zip(lhs.sectionMoves, rhs.sectionMoves).allSatisfy { $0.from == $1.from && $0.to == $1.to }
            && lhs.sectionReloads == rhs.sectionReloads
            && lhs.itemDeletes == rhs.itemDeletes
            && lhs.itemInserts == rhs.itemInserts
            && lhs.itemMoves.count == rhs.itemMoves.count
            && zip(lhs.itemMoves, rhs.itemMoves).allSatisfy { $0.from == $1.from && $0.to == $1.to }
            && lhs.itemReloads == rhs.itemReloads
            && lhs.itemReconfigures == rhs.itemReconfigures
    }
}
