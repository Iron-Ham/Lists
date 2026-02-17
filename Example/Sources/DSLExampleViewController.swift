// ABOUTME: Demo of @SnapshotBuilder DSL with GroupedList for declarative snapshots.
// ABOUTME: Shows header/footer support, pull-to-refresh, and snapshot querying.
import ListKit
import Lists
import UIKit

/// DSL demo — builds snapshots using @SnapshotBuilder result-builder syntax
/// with GroupedList, demonstrating header/footer support, pull-to-refresh,
/// and snapshot querying with `contains(section:)`.
final class DSLExampleViewController: UIViewController {

  // MARK: Internal

  enum SectionID: Hashable, Sendable {
    case pinned
    case category(String)
  }

  struct TodoItem: ListCellViewModel, Identifiable {

    // MARK: Lifecycle

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, priority: Priority = .normal) {
      self.id = id
      self.title = title
      self.isCompleted = isCompleted
      self.priority = priority
    }

    // MARK: Internal

    enum Priority: Sendable { case high, normal, low }

    let id: UUID
    let title: String
    let isCompleted: Bool
    let priority: Priority

    @MainActor
    func configure(_ cell: UICollectionViewListCell) {
      cell.setListContent { content in
        content.text = title
        if isCompleted {
          content.textProperties.color = .secondaryLabel
          content.image = UIImage(systemName: "checkmark.circle.fill")
          content.imageProperties.tintColor = .systemGreen
        } else {
          switch priority {
          case .high:
            content.image = UIImage(systemName: "exclamationmark.circle.fill")
            content.imageProperties.tintColor = .systemRed

          case .normal:
            content.image = UIImage(systemName: "circle")
            content.imageProperties.tintColor = .systemBlue

          case .low:
            content.image = UIImage(systemName: "circle")
            content.imageProperties.tintColor = .systemGray
          }
        }
      }
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "DSL"
    view.backgroundColor = .systemBackground

    groupedList = GroupedList<SectionID, TodoItem>(appearance: .insetGrouped)
    groupedList.collectionView.frame = view.bounds
    groupedList.collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(groupedList.collectionView)

    // UIKit pull-to-refresh via onRefresh
    groupedList.onRefresh = { [weak self] in
      guard let self else { return }
      try? await Task.sleep(for: .seconds(1))
      for i in categories.indices {
        categories[i].items.shuffle()
      }
      await applySnapshot()
    }

    setupNavigationBar()
    loadData()
    Task { await applySnapshot() }
  }

  // MARK: Private

  private var groupedList: GroupedList<SectionID, TodoItem>!
  private var showCompleted = true
  private var pinnedItems = [TodoItem]()
  private var categories = [(name: String, items: [TodoItem])]()

  private func setupNavigationBar() {
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: "Toggle Done",
      style: .plain,
      target: self,
      action: #selector(toggleCompleted)
    )
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "Shuffle",
      style: .plain,
      target: self,
      action: #selector(shuffleTapped)
    )
  }

  private func loadData() {
    pinnedItems = [
      TodoItem(title: "Ship v1.0", priority: .high),
      TodoItem(title: "Write release notes", priority: .high),
    ]

    categories = [
      ("Work", [
        TodoItem(title: "Review pull request"),
        TodoItem(title: "Update documentation"),
        TodoItem(title: "Fix CI pipeline", priority: .high),
        TodoItem(title: "Refactor auth module", isCompleted: true),
      ]),
      ("Personal", [
        TodoItem(title: "Grocery shopping", priority: .low),
        TodoItem(title: "Call dentist", isCompleted: true),
        TodoItem(title: "Read Swift book"),
      ]),
      ("Ideas", [
        TodoItem(title: "Blog post about ListKit", priority: .low),
        TodoItem(title: "Open source side project", priority: .low),
      ]),
    ]
  }

  private func applySnapshot() async {
    // SnapshotSection DSL with header/footer — GroupedList renders these
    // as section headers and footers automatically.
    await groupedList.setSections {
      SnapshotSection(.pinned, header: "Pinned", footer: "\(pinnedItems.count) items") {
        pinnedItems
      }

      for category in categories {
        let items = showCompleted ? category.items : category.items.filter { !$0.isCompleted }
        SnapshotSection(
          .category(category.name),
          header: category.name,
          footer: "\(items.count) items"
        ) {
          items
        }
      }
    }
  }

  @objc
  private func toggleCompleted() {
    showCompleted.toggle()
    navigationItem.leftBarButtonItem?.title = showCompleted ? "Toggle Done" : "Show Done"

    // Demonstrate Snapshot.contains(section:) — verify a section exists before querying it
    let snapshot = groupedList.snapshot()
    if snapshot.contains(section: .pinned) {
      print("Pinned section has \(snapshot.itemIdentifiers(inSection: .pinned).count) items")
    }

    Task { await applySnapshot() }
  }

  @objc
  private func shuffleTapped() {
    for i in categories.indices {
      categories[i].items.shuffle()
    }
    Task { await applySnapshot() }
  }
}
