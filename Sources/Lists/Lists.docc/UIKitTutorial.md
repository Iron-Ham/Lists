# Building Lists in UIKit

Use SimpleList, GroupedList, and OutlineList to build collection view lists with minimal boilerplate.

## Overview

The Lists module provides three pre-built configurations that handle layout, data sources,
and delegation automatically. Choose the one that fits your use case:

| Type | Sections | Headers/Footers | Hierarchy |
|------|----------|-----------------|-----------|
| ``SimpleList`` | Single | No | No |
| ``GroupedList`` | Multiple | Yes | No |
| ``OutlineList`` | Single | No | Yes (tree) |

All three follow the same pattern: create the list, add its `collectionView` to your
view hierarchy, set callback closures, and call an async method to provide data.

## SimpleList: Flat Lists

``SimpleList`` is the simplest configuration — a single-section list with no headers:

```swift
class ContactsViewController: UIViewController {
    private let list = SimpleList<ContactItem>()

    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. Add to view hierarchy
        view.addSubview(list.collectionView)
        list.collectionView.frame = view.bounds
        list.collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // 2. Handle selection
        list.onSelect = { contact in
            print("Selected \(contact.name)")
        }

        // 3. Provide data
        Task {
            await list.setItems(contacts)
        }
    }
}
```

You can also use the result builder syntax:

```swift
await list.setItems {
    ContactItem(id: "1", name: "Alice")
    ContactItem(id: "2", name: "Bob")
}
```

## GroupedList: Sectioned Lists

``GroupedList`` displays multiple sections with header and footer text:

```swift
let list = GroupedList<String, ContactItem>()

list.onSelect = { contact in
    print("Selected \(contact.name)")
}

await list.setSections([
    SectionModel(
        id: "favorites",
        items: favoriteContacts,
        header: "Favorites",
        footer: "\(favoriteContacts.count) contacts"
    ),
    SectionModel(
        id: "all",
        items: allContacts,
        header: "All Contacts"
    ),
])
```

> Note: Headers and footers are plain text strings rendered using the system's
> grouped header/footer content configuration. For custom supplementary views,
> use ``ListDataSource`` directly with a custom `supplementaryViewProvider`.

## OutlineList: Hierarchical Lists

``OutlineList`` displays expandable/collapsible trees using ``OutlineItem``:

```swift
let list = OutlineList<FileItem>(appearance: .sidebar)

await list.setItems([
    OutlineItem(item: documentsFolder, children: [
        OutlineItem(item: readme),
        OutlineItem(item: changelog),
    ], isExpanded: true),
    OutlineItem(item: srcFolder, children: [
        OutlineItem(item: mainFile),
    ]),
])
```

Each ``OutlineItem`` wraps a value, has optional children, and an `isExpanded` flag
that controls the initial expansion state.

## Adding Swipe Actions

All three configurations support leading and trailing swipe actions:

```swift
list.trailingSwipeActionsProvider = { item in
    UISwipeActionsConfiguration(actions: [
        UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
            deleteItem(item)
            completion(true)
        }
    ])
}

list.leadingSwipeActionsProvider = { item in
    UISwipeActionsConfiguration(actions: [
        UIContextualAction(style: .normal, title: "Pin") { _, _, completion in
            pinItem(item)
            completion(true)
        }
    ])
}
```

## Adding Context Menus

Long-press context menus are supported on all three configurations:

```swift
list.contextMenuProvider = { item in
    UIContextMenuConfiguration(actionProvider: { _ in
        UIMenu(children: [
            UIAction(title: "Share") { _ in share(item) },
            UIAction(title: "Delete", attributes: .destructive) { _ in delete(item) },
        ])
    })
}
```

## Custom Data Sources

When the pre-built configurations don't fit your needs, use ``ListDataSource``
(for a single cell type) or ``MixedListDataSource`` (for multiple cell types)
directly:

```swift
let layout = ListLayout.insetGrouped(headerMode: .supplementary)
let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

let dataSource = ListDataSource<String, ContactItem>(collectionView: collectionView)

await dataSource.apply {
    SnapshotSection("favorites") {
        ContactItem(id: "1", name: "Alice")
    }
    SnapshotSection("recents") {
        ContactItem(id: "2", name: "Bob")
    }
}
```

## Defining Cell View Models

A ``CellViewModel`` is a `Hashable & Sendable` value type that knows how to
configure a specific cell class:

```swift
struct ContactItem: CellViewModel, Identifiable {
    typealias Cell = UICollectionViewListCell

    let id: String
    let name: String
    let subtitle: String

    func configure(_ cell: UICollectionViewListCell) {
        var content = cell.defaultContentConfiguration()
        content.text = name
        content.secondaryText = subtitle
        cell.contentConfiguration = content
        cell.accessories = [.disclosureIndicator()]
    }
}
```

> Tip: Conforming to `Identifiable` gives you automatic `Hashable`/`Equatable`
> based on `id`. This means the diff algorithm tracks items by `id` — if you
> change `name` or `subtitle` but keep the same `id`, you need to call
> `snapshot.reconfigureItems([item])` to update the cell.

## Limitations

- **iOS 17+ only**: All list configurations require iOS 17+.
- **UICollectionView only**: Lists are backed by `UICollectionView` with
  `UICollectionViewCompositionalLayout`. `UITableView` is not supported.
- **Text-only headers/footers**: ``GroupedList`` supports string-based headers
  and footers only. For custom supplementary views, use ``ListDataSource`` with
  a custom `supplementaryViewProvider`.
- **Single cell type per data source**: ``ListDataSource`` supports one
  ``CellViewModel`` type. Use ``MixedListDataSource`` with ``AnyItem`` for
  heterogeneous cells.
- **Serialized applies**: Concurrent calls to `setItems` or `setSections` are
  queued internally. Rapid successive calls may cause visual flickering if the
  data changes faster than animations complete.

## Topics

### Pre-Built Configurations

- ``SimpleList``
- ``GroupedList``
- ``OutlineList``

### Data Sources

- ``ListDataSource``
- ``MixedListDataSource``

### Supporting Types

- ``CellViewModel``
- ``SectionModel``
- ``OutlineItem``
- ``AnyItem``
