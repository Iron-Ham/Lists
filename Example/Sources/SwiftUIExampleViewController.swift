import Lists
import SwiftUI
import UIKit

/// SwiftUI interop demo — shows two patterns:
/// 1. CellViewModels rendering SwiftUI views via UIHostingConfiguration
/// 2. UIViewControllerRepresentable / UIViewRepresentable wrappers for embedding Lists in SwiftUI
final class SwiftUIExampleViewController: UIViewController {
    struct ContactItem: CellViewModel, Identifiable {
        typealias Cell = UICollectionViewListCell
        let id: UUID
        let name: String
        let role: String
        let status: Status
        let avatarColor: Color

        enum Status: String, Sendable {
            case online, away, offline
        }

        init(id: UUID = UUID(), name: String, role: String, status: Status, avatarColor: Color) {
            self.id = id
            self.name = name
            self.role = role
            self.status = status
            self.avatarColor = avatarColor
        }

        @MainActor func configure(_ cell: UICollectionViewListCell) {
            cell.contentConfiguration = UIHostingConfiguration {
                ContactRow(name: name, role: role, status: status, avatarColor: avatarColor)
            }
            cell.accessories = [.disclosureIndicator()]
        }
    }

    private var groupedList: GroupedList<String, ContactItem>!
    private var teamMembers: [ContactItem] = []
    private var externalContacts: [ContactItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "SwiftUI"
        view.backgroundColor = .systemBackground

        groupedList = GroupedList<String, ContactItem>(appearance: .insetGrouped)
        groupedList.collectionView.frame = view.bounds
        groupedList.collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(groupedList.collectionView)

        groupedList.onSelect = { contact in
            print("Selected: \(contact.name)")
        }

        setupNavigationBar()
        loadData()
        applySnapshot()
    }

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Shuffle",
            style: .plain,
            target: self,
            action: #selector(shuffleTapped)
        )
    }

    private func loadData() {
        teamMembers = [
            ContactItem(name: "Alice Chen", role: "iOS Engineer", status: .online, avatarColor: .blue),
            ContactItem(name: "Bob Park", role: "Designer", status: .online, avatarColor: .purple),
            ContactItem(name: "Charlie Kim", role: "Backend Engineer", status: .away, avatarColor: .orange),
            ContactItem(name: "Diana Lee", role: "Product Manager", status: .offline, avatarColor: .green),
            ContactItem(name: "Eve Wilson", role: "QA Engineer", status: .online, avatarColor: .red),
        ]

        externalContacts = [
            ContactItem(name: "Frank Torres", role: "Client", status: .offline, avatarColor: .gray),
            ContactItem(name: "Grace Hopper", role: "Advisor", status: .away, avatarColor: .teal),
            ContactItem(name: "Hank Moody", role: "Contractor", status: .online, avatarColor: .indigo),
        ]
    }

    private func applySnapshot() {
        let sections = [
            SectionModel(
                id: "team",
                items: teamMembers,
                header: "Team",
                footer: "\(teamMembers.count(where: { $0.status == .online })) online"
            ),
            SectionModel(
                id: "external",
                items: externalContacts,
                header: "External",
                footer: "\(externalContacts.count) contacts"
            ),
        ]

        Task {
            await groupedList.setSections(sections, animatingDifferences: false)
        }
    }

    @objc private func shuffleTapped() {
        teamMembers.shuffle()
        externalContacts.shuffle()

        let sections = [
            SectionModel(
                id: "team",
                items: teamMembers,
                header: "Team",
                footer: "\(teamMembers.count(where: { $0.status == .online })) online"
            ),
            SectionModel(
                id: "external",
                items: externalContacts,
                header: "External",
                footer: "\(externalContacts.count) contacts"
            ),
        ]

        Task {
            await groupedList.setSections(sections)
        }
    }
}

// MARK: - SwiftUI Cell View

private struct ContactRow: View {
    let name: String
    let role: String
    let status: SwiftUIExampleViewController.ContactItem.Status
    let avatarColor: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(avatarColor.gradient)
                    .frame(width: 40, height: 40)
                Text(String(name.prefix(1)))
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle().stroke(.white, lineWidth: 2)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                Text(role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch status {
        case .online: .green
        case .away: .yellow
        case .offline: .gray
        }
    }
}

// MARK: - SwiftUI Wrappers

/// Wraps the full SwiftUI demo VC for use in a SwiftUI app.
/// Usage: `SwiftUIExampleView()` in a SwiftUI body.
struct SwiftUIExampleView: UIViewControllerRepresentable {
    func makeUIViewController(context _: Context) -> SwiftUIExampleViewController {
        SwiftUIExampleViewController()
    }

    func updateUIViewController(_: SwiftUIExampleViewController, context _: Context) {}
}

/// Generic UIViewRepresentable that wraps a SimpleList's collection view.
/// This shows how to expose any Lists component directly as a SwiftUI View.
///
/// Usage:
/// ```swift
/// struct MyApp: View {
///     @State var items = [MyItem(...), ...]
///
///     var body: some View {
///         SimpleListView(items: items, appearance: .plain) { item in
///             print("Selected: \(item)")
///         }
///     }
/// }
/// ```
@MainActor
struct SimpleListView<Item: CellViewModel>: UIViewRepresentable {
    let items: [Item]
    let appearance: UICollectionLayoutListConfiguration.Appearance
    var onSelect: (@MainActor (Item) -> Void)?

    init(
        items: [Item],
        appearance: UICollectionLayoutListConfiguration.Appearance = .plain,
        onSelect: (@MainActor (Item) -> Void)? = nil
    ) {
        self.items = items
        self.appearance = appearance
        self.onSelect = onSelect
    }

    func makeUIView(context: Context) -> UICollectionView {
        let list = SimpleList<Item>(appearance: appearance)
        list.onSelect = onSelect
        context.coordinator.list = list
        Task {
            await list.setItems(items, animatingDifferences: false)
        }
        return list.collectionView
    }

    func updateUIView(_: UICollectionView, context: Context) {
        guard let list = context.coordinator.list else { return }
        list.onSelect = onSelect
        Task {
            await list.setItems(items)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        var list: SimpleList<Item>?
    }
}

/// Generic UIViewRepresentable that wraps a GroupedList's collection view.
///
/// Usage:
/// ```swift
/// GroupedListView(sections: [
///     SectionModel(id: "header", items: items, header: "Title", footer: "Subtitle")
/// ])
/// ```
@MainActor
struct GroupedListView<SectionID: Hashable & Sendable, Item: CellViewModel>: UIViewRepresentable {
    let sections: [SectionModel<SectionID, Item>]
    let appearance: UICollectionLayoutListConfiguration.Appearance
    var onSelect: (@MainActor (Item) -> Void)?

    init(
        sections: [SectionModel<SectionID, Item>],
        appearance: UICollectionLayoutListConfiguration.Appearance = .insetGrouped,
        onSelect: (@MainActor (Item) -> Void)? = nil
    ) {
        self.sections = sections
        self.appearance = appearance
        self.onSelect = onSelect
    }

    func makeUIView(context: Context) -> UICollectionView {
        let list = GroupedList<SectionID, Item>(appearance: appearance)
        list.onSelect = onSelect
        context.coordinator.list = list
        Task {
            await list.setSections(sections, animatingDifferences: false)
        }
        return list.collectionView
    }

    func updateUIView(_: UICollectionView, context: Context) {
        guard let list = context.coordinator.list else { return }
        list.onSelect = onSelect
        Task {
            await list.setSections(sections)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        var list: GroupedList<SectionID, Item>?
    }
}
