# Building Lists in SwiftUI

Use SimpleListView, GroupedListView, and OutlineListView to embed UICollectionView lists in SwiftUI.

## Overview

The Lists module provides SwiftUI wrappers for each of the UIKit list configurations.
These are `UIViewRepresentable` views that bridge the full feature set — including
swipe actions, context menus, and pull-to-refresh — into SwiftUI.

> Important: These wrappers use UIKit's `UICollectionView` under the hood, not
> SwiftUI's native `List`. This gives you access to UIKit-specific features
> (custom cell registrations, compositional layout) but means the views don't
> participate in SwiftUI's native list styling or environment modifiers like
> `.listStyle()`.

## Inline Content: The Fastest Path

All three wrappers provide a convenience initializer that accepts a `@ViewBuilder`
closure, letting you skip defining a ``CellViewModel`` entirely:

```swift
struct ContactsView: View {
    let contacts: [Contact]

    var body: some View {
        SimpleListView(items: contacts) { contact in
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text(contact.name)
                    Text(contact.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
```

The inline initializer wraps your `@ViewBuilder` in an ``InlineCellViewModel``
that renders content via `UIHostingConfiguration`.

### Adding Accessories

Use the `accessories` parameter to add cell accessories like disclosure indicators:

```swift
SimpleListView(
    items: contacts,
    accessories: [.disclosureIndicator]
) { contact in
    Text(contact.name)
}
```

Available accessories include `.disclosureIndicator`, `.checkmark`, `.delete`,
`.reorder`, `.outlineDisclosure`, `.detail`, and a `.custom()` escape hatch
for any `UICellAccessory`.

## CellViewModel-Based Content

For reusable cell types, define a ``CellViewModel`` and pass instances directly:

```swift
struct ContactRow: CellViewModel, Identifiable {
    typealias Cell = UICollectionViewListCell
    let id: String
    let name: String

    func configure(_ cell: UICollectionViewListCell) {
        var content = cell.defaultContentConfiguration()
        content.text = name
        cell.contentConfiguration = content
    }
}

// Usage
SimpleListView(items: contactRows)
```

## SwiftUICellViewModel

When you want reusable cell types with SwiftUI-defined content, conform to
``SwiftUICellViewModel``:

```swift
struct ContactRow: SwiftUICellViewModel, Identifiable {
    let id: String
    let name: String
    let isFavorite: Bool

    var body: some View {
        Label {
            Text(name)
        } icon: {
            Image(systemName: isFavorite ? "star.fill" : "person.circle")
                .foregroundStyle(isFavorite ? .yellow : .blue)
        }
    }

    var accessories: [ListAccessory] {
        [.disclosureIndicator]
    }
}
```

> Note: Do **not** override `configure(_:)` when using `SwiftUICellViewModel`.
> The default implementation renders `body` and `accessories` via
> `UIHostingConfiguration`. Overriding it will silently ignore both properties.

## Grouped Lists

``GroupedListView`` displays sectioned data with headers and footers:

```swift
struct SettingsView: View {
    var body: some View {
        GroupedListView(
            sections: [
                SectionModel(id: "general", items: generalSettings, header: "General"),
                SectionModel(id: "privacy", items: privacySettings, header: "Privacy"),
            ]
        )
    }
}
```

With inline content:

```swift
GroupedListView(
    sections: [
        SectionModel(id: "general", items: generalItems, header: "General"),
        SectionModel(id: "privacy", items: privacyItems, header: "Privacy"),
    ],
    accessories: [.disclosureIndicator],
    onSelect: { item in navigate(to: item) }
) { item in
    Label(item.title, systemImage: item.icon)
}
```

## Outline Lists

``OutlineListView`` displays hierarchical data with expand/collapse:

```swift
OutlineListView(
    items: [
        OutlineItem(item: "Documents", children: [
            OutlineItem(item: "README.md"),
            OutlineItem(item: "CHANGELOG.md"),
        ], isExpanded: true),
        OutlineItem(item: "Sources", children: [
            OutlineItem(item: "main.swift"),
        ]),
    ]
) { item in
    Label(item, systemImage: "doc")
}
```

## Selection

All wrappers accept an `onSelect` closure:

```swift
SimpleListView(
    items: contacts,
    onSelect: { contact in
        selectedContact = contact
    }
) { contact in
    Text(contact.name)
}
```

## Swipe Actions

Leading and trailing swipe actions are configured via UIKit closures that return
`UISwipeActionsConfiguration`:

```swift
SimpleListView(
    items: contacts,
    trailingSwipeActionsProvider: { contact in
        UISwipeActionsConfiguration(actions: [
            UIContextualAction(style: .destructive, title: "Delete") { _, _, done in
                deleteContact(contact)
                done(true)
            }
        ])
    },
    leadingSwipeActionsProvider: { contact in
        UISwipeActionsConfiguration(actions: [
            UIContextualAction(style: .normal, title: "Pin") { _, _, done in
                pinContact(contact)
                done(true)
            }
        ])
    }
) { contact in
    Text(contact.name)
}
```

> Note: Swipe actions use UIKit's `UISwipeActionsConfiguration` and
> `UIContextualAction`, not SwiftUI's `.swipeActions()` modifier. This is
> because the underlying view is a `UICollectionView`.

## Context Menus

Context menus use UIKit's `UIContextMenuConfiguration`:

```swift
SimpleListView(
    items: contacts,
    contextMenuProvider: { contact in
        UIContextMenuConfiguration(actionProvider: { _ in
            UIMenu(children: [
                UIAction(title: "Share") { _ in share(contact) },
                UIAction(title: "Delete", attributes: .destructive) { _ in
                    delete(contact)
                },
            ])
        })
    }
) { contact in
    Text(contact.name)
}
```

## Pull-to-Refresh

Pass an async `onRefresh` closure to enable pull-to-refresh. The refresh
control is automatically dismissed when the closure returns:

```swift
SimpleListView(
    items: contacts,
    onRefresh: {
        contacts = await api.fetchContacts()
    }
) { contact in
    Text(contact.name)
}
```

## Limitations

- **UIKit-based**: The SwiftUI wrappers use `UIViewRepresentable` around
  `UICollectionView`. SwiftUI environment modifiers like `.listStyle()`,
  `.listRowBackground()`, and `.listRowSeparator()` have **no effect**.
- **UIKit action types**: Swipe actions, context menus, and accessories all use
  UIKit types (`UISwipeActionsConfiguration`, `UIContextMenuConfiguration`,
  `UICellAccessory`) rather than SwiftUI equivalents.
- **Text-only headers/footers**: ``GroupedListView`` renders headers and footers
  as plain strings. Custom supplementary views require dropping down to
  ``ListDataSource`` in UIKit.
- **No `@Environment` propagation into cells**: When using ``CellViewModel`` types,
  the cell is configured via `configure(_:)` which runs in a UIKit context.
  SwiftUI environment values are not automatically available. Use
  ``SwiftUICellViewModel`` or the inline API for SwiftUI environment access.
- **Equatable data required**: The inline content initializer requires your data
  type to conform to `Hashable & Sendable`. The `@ViewBuilder` closure itself
  is **not** compared — only `data` and `accessories` drive diffing.
- **iOS 17+ only**: All SwiftUI wrappers require iOS 17+.

## Topics

### SwiftUI Views

- ``SimpleListView``
- ``GroupedListView``
- ``OutlineListView``

### Cell Protocols

- ``SwiftUICellViewModel``
- ``InlineCellViewModel``
- ``CellViewModel``

### Accessories

- ``ListAccessory``
