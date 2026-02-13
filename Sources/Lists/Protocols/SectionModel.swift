public struct SectionModel<SectionID: Hashable & Sendable, Item: CellViewModel>: Sendable {
    public let id: SectionID
    public let items: [Item]
    public let header: String?
    public let footer: String?

    public init(id: SectionID, items: [Item], header: String? = nil, footer: String? = nil) {
        self.id = id
        self.items = items
        self.header = header
        self.footer = footer
    }
}
