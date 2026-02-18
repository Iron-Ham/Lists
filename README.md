# ListKit

A fast, pure-Swift diffable data source for `UICollectionView`. Drop-in replacement for Apple's `UICollectionViewDiffableDataSource` with an O(n) Heckel diff algorithm and a high-level declarative API.

**Two libraries, one repo:**

| Library | Purpose |
|:--------|:--------|
| **ListKit** | Low-level diffing engine and data source. API-compatible with Apple's `NSDiffableDataSourceSnapshot`. |
| **Lists** | High-level, ViewModel-driven layer with result-builder DSL, automatic cell registration, pre-built list configurations, and SwiftUI wrappers. |

**[Documentation](https://iron-ham.github.io/Lists/documentation)** — full API reference, guides, and examples.

## Requirements

- iOS 17.0+
- Swift 6.0
- Xcode 17+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Iron-Ham/ListKit", from: "0.5.0"),
]
```

Then add `ListKit`, `Lists`, or both to your target:

```swift
.target(name: "MyApp", dependencies: ["ListKit", "Lists"])
```

### Tuist

```swift
.external(name: "ListKit"),
.external(name: "Lists"),
```

## Quick Start

Define a view model, build a snapshot with the DSL, done:

```swift
import Lists

struct ContactItem: CellViewModel, Identifiable {
    typealias Cell = UICollectionViewListCell
    let id: UUID
    let name: String

    @MainActor func configure(_ cell: UICollectionViewListCell) {
        var content = cell.defaultContentConfiguration()
        content.text = name
        cell.contentConfiguration = content
    }
}

class ContactsViewController: UIViewController {
    private var dataSource: ListDataSource<String, ContactItem>!
    private var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()
        let layout = ListLayout.plain()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        view.addSubview(collectionView)

        dataSource = ListDataSource(collectionView: collectionView)

        Task {
            await dataSource.apply {
                SnapshotSection("contacts") {
                    ContactItem(id: UUID(), name: "Alice")
                    ContactItem(id: UUID(), name: "Bob")
                }
            }
        }
    }
}
```

Lists also provides pre-built configurations (`SimpleList`, `GroupedList`, `OutlineList`) with SwiftUI wrappers, mixed cell type support, and more. See the [documentation](https://iron-ham.github.io/Lists/documentation) for the full API.

## Benchmarks

All benchmarks run in **Release configuration** with median-of-15 and 5 warmup iterations on Apple Silicon.

### vs Apple's NSDiffableDataSourceSnapshot

| Operation | ListKit | Apple | Speedup |
|:---|---:|---:|---:|
| Build 10k items | 0.002 ms | 1.223 ms | **752.7x** |
| Build 50k items | 0.006 ms | 6.010 ms | **1,045.3x** |
| Build 100 sections x 100 | 0.060 ms | 3.983 ms | **66.4x** |
| Delete 5k from 10k | 1.206 ms | 2.448 ms | **2.0x** |
| Delete 25/50 sections | 0.180 ms | 1.852 ms | **10.3x** |
| Reload 5k items | 0.099 ms | 1.547 ms | **15.7x** |
| Query itemIdentifiers 100x | 0.051 ms | 46.364 ms | **908.3x** |

#### With Item.ID (UUID) — realistic pattern

Real-world apps store `Item.ID` in the snapshot, not the full model — the [Apple-recommended pattern](https://developer.apple.com/documentation/uikit/uicollectionviewdiffabledatasource). These benchmarks use `UUID` identifiers from an `Identifiable` model type.

| Operation | ListKit | Apple | Speedup |
|:---|---:|---:|---:|
| Build 10k Item.IDs | 0.003 ms | 2.269 ms | **789.2x** |
| Delete 5k Item.IDs | 1.358 ms | 4.084 ms | **3.0x** |
| Reload 5k Item.IDs | 0.284 ms | 2.738 ms | **9.6x** |

ListKit snapshots are pure Swift value types with flat array storage and a lazy reverse index. Apple's `NSDiffableDataSourceSnapshot` is backed by Objective-C runtime overhead and per-query hashing.

### vs IGListKit (Instagram)

Both libraries implement Paul Heckel's O(n) diff. IGListKit's is Objective-C++; ListKit's is pure Swift. Both sides pre-build their data structures before the timed block so only the diff algorithm is measured — `ListDiff()` for IGListKit, `SectionedDiff.diff()` for ListKit. IGListKit diffs a single flat array; ListKit diffs sections first, then items per-section, and reconciles cross-section moves.

| Operation | IGListKit | ListKit | Notes |
|:---|---:|---:|:---|
| Diff 10k (50% overlap) | 10.8 ms | 3.9 ms | **2.8x** — ListKit wins at common scale |
| Diff 50k (50% overlap) | 55.4 ms | 19.6 ms | **2.8x** — ListKit wins at scale too |
| Diff no-change 10k | 9.5 ms | 0.09 ms | **106x** — per-section skip makes this free |
| Diff shuffle 10k | 9.8 ms | 3.2 ms | **3.1x** — ListKit wins all-moves case |

Per-section diffing skips unchanged sections entirely — the common case for incremental UI updates.

### Mixed Operations (Inserts + Deletes + Moves)

Real-world list updates rarely involve just one type of change. A feed refresh might delete stale items, insert new ones, and re-rank existing items — all at once. These benchmarks combine all three operations in a single diff using `Item.ID` (UUID) identifiers. "Moderate churn" changes 20% of items per operation type; "heavy churn" changes 50%.

#### Diff Algorithm — ListKit vs IGListKit

| Scenario | IGListKit | ListKit | Speedup |
|:---|---:|---:|---:|
| 10k — moderate churn | 10.6 ms | 3.3 ms | **3.2x** |
| 10k — heavy churn | 11.4 ms | 3.9 ms | **2.9x** |
| 50k — moderate churn | 52.0 ms | 16.7 ms | **3.1x** |

#### Snapshot Build — ListKit vs Apple (Item.ID)

| Scenario | Apple | ListKit | Speedup |
|:---|---:|---:|---:|
| 10k — moderate churn | 4.238 ms | 0.005 ms | **782x** |
| 10k — heavy churn | 4.359 ms | 0.007 ms | **627x** |
| 50k — moderate churn | 22.816 ms | 0.022 ms | **1,049x** |

ListKit's full pipeline (snapshot build + diff) for 10k items with moderate churn completes faster than Apple takes to just *build* the snapshots.

#### Data Source Apply — ListKit vs Apple (Item.ID)

The ultimate end-to-end test: `apply()` on a real `UICollectionViewDiffableDataSource`, which includes the diff computation, `performBatchUpdates`, and all UIKit bookkeeping. Apple's diff algorithm is internal and can't be benchmarked in isolation — this is the only way to measure it.

| Scenario | Apple | ListKit | Speedup |
|:---|---:|---:|---:|
| 10k — moderate churn | 11.9 ms | 8.7 ms | **1.4x** |
| 10k — heavy churn | 23.5 ms | 14.2 ms | **1.7x** |

The speedup is smaller here than in isolated benchmarks because both frameworks share the same `UICollectionView` overhead (batch updates, layout invalidation). The diff advantage matters most at scale: Apple's heavy-churn apply exceeds the 16 ms frame budget, while ListKit stays under.

### vs ReactiveCollectionsKit

ReactiveCollectionsKit wraps Apple's `NSDiffableDataSourceSnapshot` with type-erased `CollectionViewModel` layers. These benchmarks compare model construction (building the data structures each library needs before applying to a collection view).

| Operation | ListKit | ReactiveCollectionsKit | Apple | Speedup vs RC |
|:---|---:|---:|---:|---:|
| Build 10k items | 0.004 ms | 7.5 ms | 1.3 ms | **1,871x** |
| Build 50k items | 0.014 ms | 37.4 ms | — | **2,671x** |
| Build 100 sections x 100 | 0.058 ms | 7.3 ms | 4.2 ms | **126x** |

Run benchmarks with `make benchmark`.

## Development

```bash
make setup       # install Tuist, fetch dependencies, generate project, install hooks
make build       # build ListKit + Lists frameworks
make test        # run all tests (ListKit + Lists)
make benchmark   # run performance benchmarks
make format      # format code with SwiftFormat
make lint        # lint with SwiftFormat
make open        # open in Xcode
```

## License

MIT
