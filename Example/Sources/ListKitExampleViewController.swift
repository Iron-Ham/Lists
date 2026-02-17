// ABOUTME: Raw ListKit API demo with manual snapshot building.
// ABOUTME: Shows two-section list with headers, footers, shuffle, add, and drag reorder.
import ListKit
import UIKit

/// Raw ListKit API demo — manual snapshot building with headers, footers, shuffle, and add.
final class ListKitExampleViewController: UIViewController {

  // MARK: Internal

  enum Section: Int, Hashable, Sendable, CaseIterable {
    case favorites
    case all
  }

  struct Item: Hashable, Sendable {
    let id: UUID
    var title: String

    static func ==(lhs: Item, rhs: Item) -> Bool {
      lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "ListKit"
    view.backgroundColor = .systemBackground

    setupCollectionView()
    setupDataSource()
    setupNavigationBar()
    applyInitialSnapshot()
  }

  // MARK: Private

  private var collectionView: UICollectionView!
  private var dataSource: CollectionViewDiffableDataSource<Section, Item>!
  private var favorites = [Item]()
  private var allItems = [Item]()

  private func setupCollectionView() {
    var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
    config.headerMode = .supplementary
    config.footerMode = .supplementary
    let layout = UICollectionViewCompositionalLayout.list(using: config)

    collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
    collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(collectionView)
  }

  private func setupDataSource() {
    let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, item in
      var content = cell.defaultContentConfiguration()
      content.text = item.title
      cell.contentConfiguration = content
    }

    dataSource = CollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, item in
      cv.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
    }

    let sectionHeaders: [Section: String] = [
      .favorites: "Favorites",
      .all: "All Items",
    ]
    let sectionFooters: [Section: String] = [
      .favorites: "Pinned items appear here",
      .all: "Tap + to add, Shuffle to reorder",
    ]

    let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
      elementKind: UICollectionView.elementKindSectionHeader
    ) { view, _, indexPath in
      guard let section = Section(rawValue: indexPath.section) else { return }
      var content = UIListContentConfiguration.groupedHeader()
      content.text = sectionHeaders[section]
      view.contentConfiguration = content
    }

    let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
      elementKind: UICollectionView.elementKindSectionFooter
    ) { view, _, indexPath in
      guard let section = Section(rawValue: indexPath.section) else { return }
      var content = UIListContentConfiguration.groupedFooter()
      content.text = sectionFooters[section]
      view.contentConfiguration = content
    }

    dataSource.supplementaryViewProvider = { cv, kind, indexPath in
      switch kind {
      case UICollectionView.elementKindSectionHeader:
        cv.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
      case UICollectionView.elementKindSectionFooter:
        cv.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
      default:
        nil
      }
    }

    // Only allow reordering items in the "All Items" section
    dataSource.canMoveItemHandler = { indexPath in
      Section(rawValue: indexPath.section) == .all
    }

    // Persist reorder in the backing array
    dataSource.didMoveItemHandler = { [weak self] source, destination in
      guard let self else { return }
      let item = allItems.remove(at: source.item)
      allItems.insert(item, at: destination.item)
    }

    collectionView.dragInteractionEnabled = true
  }

  private func setupNavigationBar() {
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: "Shuffle",
      style: .plain,
      target: self,
      action: #selector(shuffleTapped)
    )
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .add,
      target: self,
      action: #selector(addTapped)
    )
  }

  private func applyInitialSnapshot() {
    favorites = (1 ... 3).map { Item(id: UUID(), title: "Starred \($0)") }
    allItems = (1 ... 15).map { Item(id: UUID(), title: "Item \($0)") }

    var snapshot = DiffableDataSourceSnapshot<Section, Item>()
    snapshot.appendSections([.favorites, .all])
    snapshot.appendItems(favorites, toSection: .favorites)
    snapshot.appendItems(allItems, toSection: .all)

    Task { await dataSource.apply(snapshot, animatingDifferences: false) }
  }

  @objc
  private func addTapped() {
    let newItem = Item(id: UUID(), title: "Item \(allItems.count + 1)")
    allItems.append(newItem)

    var snapshot = dataSource.snapshot()
    snapshot.appendItems([newItem], toSection: .all)
    Task { await dataSource.apply(snapshot) }
  }

  @objc
  private func shuffleTapped() {
    allItems.shuffle()

    var snapshot = DiffableDataSourceSnapshot<Section, Item>()
    snapshot.appendSections([.favorites, .all])
    snapshot.appendItems(favorites, toSection: .favorites)
    snapshot.appendItems(allItems, toSection: .all)

    Task { await dataSource.apply(snapshot) }
  }
}
