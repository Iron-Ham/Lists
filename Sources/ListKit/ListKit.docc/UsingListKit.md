# Using ListKit Directly

Build custom collection view data sources with full control over diffing and batch updates.

## Overview

ListKit provides the low-level primitives that the higher-level Lists framework is built on.
Use ListKit directly when you need custom data source behavior, want to integrate with
your own abstraction layer, or need access to the raw diff engine.

Most apps should use the ``Lists`` module instead — it handles cell registration,
layout, and delegation automatically. Reach for ListKit when you need something
that Lists doesn't cover.

## Create a Data Source

``CollectionViewDiffableDataSource`` requires a collection view and a cell provider
closure. You are responsible for cell registration and dequeuing:

```swift
let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, String> {
    cell, indexPath, item in
    var content = cell.defaultContentConfiguration()
    content.text = item
    cell.contentConfiguration = content
}

let dataSource = CollectionViewDiffableDataSource<Int, String>(
    collectionView: collectionView
) { collectionView, indexPath, item in
    collectionView.dequeueConfiguredReusableCell(
        using: cellRegistration, for: indexPath, item: item
    )
}
```

> Important: Unlike Apple's `UICollectionViewDiffableDataSource`, ListKit's data source
> does **not** use `NSDiffableDataSourceSnapshot` under the hood. It uses its own
> ``DiffableDataSourceSnapshot`` type with different performance characteristics.

## Build and Apply Snapshots

Snapshots are value types. Build one, populate it, then apply it to the data source:

```swift
var snapshot = DiffableDataSourceSnapshot<Int, String>()
snapshot.appendSections([0])
snapshot.appendItems(["Alice", "Bob", "Charlie"], toSection: 0)

await dataSource.apply(snapshot, animatingDifferences: true)
```

When you apply a new snapshot, the data source computes the minimal diff and
applies animated batch updates. Subsequent calls to `apply` are serialized
automatically — concurrent calls are queued and executed in order.

## Multi-Section Snapshots

```swift
var snapshot = DiffableDataSourceSnapshot<String, Item>()
snapshot.appendSections(["favorites", "recents"])
snapshot.appendItems(favoriteItems, toSection: "favorites")
snapshot.appendItems(recentItems, toSection: "recents")

await dataSource.apply(snapshot)
```

## Reload vs. Reconfigure

When item content changes but identity stays the same, you can mark items for
reload or reconfiguration:

```swift
var snapshot = dataSource.snapshot()
// Reload: dequeues a new cell
snapshot.reloadItems([updatedItem])
// Reconfigure: updates the existing cell in place (cheaper)
snapshot.reconfigureItems([anotherItem])
await dataSource.apply(snapshot)
```

> Tip: Prefer `reconfigureItems` when only cell content has changed. It avoids
> the cost of dequeuing and is visually smoother.

## Hierarchical Data with Section Snapshots

Use ``DiffableDataSourceSectionSnapshot`` for parent–child relationships within
a single section:

```swift
var sectionSnapshot = DiffableDataSourceSectionSnapshot<Item>()
sectionSnapshot.append([folder])
sectionSnapshot.append([file1, file2], to: folder)
sectionSnapshot.expand([folder])

await dataSource.apply(sectionSnapshot, to: sectionID)
```

## Limitations

- **iOS only**: ListKit requires iOS 17+ and UIKit. It does not support macOS,
  tvOS, or watchOS.
- **No supplementary view management**: You must configure supplementary views
  (headers, footers) via the `supplementaryViewProvider` closure manually.
- **No cell registration**: Unlike the Lists module, ListKit does not handle
  cell registration — you must register cells yourself.
- **Item uniqueness**: Each item must be unique across the entire snapshot.
  Duplicate items will trigger an assertion in debug builds and produce
  undefined behavior in release builds.

## Topics

### Data Source

- ``CollectionViewDiffableDataSource``

### Snapshots

- ``DiffableDataSourceSnapshot``
- ``DiffableDataSourceSectionSnapshot``
