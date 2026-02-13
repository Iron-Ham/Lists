import Lists
import UIKit

/// Manual Lists demo — uses GroupedList with SectionModel, headers, and footers.
final class GroupedListExampleViewController: UIViewController {
    enum SectionID: String, Hashable, Sendable {
        case account
        case preferences
        case notifications
        case about
    }

    struct SettingItem: CellViewModel, Identifiable {
        typealias Cell = UICollectionViewListCell
        let id: String
        let title: String
        let icon: String
        let detail: String?

        init(id: String, title: String, icon: String, detail: String? = nil) {
            self.id = id
            self.title = title
            self.icon = icon
            self.detail = detail
        }

        @MainActor func configure(_ cell: UICollectionViewListCell) {
            var content = cell.defaultContentConfiguration()
            content.text = title
            content.image = UIImage(systemName: icon)
            content.secondaryText = detail
            cell.accessories = [.disclosureIndicator()]
            cell.contentConfiguration = content
        }
    }

    private var groupedList: GroupedList<SectionID, SettingItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Manual"
        view.backgroundColor = .systemBackground

        groupedList = GroupedList<SectionID, SettingItem>(appearance: .insetGrouped)
        groupedList.collectionView.frame = view.bounds
        groupedList.collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(groupedList.collectionView)

        groupedList.onSelect = { item in
            print("Selected setting: \(item.title)")
        }

        loadSections()
    }

    private func loadSections() {
        let sections: [SectionModel<SectionID, SettingItem>] = [
            SectionModel(
                id: .account,
                items: [
                    SettingItem(id: "profile", title: "Profile", icon: "person.fill"),
                    SettingItem(id: "password", title: "Password", icon: "lock.fill"),
                    SettingItem(id: "email", title: "Email", icon: "envelope.fill", detail: "user@example.com"),
                ],
                header: "Account",
                footer: "Manage your account details and security settings"
            ),
            SectionModel(
                id: .preferences,
                items: [
                    SettingItem(id: "appearance", title: "Appearance", icon: "paintbrush.fill", detail: "System"),
                    SettingItem(id: "language", title: "Language", icon: "globe", detail: "English"),
                    SettingItem(id: "privacy", title: "Privacy", icon: "hand.raised.fill"),
                ],
                header: "Preferences"
            ),
            SectionModel(
                id: .notifications,
                items: [
                    SettingItem(id: "push", title: "Push Notifications", icon: "bell.fill"),
                    SettingItem(id: "email-notif", title: "Email Notifications", icon: "envelope.badge.fill"),
                    SettingItem(id: "sound", title: "Sound", icon: "speaker.wave.2.fill", detail: "Default"),
                ],
                header: "Notifications",
                footer: "Choose how you want to be notified"
            ),
            SectionModel(
                id: .about,
                items: [
                    SettingItem(id: "version", title: "Version", icon: "info.circle", detail: "1.0.0"),
                    SettingItem(id: "licenses", title: "Open Source Licenses", icon: "doc.text"),
                    SettingItem(id: "feedback", title: "Send Feedback", icon: "bubble.left.fill"),
                ],
                header: "About",
                footer: "Built with ListKit"
            ),
        ]

        Task {
            await groupedList.setSections(sections, animatingDifferences: false)
        }
    }
}
