# ``Lists``

A declarative, type-safe framework for building collection view lists in UIKit and SwiftUI.

## Overview

Lists builds on top of ListKit to provide a batteries-included API for common list patterns: flat lists, grouped/sectioned lists, and hierarchical outline lists. It supports both UIKit and SwiftUI, with result builder DSLs for snapshot construction.

## Topics

### Essentials

- <doc:QuickStart>
- <doc:UIKitTutorial>
- <doc:SwiftUITutorial>
- <doc:SwiftUIIntegration>

### Core Protocols

- ``CellViewModel``
- ``SectionModel``

### Data Sources

- ``ListDataSource``
- ``MixedListDataSource``

### Pre-Built Configurations

- ``SimpleList``
- ``GroupedList``
- ``OutlineList``
- ``OutlineItem``

### SwiftUI Wrappers

- ``SimpleListView``
- ``GroupedListView``
- ``OutlineListView``
- ``SwiftUICellViewModel``
- ``InlineCellViewModel``
- ``ListAccessory``

### Result Builders

- ``ItemsBuilder``
- ``SnapshotBuilder``
- ``SnapshotSection``
- ``MixedSnapshotBuilder``
- ``MixedItemsBuilder``
- ``MixedSection``

### Type-Erased Cells

- ``AnyItem``

### Layout Helpers

- ``ListLayout``
