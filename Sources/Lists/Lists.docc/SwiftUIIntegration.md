# SwiftUI Integration

Use ListKit-powered collection views in SwiftUI with zero boilerplate.

## Overview

Lists provides `UIViewRepresentable` wrappers — ``SimpleListView``,
``GroupedListView``, and ``OutlineListView`` — that expose the full feature
set (swipe actions, context menus, pull-to-refresh) as SwiftUI views.

Each wrapper also offers an **inline content** initializer that accepts a
`@ViewBuilder` closure, so you can skip defining a ``CellViewModel`` entirely:

```swift
SimpleListView(items: contacts) { contact in
    Text(contact.name)
}
```

## Inline Content

The inline API wraps your `@ViewBuilder` in an ``InlineCellViewModel`` behind
the scenes. It's the fastest path from data to screen when you don't need
custom cell classes.

```swift
SimpleListView(
    items: contacts,
    accessories: [.disclosureIndicator],
    onSelect: { contact in print(contact.name) }
) { contact in
    HStack {
        Image(systemName: "person.circle")
        Text(contact.name)
    }
}
```

## SwiftUICellViewModel

When you need reusable cell types but want to define their content in SwiftUI,
conform to ``SwiftUICellViewModel``:

```swift
struct ContactRow: SwiftUICellViewModel, Identifiable {
    let id: String
    let name: String

    var body: some View {
        Label(name, systemImage: "person.circle")
    }

    var accessories: [ListAccessory] {
        [.disclosureIndicator]
    }
}
```

## Swipe Actions

All three SwiftUI wrappers support leading and trailing swipe actions:

```swift
SimpleListView(
    items: contacts,
    trailingSwipeActionsProvider: { contact in
        UISwipeActionsConfiguration(actions: [
            UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
                deleteContact(contact)
                completion(true)
            }
        ])
    }
) { contact in
    Text(contact.name)
}
```

## Pull-to-Refresh

Pass an `onRefresh` closure to enable pull-to-refresh:

```swift
SimpleListView(
    items: contacts,
    onRefresh: {
        await fetchLatestContacts()
    }
) { contact in
    Text(contact.name)
}
```

## Topics

### SwiftUI Views

- ``SimpleListView``
- ``GroupedListView``
- ``OutlineListView``

### Cell Protocols

- ``SwiftUICellViewModel``
- ``InlineCellViewModel``

### Accessories

- ``ListAccessory``
