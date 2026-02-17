// ABOUTME: @resultBuilder for hierarchical OutlineItem trees.
// ABOUTME: Also extends OutlineItem with a builder-based children initializer.
// MARK: - OutlineItemBuilder

/// A result builder for constructing arrays of ``OutlineItem`` declaratively.
///
/// Use this builder to define outline hierarchies with visual nesting that
/// mirrors the data structure:
///
/// ```swift
/// await list.setItems {
///     OutlineItem(item: "Documents", isExpanded: true) {
///         OutlineItem(item: "Projects") {
///             OutlineItem(item: "ListKit")
///         }
///         OutlineItem(item: "Notes")
///     }
///     OutlineItem(item: "Downloads")
/// }
/// ```
@resultBuilder
public struct OutlineItemBuilder<Item: Hashable & Sendable> {
  public static func buildBlock(_ components: [OutlineItem<Item>]...) -> [OutlineItem<Item>] {
    components.flatMap(\.self)
  }

  public static func buildExpression(_ item: OutlineItem<Item>) -> [OutlineItem<Item>] {
    [item]
  }

  public static func buildExpression(_ items: [OutlineItem<Item>]) -> [OutlineItem<Item>] {
    items
  }

  public static func buildOptional(_ component: [OutlineItem<Item>]?) -> [OutlineItem<Item>] {
    component ?? []
  }

  public static func buildEither(first component: [OutlineItem<Item>]) -> [OutlineItem<Item>] {
    component
  }

  public static func buildEither(second component: [OutlineItem<Item>]) -> [OutlineItem<Item>] {
    component
  }

  public static func buildArray(_ components: [[OutlineItem<Item>]]) -> [OutlineItem<Item>] {
    components.flatMap(\.self)
  }

  public static func buildLimitedAvailability(_ component: [OutlineItem<Item>]) -> [OutlineItem<Item>] {
    component
  }
}

extension OutlineItem {
  /// Creates an outline item with children defined using the ``OutlineItemBuilder`` result builder.
  ///
  /// ```swift
  /// OutlineItem(item: folder, isExpanded: true) {
  ///     OutlineItem(item: fileA)
  ///     OutlineItem(item: fileB)
  ///     if showHidden {
  ///         OutlineItem(item: hiddenFile)
  ///     }
  /// }
  /// ```
  public init(
    item: Item,
    isExpanded: Bool = false,
    @OutlineItemBuilder<Item> children: () -> [OutlineItem<Item>]
  ) {
    self.init(item: item, children: children(), isExpanded: isExpanded)
  }
}
