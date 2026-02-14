# Getting Started with Lists

Build collection view lists in minutes using type-safe cell view models and declarative snapshots.

## Overview

Lists provides a layered API for building `UICollectionView`-backed lists.
At the lowest level you define **cell view models** — small value types that
describe how a cell should look. At the highest level you use pre-built
configurations like ``SimpleList`` or ``GroupedList`` that handle layout,
data sources, and delegation for you.

## Define a Cell View Model

A ``CellViewModel`` pairs a data model with a cell class and a `configure` method:

```swift
struct ContactItem: CellViewModel, Identifiable {
    let id: String
    let name: String

    func configure(_ cell: UICollectionViewListCell) {
        var content = cell.defaultContentConfiguration()
        content.text = name
        cell.contentConfiguration = content
    }
}
```

> Tip: Conform to `Identifiable` to get automatic `Hashable` / `Equatable`
> based on `id`, which is what the diff algorithm uses to track identity.

## Display a Flat List

Use ``SimpleList`` for a single-section list with no headers:

```swift
let list = SimpleList<ContactItem>()
view.addSubview(list.collectionView)

list.onSelect = { contact in
    print("Selected \(contact.name)")
}

await list.setItems([
    ContactItem(id: "1", name: "Alice"),
    ContactItem(id: "2", name: "Bob"),
])
```

## Use the Snapshot DSL

Build multi-section snapshots with the result builder DSL:

```swift
let dataSource = ListDataSource<String, ContactItem>(collectionView: collectionView)

await dataSource.apply {
    SnapshotSection("favorites") {
        ContactItem(id: "1", name: "Alice")
    }
    SnapshotSection("recents") {
        ContactItem(id: "2", name: "Bob")
        ContactItem(id: "3", name: "Charlie")
    }
}
```

## Display a Grouped List

Use ``GroupedList`` for sectioned lists with headers and footers:

```swift
let list = GroupedList<String, ContactItem>()

await list.setSections([
    SectionModel(id: "friends", items: friends, header: "Friends"),
    SectionModel(id: "family", items: family, header: "Family"),
])
```

## Topics

### Essential Types

- ``CellViewModel``
- ``SimpleList``
- ``ListDataSource``
- ``SnapshotBuilder``
