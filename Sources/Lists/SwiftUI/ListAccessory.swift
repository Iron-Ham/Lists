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

    /// Escape hatch for parameterized accessories (e.g., `UICellAccessory.detail(actionHandler:)`).
    /// The `key` is used for equality — two `.custom` values are equal when their keys match.
    case custom(UICellAccessory, key: AnyHashable)

    public static func == (lhs: ListAccessory, rhs: ListAccessory) -> Bool {
        switch (lhs, rhs) {
        case (.disclosureIndicator, .disclosureIndicator),
             (.checkmark, .checkmark),
             (.delete, .delete),
             (.reorder, .reorder),
             (.outlineDisclosure, .outlineDisclosure),
             (.detail, .detail):
            true
        case let (.custom(_, lhsKey), .custom(_, rhsKey)):
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
        case let .custom(_, key): hasher.combine(6); hasher.combine(key)
        }
    }

    /// Converts to the UIKit `UICellAccessory` equivalent.
    public var uiAccessory: UICellAccessory {
        switch self {
        case .disclosureIndicator: .disclosureIndicator()
        case .checkmark: .checkmark()
        case .delete: .delete()
        case .reorder: .reorder()
        case .outlineDisclosure: .outlineDisclosure()
        case .detail: .detail()
        case let .custom(accessory, _): accessory
        }
    }
}
