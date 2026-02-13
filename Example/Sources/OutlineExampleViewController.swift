import Lists
import UIKit

/// OutlineList demo — hierarchical expand/collapse with nested items.
/// Shows a file browser with folders containing files and sub-folders.
final class OutlineExampleViewController: UIViewController {
    struct FileItem: CellViewModel, Identifiable {
        typealias Cell = UICollectionViewListCell
        let id: String
        let name: String
        let isFolder: Bool

        init(id: String? = nil, name: String, isFolder: Bool = false) {
            self.id = id ?? name
            self.name = name
            self.isFolder = isFolder
        }

        @MainActor func configure(_ cell: UICollectionViewListCell) {
            var content = cell.defaultContentConfiguration()
            content.text = name

            if isFolder {
                content.image = UIImage(systemName: "folder.fill")
                content.imageProperties.tintColor = .systemBlue
            } else {
                let ext = (name as NSString).pathExtension.lowercased()
                switch ext {
                case "swift":
                    content.image = UIImage(systemName: "swift")
                    content.imageProperties.tintColor = .systemOrange
                case "json", "plist":
                    content.image = UIImage(systemName: "doc.text")
                    content.imageProperties.tintColor = .systemGreen
                case "md":
                    content.image = UIImage(systemName: "doc.richtext")
                    content.imageProperties.tintColor = .systemPurple
                default:
                    content.image = UIImage(systemName: "doc")
                    content.imageProperties.tintColor = .secondaryLabel
                }
            }

            cell.contentConfiguration = content
        }
    }

    private var outlineList: OutlineList<FileItem>!
    private var fileTree: [OutlineItem<FileItem>] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Outline"
        view.backgroundColor = .systemBackground

        outlineList = OutlineList<FileItem>(appearance: .sidebar)
        outlineList.collectionView.frame = view.bounds
        outlineList.collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(outlineList.collectionView)

        outlineList.onSelect = { item in
            print("Selected: \(item.name)")
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
        fileTree = [
            OutlineItem(
                item: FileItem(name: "Sources", isFolder: true),
                children: [
                    OutlineItem(
                        item: FileItem(name: "ListKit", isFolder: true),
                        children: [
                            OutlineItem(
                                item: FileItem(name: "Algorithm", isFolder: true),
                                children: [
                                    OutlineItem(item: FileItem(name: "HeckelDiff.swift")),
                                    OutlineItem(item: FileItem(name: "SectionedDiff.swift")),
                                    OutlineItem(item: FileItem(name: "StagedChangeset.swift")),
                                ],
                                isExpanded: true
                            ),
                            OutlineItem(
                                item: FileItem(name: "DataSource", isFolder: true),
                                children: [
                                    OutlineItem(item: FileItem(name: "CollectionViewDiffableDataSource.swift")),
                                ],
                                isExpanded: true
                            ),
                            OutlineItem(
                                item: FileItem(name: "Snapshot", isFolder: true),
                                children: [
                                    OutlineItem(item: FileItem(name: "DiffableDataSourceSnapshot.swift")),
                                    OutlineItem(item: FileItem(name: "DiffableDataSourceSectionSnapshot.swift")),
                                ]
                            ),
                        ],
                        isExpanded: true
                    ),
                    OutlineItem(
                        item: FileItem(name: "Lists", isFolder: true),
                        children: [
                            OutlineItem(item: FileItem(name: "CellViewModel.swift")),
                            OutlineItem(item: FileItem(name: "ListDataSource.swift")),
                            OutlineItem(item: FileItem(name: "SimpleList.swift")),
                            OutlineItem(item: FileItem(name: "GroupedList.swift")),
                            OutlineItem(item: FileItem(name: "OutlineList.swift")),
                        ],
                        isExpanded: true
                    ),
                ],
                isExpanded: true
            ),
            OutlineItem(
                item: FileItem(name: "Tests", isFolder: true),
                children: [
                    OutlineItem(item: FileItem(name: "HeckelDiffTests.swift")),
                    OutlineItem(item: FileItem(name: "SnapshotTests.swift")),
                    OutlineItem(item: FileItem(name: "PerformanceTests.swift")),
                ]
            ),
            OutlineItem(item: FileItem(name: "Package.swift")),
            OutlineItem(item: FileItem(name: "README.md")),
        ]
    }

    private func applySnapshot() {
        Task {
            await outlineList.setItems(fileTree, animatingDifferences: false)
        }
    }

    @objc private func shuffleTapped() {
        /// Shuffle children within each expanded folder
        func shuffleChildren(_ items: [OutlineItem<FileItem>]) -> [OutlineItem<FileItem>] {
            items.shuffled().map { item in
                if item.children.isEmpty {
                    return item
                }
                return OutlineItem(
                    item: item.item,
                    children: shuffleChildren(item.children),
                    isExpanded: item.isExpanded
                )
            }
        }

        fileTree = shuffleChildren(fileTree)
        Task {
            await outlineList.setItems(fileTree)
        }
    }
}
