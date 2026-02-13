# ListKit

A fast, pure-Swift diffable data source for `UICollectionView`. Drop-in replacement for Apple's `UICollectionViewDiffableDataSource` with an O(n) Heckel diff algorithm and a high-level declarative API.

**Two libraries, one repo:**

| Library | Purpose |
|:--------|:--------|
| **ListKit** | Low-level diffing engine and data source. API-compatible with Apple's `NSDiffableDataSourceSnapshot`. |
| **Lists** | High-level, ViewModel-driven layer with result-builder DSL, automatic cell registration, and pre-built list configurations. |

## Requirements

- iOS 17.0+
- Swift 6.0
- Xcode 17+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/<owner>/ListKit", from: "0.1.0"),
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

### Lists (recommended for most apps)

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

### ListKit (low-level API)

Same API surface as Apple's diffable data source — familiar if you've used `UICollectionViewDiffableDataSource`:

```swift
import ListKit

let dataSource = CollectionViewDiffableDataSource<String, Int>(
    collectionView: collectionView
) { cv, indexPath, item in
    let cell = cv.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
    // configure cell
    return cell
}

var snapshot = DiffableDataSourceSnapshot<String, Int>()
snapshot.appendSections(["main"])
snapshot.appendItems([1, 2, 3], toSection: "main")
await dataSource.apply(snapshot)
```

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Lists                                                       │
│  ┌──────────────┐  ┌───────────┐  ┌──────────────┐           │
│  │ SimpleList   │  │ GroupedList│  │ OutlineList  │           │
│  └──────┬───────┘  └─────┬─────┘  └──────┬───────┘           │
│         └────────┬───────┘               │                   │
│           ┌──────▼──────┐                │                   │
│           │ListDataSource│───────────────┘                   │
│           └──────┬──────┘                                    │
│       ┌──────────▼───────────┐                               │
│       │MixedListDataSource   │  (heterogeneous cell types)   │
│       │  AnyItem + Registrar │                               │
│       └──────────┬───────────┘                               │
│   ┌──────────────┼──────────────────┐                        │
│   │SnapshotBuilder│  CellViewModel  │                        │
│   └──────────────┴──────────────────┘                        │
├──────────────────────────────────────────────────────────────┤
│  ListKit                                                     │
│  ┌─────────────────────────────────────┐                     │
│  │ CollectionViewDiffableDataSource    │                     │
│  └──────────────┬──────────────────────┘                     │
│  ┌──────────────▼──────────────────────┐                     │
│  │ DiffableDataSourceSnapshot          │                     │
│  │ DiffableDataSourceSectionSnapshot   │                     │
│  └──────────────┬──────────────────────┘                     │
│  ┌──────────────▼──────────────────────┐                     │
│  │ HeckelDiff (O(n))                   │                     │
│  │ SectionedDiff                       │                     │
│  └─────────────────────────────────────┘                     │
└──────────────────────────────────────────────────────────────┘
```

## Features

### CellViewModel Protocol

One protocol, one method. ViewModels are the item identifiers — no type erasure needed:

```swift
public protocol CellViewModel: Hashable, Sendable {
    associatedtype Cell: UICollectionViewCell
    @MainActor func configure(_ cell: Cell)
}
```

Conform to `Identifiable` to get automatic id-based `Hashable`/`Equatable`:

```swift
struct TodoItem: CellViewModel, Identifiable {
    typealias Cell = UICollectionViewListCell
    let id: UUID
    let title: String
    let isCompleted: Bool  // not included in hash/equality

    @MainActor func configure(_ cell: UICollectionViewListCell) { ... }
}
```

### Result-Builder DSL

Build snapshots declaratively with `if`/`else`, `for` loops, and conditionals:

```swift
await dataSource.apply {
    SnapshotSection(.pinned) {
        pinnedItems
    }

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
```

### Pre-Built Configurations

| Type | Use Case |
|:-----|:---------|
| `SimpleList<Item>` | Single-section flat list. Owns its collection view and layout. |
| `GroupedList<SectionID, Item>` | Multi-section with headers/footers from `SectionModel`. |
| `OutlineList<Item>` | Hierarchical expand/collapse via `OutlineItem` tree. |

### Hierarchical Data

`DiffableDataSourceSectionSnapshot` supports parent-child relationships with expand/collapse:

```swift
var sectionSnapshot = DiffableDataSourceSectionSnapshot<Item>()
sectionSnapshot.append([parent])
sectionSnapshot.append([child1, child2], to: parent)
sectionSnapshot.expand([parent])

await dataSource.apply(sectionSnapshot, to: .files)
```

### Mixed Cell Types

`MixedListDataSource` supports heterogeneous `CellViewModel` types in a single data source via type-erased `AnyItem`. Each section (or even each row) can use a different cell type:

```swift
struct BannerItem: CellViewModel { typealias Cell = BannerCell; ... }
struct ProductItem: CellViewModel { typealias Cell = ProductCell; ... }

let dataSource = MixedListDataSource<SectionID>(collectionView: collectionView)

await dataSource.apply {
    MixedSection(.banners) {
        BannerItem(title: "Summer Sale!")
    }
    MixedSection(.products) {
        ProductItem(name: "Laptop", price: "$999")
        ProductItem(name: "Phone", price: "$699")
    }
}

// Type-safe extraction for tap handling
if let product = anyItem.as(ProductItem.self) { showDetail(product) }
```

`MixedListDataSource` uses type-erased `AnyItem` wrappers, which adds overhead compared to the concrete `ListDataSource` path. `AnyItem` uses precomputed hashing and `ObjectIdentifier` fast-reject equality to minimize the cost — cross-type comparisons are a single pointer compare, not a witness table dispatch.

| Operation | Concrete | AnyItem | Overhead |
|:---|---:|---:|---:|
| Wrap 10k items | — | 0.5 ms | — |
| Build 10k snapshot | 0.002 ms | 0.08 ms | ~40x |
| DSL build 100 sections x 100 | 0.4 ms | 1.4 ms | ~3x |
| Diff 10k (50% overlap) | 12.0 ms | 17.1 ms | ~1.4x |
| Diff 10k (cross-type replace) | — | 28.6 ms | — |

Snapshot construction overhead is measurable but sub-millisecond at typical scales. The critical path — diffing — adds only ~40% overhead, and both absolute times remain well within a single frame budget (16ms @ 60fps for typical list sizes).

### Swift 6 Strict Concurrency

All types are `Sendable`. The data source is `@MainActor`. Snapshots are value types that can be built on any thread and applied on main.

## Current Limitations

**Delegate access in pre-built configurations.** `SimpleList`, `GroupedList`, and `OutlineList` own the `UICollectionViewDelegate` and only expose `onSelect`. Swipe actions, context menus, and drag-and-drop require using `ListDataSource` or `CollectionViewDiffableDataSource` directly with your own delegate.

## Benchmarks

All benchmarks run in **Release configuration** with median-of-15 and 5 warmup iterations on Apple Silicon.

### vs Apple's NSDiffableDataSourceSnapshot

| Operation | ListKit | Apple | Speedup |
|:---|---:|---:|---:|
| Build 10k items | 0.002 ms | 1.286 ms | **857.6x** |
| Build 50k items | 0.006 ms | 6.324 ms | **1,054.0x** |
| Build 100 sections x 100 | 0.057 ms | 4.227 ms | **74.8x** |
| Delete 5k from 10k | 1.184 ms | 2.462 ms | **2.1x** |
| Delete 25/50 sections | 0.043 ms | 1.934 ms | **44.8x** |
| Reload 5k items | 0.100 ms | 1.632 ms | **16.3x** |
| Query itemIdentifiers 100x | 0.054 ms | 48.326 ms | **886.7x** |

ListKit snapshots are pure Swift value types with flat array storage and a lazy reverse index. Apple's `NSDiffableDataSourceSnapshot` is backed by Objective-C runtime overhead and per-query hashing.

### vs IGListKit (Instagram)

Both libraries implement Paul Heckel's O(n) diff. IGListKit's is Objective-C++; ListKit's is pure Swift. Both sides pre-build their data structures before the timed block so only the diff algorithm is measured — `ListDiff()` for IGListKit, `SectionedDiff.diff()` for ListKit. IGListKit diffs a single flat array; ListKit diffs sections first, then items per-section, and reconciles cross-section moves.

| Operation | IGListKit | ListKit | Notes |
|:---|---:|---:|:---|
| Diff 10k (50% overlap) | 12.6 ms | 11.8 ms | ListKit wins at common scale |
| Diff 50k (50% overlap) | 55.7 ms | 67.7 ms | IGListKit's flat C++ pass is faster at scale |
| Diff no-change 10k | 9.4 ms | 0.08 ms | **116x** — per-section skip makes this free |
| Diff shuffle 10k | 10.3 ms | 3.3 ms | **3.1x** ListKit wins all-moves case |

Per-section diffing skips unchanged sections entirely — the common case for incremental UI updates. At 50k with 50% overlap, IGListKit's single-pass Obj-C++ is faster, but ListKit provides sectioned structure, `Sendable` safety, and full `UICollectionViewDiffableDataSource` compatibility that IGListKit doesn't.

### vs ReactiveCollectionsKit

ReactiveCollectionsKit wraps Apple's `NSDiffableDataSourceSnapshot` with type-erased `CollectionViewModel` layers. These benchmarks compare model construction (building the data structures each library needs before applying to a collection view).

| Operation | ListKit | ReactiveCollectionsKit | Apple | Speedup vs RC |
|:---|---:|---:|---:|---:|
| Build 10k items | 0.006 ms | 7.9 ms | 1.3 ms | **1,311x** |
| Build 50k items | 0.033 ms | 36.7 ms | — | **1,113x** |
| Build 100 sections x 100 | 0.058 ms | 7.8 ms | 4.7 ms | **134x** |

Type erasure alone (`eraseToAnyViewModel()`) costs 7.3 ms for 10k cells — more than ListKit's entire snapshot build at the same scale.

Run benchmarks with:

```
make benchmark
```

## Development

### Setup

```bash
make setup    # install Tuist, fetch dependencies, generate project, install hooks
```

### Common Commands

```bash
make build       # build ListKit + Lists frameworks
make test        # run all tests (ListKit + Lists)
make benchmark   # run performance benchmarks
make format      # format code with SwiftFormat
make lint        # lint with SwiftFormat
make open        # open in Xcode
```

### Project Structure

```
Sources/
  ListKit/          # Low-level diffing + data source
    Algorithm/      # HeckelDiff, SectionedDiff, StagedChangeset
    DataSource/     # CollectionViewDiffableDataSource
    Snapshot/       # DiffableDataSourceSnapshot, SectionSnapshot
  Lists/            # High-level declarative API
    Protocols/      # CellViewModel, SectionModel
    DataSource/     # ListDataSource, MixedListDataSource
    Builder/        # SnapshotBuilder, ItemsBuilder, MixedSnapshotBuilder, DSL extensions
    Mixed/          # AnyItem, DynamicCellRegistrar
    Configurations/ # SimpleList, GroupedList, OutlineList
    Extensions/     # LayoutHelpers, CellViewModel+Identifiable
Tests/
  ListKitTests/     # Diff, snapshot, data source
  ListsTests/       # Builder, configurations, view models
  Benchmarks/       # Apple, IGListKit, ReactiveCollectionsKit
Example/            # Demo app
```

## License

MIT
