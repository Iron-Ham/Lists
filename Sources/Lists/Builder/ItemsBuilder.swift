/// A result builder for constructing arrays of a single ``CellViewModel`` type.
///
/// Used by ``SimpleList/setItems(animatingDifferences:content:)`` and
/// ``SnapshotSection/init(_:items:)-6gwjp`` to enable declarative item lists.
@resultBuilder
public struct ItemsBuilder<Item: CellViewModel> {
  public static func buildBlock(_ components: [Item]...) -> [Item] {
    components.flatMap(\.self)
  }

  public static func buildExpression(_ item: Item) -> [Item] {
    [item]
  }

  public static func buildExpression(_ items: [Item]) -> [Item] {
    items
  }

  public static func buildOptional(_ component: [Item]?) -> [Item] {
    component ?? []
  }

  public static func buildEither(first component: [Item]) -> [Item] {
    component
  }

  public static func buildEither(second component: [Item]) -> [Item] {
    component
  }

  public static func buildArray(_ components: [[Item]]) -> [Item] {
    components.flatMap(\.self)
  }
}
