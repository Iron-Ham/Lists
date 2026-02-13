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
    .package(url: "https://github.com/Iron-Ham/ListKit", from: "0.1.0"),
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
┌─────────────────────────────────────────────────────┐
│  Lists                                              │
│  ┌──────────────┐  ┌───────────┐  ┌──────────────┐  │
│  │ SimpleList   │  │ GroupedList│ │ OutlineList  │  │
│  └──────┬───────┘  └─────┬─────┘  └──────┬───────┘  │
│         └────────┬───────┘               │          │
│           ┌──────▼──────┐                │          │
│           │ListDataSource│───────────────┘          │
│           └──────┬──────┘                           │
│   ┌──────────────┼──────────────────┐               │
│   │SnapshotBuilder│  CellViewModel  │               │
│   └──────────────┴──────────────────┘               │
├─────────────────────────────────────────────────────┤
│  ListKit                                            │
│  ┌─────────────────────────────────────┐            │
│  │ CollectionViewDiffableDataSource    │            │
│  └──────────────┬──────────────────────┘            │
│  ┌──────────────▼──────────────────────┐            │
│  │ DiffableDataSourceSnapshot          │            │
│  │ DiffableDataSourceSectionSnapshot   │            │
│  └──────────────┬──────────────────────┘            │
│  ┌──────────────▼──────────────────────┐            │
│  │ HeckelDiff (O(n))                   │            │
│  │ SectionedDiff                       │            │
│  └─────────────────────────────────────┘            │
└─────────────────────────────────────────────────────┘
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

### Swift 6 Strict Concurrency

All types are `Sendable`. The data source is `@MainActor`. Snapshots are value types that can be built on any thread and applied on main.

## Current Limitations

**Mixed cell types in Lists.** `ListDataSource` is generic over a single `Item: CellViewModel`, so every item shares one `Cell` associated type. This means you can't mix heterogeneous cell types (e.g. a horizontal carousel section alongside vertical list rows) through the Lists layer. Workaround: use `CollectionViewDiffableDataSource` (ListKit) directly — its `CellProvider` closure can return any cell type per index path, just like Apple's API.

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

Both libraries implement Paul Heckel's O(n) diff. IGListKit's is Objective-C++; ListKit's is pure Swift. Both sides perform equivalent work: diff two collections with 50% overlap. ListKit's numbers include the full pipeline (build two snapshots + `SectionedDiff.diff`).

| Operation | IGListKit | ListKit | Notes |
|:---|---:|---:|:---|
| Diff 10k (50% overlap) | 11.6 ms | 11.9 ms | Near-parity at common scale |
| Diff 50k (50% overlap) | 64.0 ms | 70.9 ms | IGListKit's C++ is faster for raw diffing |
| Diff no-change 10k | 10.6 ms | 0.1 ms | **91x** — per-section skip makes this free |
| Diff shuffle 10k | 11.6 ms | 3.4 ms | **3.4x** ListKit wins all-moves case |

Per-section diffing skips unchanged sections entirely — the common case for incremental UI updates. For heavy churn (50% overlap), IGListKit's Obj-C++ wins on raw throughput, but ListKit provides sectioned structure, `Sendable` safety, and full `UICollectionViewDiffableDataSource` compatibility that IGListKit doesn't.

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
    DataSource/     # ListDataSource
    Builder/        # SnapshotBuilder, ItemsBuilder, DSL extensions
    Configurations/ # SimpleList, GroupedList, OutlineList
    Extensions/     # LayoutHelpers, CellViewModel+Identifiable
Tests/
  ListKitTests/     # 91 tests — diff, snapshot, data source
  ListsTests/       # 43 tests — builder, configurations, view models
  Benchmarks/       # 18 benchmarks — Apple, IGListKit, ReactiveCollectionsKit
Example/            # 5-tab demo app
```

## License

MIT
