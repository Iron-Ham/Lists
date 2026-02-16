import ListKit
import Lists
import UIKit

/// Live-updating demo — timer-driven data changes showcasing animated diffing in real time.
/// Simulates a stock watchlist with prices updating, items entering/leaving sections.
final class LiveExampleViewController: UIViewController {

  // MARK: Internal

  enum SectionID: String, Hashable, Sendable {
    case gainers
    case losers
  }

  struct StockItem: ListCellViewModel, Identifiable, ContentEquatable {

    let id: String // ticker symbol
    let name: String
    var price: Double
    var change: Double

    var isGainer: Bool {
      change >= 0
    }

    /// Hash/equality by id only — price/change are mutable display values.
    /// This lets the diff detect cross-section moves (gainer↔loser) instead of delete+insert.
    static func ==(lhs: StockItem, rhs: StockItem) -> Bool {
      lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }

    /// Content equality compares display values so the data source can auto-reconfigure
    /// cells when prices change — no manual `reconfigureItems` needed.
    func isContentEqual(to other: StockItem) -> Bool {
      price == other.price && change == other.change
    }

    @MainActor
    func configure(_ cell: UICollectionViewListCell) {
      cell.setListContent { content in
        content.text = "\(id)  —  \(name)"

        let sign = change >= 0 ? "+" : ""
        let changePercent = String(format: "%@%.2f%%", sign, change)
        let priceStr = String(format: "$%.2f", price)
        content.secondaryText = "\(priceStr)  \(changePercent)"
        content.secondaryTextProperties.color = change >= 0 ? .systemGreen : .systemRed
        content.secondaryTextProperties.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)

        let symbolName = change >= 0 ? "arrow.up.right" : "arrow.down.right"
        content.image = UIImage(systemName: symbolName)
        content.imageProperties.tintColor = change >= 0 ? .systemGreen : .systemRed
      }
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Live"
    view.backgroundColor = .systemBackground

    setupCollectionView()
    dataSource = ListDataSource(collectionView: collectionView)
    setupSupplementaryViews()
    setupNavigationBar()
    loadInitialData()
    applySnapshot(animated: false)
    startTimer()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    timer?.invalidate()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if timer == nil || !(timer?.isValid ?? false) {
      startTimer()
    }
  }

  // MARK: Private

  private var dataSource: ListDataSource<SectionID, StockItem>!
  private var collectionView: UICollectionView!
  private var timer: Timer?
  private var stocks = [StockItem]()
  private var tickCount = 0

  private func setupCollectionView() {
    var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
    config.headerMode = .supplementary
    config.footerMode = .supplementary
    let layout = UICollectionViewCompositionalLayout.list(using: config)

    collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
    collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(collectionView)
  }

  private func setupSupplementaryViews() {
    let sectionHeaders: [SectionID: String] = [
      .gainers: "Gainers",
      .losers: "Losers",
    ]

    let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
      elementKind: UICollectionView.elementKindSectionHeader
    ) { view, _, indexPath in
      let sections: [SectionID] = [.gainers, .losers]
      guard indexPath.section < sections.count else { return }
      var content = UIListContentConfiguration.groupedHeader()
      content.text = sectionHeaders[sections[indexPath.section]]
      view.contentConfiguration = content
    }

    let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
      elementKind: UICollectionView.elementKindSectionFooter
    ) { [weak self] view, _, indexPath in
      guard let self else { return }
      var content = UIListContentConfiguration.groupedFooter()
      let sections: [SectionID] = [.gainers, .losers]
      guard indexPath.section < sections.count else { return }
      let section = sections[indexPath.section]
      switch section {
      case .gainers:
        let count = stocks.filter(\.isGainer).count
        content.text = "\(count) stocks trending up"

      case .losers:
        let count = stocks.count(where: { !$0.isGainer })
        content.text = "\(count) stocks trending down"
      }
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
  }

  private func setupNavigationBar() {
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "Reset",
      style: .plain,
      target: self,
      action: #selector(resetTapped)
    )
  }

  private func loadInitialData() {
    stocks = [
      StockItem(id: "AAPL", name: "Apple Inc.", price: 189.45, change: 1.23),
      StockItem(id: "GOOGL", name: "Alphabet Inc.", price: 141.80, change: -0.54),
      StockItem(id: "MSFT", name: "Microsoft Corp.", price: 378.91, change: 2.15),
      StockItem(id: "AMZN", name: "Amazon.com Inc.", price: 178.25, change: -1.87),
      StockItem(id: "TSLA", name: "Tesla Inc.", price: 248.42, change: 3.42),
      StockItem(id: "META", name: "Meta Platforms", price: 505.75, change: -0.31),
      StockItem(id: "NVDA", name: "NVIDIA Corp.", price: 875.30, change: 4.56),
      StockItem(id: "NFLX", name: "Netflix Inc.", price: 628.15, change: -2.10),
      StockItem(id: "AMD", name: "Advanced Micro", price: 164.80, change: 0.78),
      StockItem(id: "INTC", name: "Intel Corp.", price: 42.35, change: -3.21),
    ]
  }

  private func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.tick()
      }
    }
  }

  private func tick() {
    tickCount += 1

    // Randomly adjust prices and changes
    for i in stocks.indices {
      let delta = Double.random(in: -2.0 ... 2.0)
      stocks[i].price = max(1.0, stocks[i].price + delta)
      stocks[i].change += Double.random(in: -1.5 ... 1.5)
      stocks[i].change = max(-15, min(15, stocks[i].change))
    }

    // Every 5 ticks, shuffle order within sections to show move animations
    if tickCount % 5 == 0 {
      stocks.shuffle()
    }

    applySnapshot(animated: true)
  }

  private func applySnapshot(animated: Bool) {
    let gainers = stocks.filter(\.isGainer).sorted { $0.change > $1.change }
    let losers = stocks.filter { !$0.isGainer }.sorted { $0.change < $1.change }

    // StockItem conforms to ContentEquatable, so the data source automatically
    // detects content changes (price/change) and reconfigures affected cells.
    // No manual reconfigureItems call needed.
    var snapshot = ListDataSource<SectionID, StockItem>.Snapshot()
    snapshot.appendSections([.gainers, .losers])
    snapshot.appendItems(gainers, toSection: .gainers)
    snapshot.appendItems(losers, toSection: .losers)

    Task {
      await dataSource.apply(snapshot, animatingDifferences: animated)
    }
  }

  @objc
  private func resetTapped() {
    tickCount = 0
    loadInitialData()
    applySnapshot(animated: true)
  }
}
