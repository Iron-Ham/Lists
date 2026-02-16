import Lists
import UIKit

/// Manual Lists demo — uses GroupedList with SectionModel, headers, and footers.
final class GroupedListExampleViewController: UIViewController {

  // MARK: Internal

  enum SectionID: String, Hashable, Sendable {
    case account
    case preferences
    case notifications
    case about
  }

  struct SettingItem: ListCellViewModel, Identifiable {

    // MARK: Lifecycle

    init(id: String, title: String, icon: String, detail: String? = nil) {
      self.id = id
      self.title = title
      self.icon = icon
      self.detail = detail
    }

    // MARK: Internal

    let id: String
    let title: String
    let icon: String
    let detail: String?

    @MainActor
    func configure(_ cell: UICollectionViewListCell) {
      cell.setListContent(
        text: title,
        secondaryText: detail,
        image: UIImage(systemName: icon),
        accessories: [.disclosureIndicator]
      )
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Manual"
    view.backgroundColor = .systemBackground

    groupedList = GroupedList<SectionID, SettingItem>(
      appearance: .insetGrouped,
      showsSeparators: true,
      separatorColor: .systemGray4
    )
    groupedList.collectionView.frame = view.bounds
    groupedList.collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(groupedList.collectionView)

    groupedList.onSelect = { item in
      print("Selected setting: \(item.title)")
    }

    groupedList.onDeselect = { item in
      print("Deselected setting: \(item.title)")
    }

    groupedList.onDelete = { [weak self] item in
      guard let self else { return }
      removeItem(item)
    }

    groupedList.trailingSwipeActionsProvider = { [weak self] item in
      let delete = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
        self?.removeItem(item)
        completion(true)
      }
      delete.image = UIImage(systemName: "trash.fill")

      let archive = UIContextualAction(style: .normal, title: "Archive") { _, _, completion in
        print("Archived \(item.title)")
        completion(true)
      }
      archive.image = UIImage(systemName: "archivebox.fill")
      archive.backgroundColor = .systemIndigo

      return UISwipeActionsConfiguration(actions: [delete, archive])
    }

    groupedList.separatorHandler = { [weak self] item, config in
      guard let self else { return config }
      let isAccountItem = sectionItems.first(where: { $0.id == .account })?.items.contains(where: { $0.id == item.id }) ?? false
      if isAccountItem {
        var config = config
        config.color = .systemRed
        return config
      }
      return config
    }

    groupedList.onMove = { [weak self] source, destination in
      guard let self else { return }
      moveItem(from: source, to: destination)
    }

    setupNavigationBar()
    loadSections()
  }

  // MARK: Private

  private var groupedList: GroupedList<SectionID, SettingItem>!
  private var isSelectMode = false

  private var sectionItems: [(id: SectionID, items: [SettingItem], header: String?, footer: String?)] = [
    (
      .account,
      [
        SettingItem(id: "profile", title: "Profile", icon: "person.fill"),
        SettingItem(id: "password", title: "Password", icon: "lock.fill"),
        SettingItem(id: "email", title: "Email", icon: "envelope.fill", detail: "user@example.com"),
      ],
      "Account",
      "Manage your account details and security settings"
    ),
    (
      .preferences,
      [
        SettingItem(id: "appearance", title: "Appearance", icon: "paintbrush.fill", detail: "System"),
        SettingItem(id: "language", title: "Language", icon: "globe", detail: "English"),
        SettingItem(id: "privacy", title: "Privacy", icon: "hand.raised.fill"),
      ],
      "Preferences",
      nil
    ),
    (
      .notifications,
      [
        SettingItem(id: "push", title: "Push Notifications", icon: "bell.fill"),
        SettingItem(id: "email-notif", title: "Email Notifications", icon: "envelope.badge.fill"),
        SettingItem(id: "sound", title: "Sound", icon: "speaker.wave.2.fill", detail: "Default"),
      ],
      "Notifications",
      "Choose how you want to be notified"
    ),
    (
      .about,
      [
        SettingItem(id: "version", title: "Version", icon: "info.circle", detail: "1.0.0"),
        SettingItem(id: "licenses", title: "Open Source Licenses", icon: "doc.text"),
        SettingItem(id: "feedback", title: "Send Feedback", icon: "bubble.left.fill"),
      ],
      "About",
      "Built with ListKit"
    ),
  ]

  private func setupNavigationBar() {
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "Select Mode",
      style: .plain,
      target: self,
      action: #selector(toggleSelectMode)
    )
  }

  @objc
  private func toggleSelectMode() {
    isSelectMode.toggle()
    groupedList.collectionView.allowsMultipleSelection = isSelectMode
    navigationItem.rightBarButtonItem?.title = isSelectMode ? "Done" : "Select Mode"
  }

  private func loadSections() {
    let sections = sectionItems.map { entry in
      SectionModel(
        id: entry.id,
        items: entry.items,
        header: entry.header,
        footer: entry.footer
      )
    }

    Task {
      await groupedList.setSections(sections, animatingDifferences: false)
    }
  }

  private func removeItem(_ item: SettingItem) {
    for i in sectionItems.indices {
      sectionItems[i].items.removeAll { $0.id == item.id }
    }
    reapplySections()
  }

  private func moveItem(from source: IndexPath, to destination: IndexPath) {
    let item = sectionItems[source.section].items.remove(at: source.item)
    sectionItems[destination.section].items.insert(item, at: destination.item)
  }

  private func reapplySections() {
    let sections = sectionItems.map { entry in
      SectionModel(
        id: entry.id,
        items: entry.items,
        header: entry.header,
        footer: entry.footer
      )
    }
    Task {
      await groupedList.setSections(sections)
    }
  }
}
