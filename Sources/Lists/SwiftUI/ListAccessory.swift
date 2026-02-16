import UIKit

/// A pure-Swift cell accessory type that replaces `UICellAccessory` in SwiftUI cell view models.
///
/// Use this instead of importing UIKit's `UICellAccessory` directly. The `.custom()` case
/// provides an escape hatch for advanced accessories not covered by the convenience cases.
///
/// - Note: This type is `@unchecked Sendable` because the `.custom` case holds a
///   `UICellAccessory`, which is not `Sendable`. All `ListAccessory` values must be
///   created and accessed on `@MainActor`.
public enum ListAccessory: @unchecked Sendable, Hashable {
  case disclosureIndicator
  case checkmark
  case delete
  case reorder
  case outlineDisclosure
  case detail

  /// A multi-select checkmark accessory shown during editing mode.
  case multiselect

  /// A text label displayed on the trailing side of the cell (e.g., a count badge).
  /// An empty string produces a visible but blank accessory label.
  case label(text: String)

  /// A pop-up menu button attached to the cell.
  ///
  /// The `key` is used for equality — two `.popUpMenu` values are equal when their keys match.
  /// Use ``popUpMenu(_:)`` for a convenience initializer with a default key.
  ///
  /// - Note: `UIMenu` is not `Sendable`. Like the `.custom` case, `.popUpMenu` values
  ///   must be created and accessed on `@MainActor`.
  case popUpMenu(UIMenu, key: AnyHashable)

  /// Escape hatch for parameterized accessories (e.g., `UICellAccessory.detail(actionHandler:)`).
  /// The `key` is used for equality — two `.custom` values are equal when their keys match.
  case custom(UICellAccessory, key: AnyHashable)

  // MARK: Public

  /// Converts to the UIKit `UICellAccessory` equivalent.
  public var uiAccessory: UICellAccessory {
    switch self {
    case .disclosureIndicator: .disclosureIndicator()
    case .checkmark: .checkmark()
    case .delete: .delete()
    case .reorder: .reorder()
    case .outlineDisclosure: .outlineDisclosure()
    case .detail: .detail()
    case .multiselect: .multiselect()
    case .label(let text): .label(text: text)
    case .popUpMenu(let menu, key: _): .popUpMenu(menu)
    case .custom(let accessory, _): accessory
    }
  }

  /// Creates a pop-up menu button with a default key.
  ///
  /// All `popUpMenu` accessories created this way are considered equal for diffing purposes.
  /// If menu changes should trigger cell reconfiguration, use the case initializer directly
  /// with a unique key: `.popUpMenu(menu, key: "uniqueID")`.
  public static func popUpMenu(_ menu: UIMenu) -> ListAccessory {
    .popUpMenu(menu, key: AnyHashable("popUpMenu"))
  }

  /// Creates a detail (info) button with an action handler.
  ///
  /// Use this when the detail button should trigger an action on tap. For a purely
  /// decorative info button, use the ``detail`` case instead.
  public static func detail(
    actionHandler: @escaping () -> Void,
    key: AnyHashable = AnyHashable("detail-action")
  ) -> ListAccessory {
    .custom(UICellAccessory.detail(actionHandler: actionHandler), key: key)
  }

  public static func ==(lhs: ListAccessory, rhs: ListAccessory) -> Bool {
    switch (lhs, rhs) {
    case (.disclosureIndicator, .disclosureIndicator),
         (.checkmark, .checkmark),
         (.delete, .delete),
         (.reorder, .reorder),
         (.outlineDisclosure, .outlineDisclosure),
         (.detail, .detail),
         (.multiselect, .multiselect):
      true
    case (.label(let lhsText), .label(let rhsText)):
      lhsText == rhsText
    case (.popUpMenu(_, key: let lhsKey), .popUpMenu(_, key: let rhsKey)):
      lhsKey == rhsKey
    case (.custom(_, let lhsKey), .custom(_, let rhsKey)):
      lhsKey == rhsKey
    default:
      false
    }
  }

  public func hash(into hasher: inout Hasher) {
    switch self {
    case .disclosureIndicator: hasher.combine(0)

    case .checkmark: hasher.combine(1)

    case .delete: hasher.combine(2)

    case .reorder: hasher.combine(3)

    case .outlineDisclosure: hasher.combine(4)

    case .detail: hasher.combine(5)

    case .multiselect: hasher.combine(6)

    case .label(let text):
      hasher.combine(7)
      hasher.combine(text)

    case .popUpMenu(_, key: let key):
      hasher.combine(8)
      hasher.combine(key)

    case .custom(_, let key):
      hasher.combine(9)
      hasher.combine(key)
    }
  }

}
