import ListKit
import Lists
import UIKit

/// DSL demo — builds snapshots using @SnapshotBuilder result-builder syntax.
final class DSLExampleViewController: UIViewController {
    enum SectionID: Hashable, Sendable {
        case pinned
        case category(String)
    }

    struct TodoItem: CellViewModel, Identifiable {
        typealias Cell = UICollectionViewListCell
        let id: UUID
        let title: String
        let isCompleted: Bool
        let priority: Priority

        enum Priority: Sendable { case high, normal, low }

        init(id: UUID = UUID(), title: String, isCompleted: Bool = false, priority: Priority = .normal) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
            self.priority = priority
        }

        @MainActor func configure(_ cell: UICollectionViewListCell) {
            var content = cell.defaultContentConfiguration()
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
            cell.contentConfiguration = content
        }
    }

    private var dataSource: ListDataSource<SectionID, TodoItem>!
    private var collectionView: UICollectionView!
    private var showCompleted = true
    private var pinnedItems: [TodoItem] = []
    private var categories: [(name: String, items: [TodoItem])] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "DSL"
        view.backgroundColor = .systemBackground

        setupCollectionView()
        dataSource = ListDataSource(collectionView: collectionView)
        setupHeaders()
        setupNavigationBar()
        loadData()
        applySnapshot()
    }

    private func setupCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        let layout = UICollectionViewCompositionalLayout.list(using: config)

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)
    }

    private func setupHeaders() {
        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] view, _, indexPath in
            guard let self else { return }
            let snapshot = dataSource.snapshot()
            guard indexPath.section < snapshot.sectionIdentifiers.count else { return }
            var content = UIListContentConfiguration.groupedHeader()
            switch snapshot.sectionIdentifiers[indexPath.section] {
            case .pinned: content.text = "Pinned"
            case let .category(name): content.text = name
            }
            view.contentConfiguration = content
        }

        dataSource.supplementaryViewProvider = { cv, kind, indexPath in
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                cv.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            default:
                nil
            }
        }
    }

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

    private func applySnapshot() {
        Task {
            // The DSL enables declarative, conditional snapshot building
            await dataSource.apply {
                // Pinned section always shows
                SnapshotSection(.pinned) {
                    pinnedItems
                }

                // Dynamic sections from data
                for category in categories {
                    SnapshotSection(.category(category.name)) {
                        if showCompleted {
                            category.items
                        } else {
                            category.items.filter { !$0.isCompleted }
                        }
                    }
                }
            }
        }
    }

    @objc private func toggleCompleted() {
        showCompleted.toggle()
        navigationItem.leftBarButtonItem?.title = showCompleted ? "Toggle Done" : "Show Done"
        applySnapshot()
    }

    @objc private func shuffleTapped() {
        for i in categories.indices {
            categories[i].items.shuffle()
        }
        applySnapshot()
    }
}
