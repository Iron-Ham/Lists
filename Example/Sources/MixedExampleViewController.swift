import ListKit
import Lists
import UIKit

// MARK: - MixedExampleViewController

/// Mixed cell types demo — uses MixedListDataSource with heterogeneous CellViewModel types.
final class MixedExampleViewController: UIViewController {

  // MARK: Internal

  enum SectionID: Hashable, Sendable {
    case banner
    case products
    case ratings
  }

  struct BannerItem: CellViewModel, Identifiable {
    typealias Cell = UICollectionViewListCell

    let id: String
    let title: String
    let subtitle: String

    @MainActor
    func configure(_ cell: UICollectionViewListCell) {
      var content = cell.defaultContentConfiguration()
      content.text = title
      content.secondaryText = subtitle
      content.image = UIImage(systemName: "megaphone.fill")
      content.imageProperties.tintColor = .systemOrange
      content.textProperties.font = .preferredFont(forTextStyle: .headline)
      cell.contentConfiguration = content
    }
  }

  struct ProductItem: CellViewModel, Identifiable {
    typealias Cell = UICollectionViewListCell

    let id: String
    let name: String
    let price: String
    let icon: String

    @MainActor
    func configure(_ cell: UICollectionViewListCell) {
      var content = cell.defaultContentConfiguration()
      content.text = name
      content.secondaryText = price
      content.image = UIImage(systemName: icon)
      content.imageProperties.tintColor = .systemBlue
      cell.accessories = [.disclosureIndicator()]
      cell.contentConfiguration = content
    }
  }

  struct RatingItem: CellViewModel, Identifiable {
    typealias Cell = UICollectionViewListCell

    let id: String
    let reviewer: String
    let stars: Int

    @MainActor
    func configure(_ cell: UICollectionViewListCell) {
      var content = cell.defaultContentConfiguration()
      content.text = reviewer
      content.secondaryText = String(repeating: "\u{2605}", count: stars)
        + String(repeating: "\u{2606}", count: 5 - stars)
      content.secondaryTextProperties.color = .systemYellow
      content.image = UIImage(systemName: "person.circle.fill")
      content.imageProperties.tintColor = .systemGray
      cell.contentConfiguration = content
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Mixed"
    view.backgroundColor = .systemBackground

    setupCollectionView()
    dataSource = MixedListDataSource(collectionView: collectionView)
    setupHeaders()
    setupNavigationBar()
    applySnapshot()
  }

  // MARK: Private

  private var dataSource: MixedListDataSource<SectionID>!
  private var collectionView: UICollectionView!
  private var showBanner = true

  private func setupCollectionView() {
    var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
    config.headerMode = .supplementary
    let layout = UICollectionViewCompositionalLayout.list(using: config)

    collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
    collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    collectionView.delegate = self
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
      case .banner: content.text = "Featured"
      case .products: content.text = "Products"
      case .ratings: content.text = "Reviews"
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
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "Toggle Banner",
      style: .plain,
      target: self,
      action: #selector(toggleBanner)
    )
  }

  private func applySnapshot() {
    Task {
      await dataSource.apply {
        if showBanner {
          MixedSection(.banner) {
            BannerItem(id: "sale", title: "Summer Sale!", subtitle: "Up to 50% off")
            BannerItem(id: "new", title: "New Arrivals", subtitle: "Check out what's new")
          }
        }

        MixedSection(.products) {
          ProductItem(id: "laptop", name: "Laptop Pro", price: "$1,299", icon: "laptopcomputer")
          ProductItem(id: "phone", name: "Phone Ultra", price: "$999", icon: "iphone")
          ProductItem(id: "watch", name: "Watch SE", price: "$249", icon: "applewatch")
          ProductItem(id: "headphones", name: "AirPods Max", price: "$549", icon: "headphones")
        }

        MixedSection(.ratings) {
          RatingItem(id: "r1", reviewer: "Alice", stars: 5)
          RatingItem(id: "r2", reviewer: "Bob", stars: 4)
          RatingItem(id: "r3", reviewer: "Charlie", stars: 3)
        }
      }
    }
  }

  @objc
  private func toggleBanner() {
    showBanner.toggle()
    applySnapshot()
  }
}

// MARK: UICollectionViewDelegate

extension MixedExampleViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    collectionView.deselectItem(at: indexPath, animated: true)
    guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

    if let banner = item.as(BannerItem.self) {
      print("Tapped banner: \(banner.title)")
    } else if let product = item.as(ProductItem.self) {
      print("Tapped product: \(product.name) — \(product.price)")
    } else if let rating = item.as(RatingItem.self) {
      print("Tapped review by \(rating.reviewer): \(rating.stars) stars")
    }
  }
}
