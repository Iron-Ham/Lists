// ABOUTME: Pure-Swift enum mapping to UICellAccessory for use in cell view models.
// ABOUTME: Includes standard, custom, toggle, badge, and other accessory types.
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

  /// An inline toggle switch for settings-style cells.
  ///
  /// The `key` is used for equality alongside `isOn` — the `onChange` closure is ignored for diffing.
  /// Use ``toggle(isOn:key:onChange:)`` for a convenience initializer with a default key.
  case toggle(isOn: Bool, onChange: @MainActor (Bool) -> Void, key: AnyHashable)

  /// A pill-shaped badge displaying a short text string (e.g., a count or status label).
  case badge(_ text: String)

  /// A trailing SF Symbol image.
  case image(systemName: String)

  /// A small inline progress bar showing a value between 0.0 and 1.0.
  case progress(_ value: Double)

  /// A spinning activity indicator for loading states.
  case activityIndicator

  /// Escape hatch for parameterized accessories (e.g., `UICellAccessory.detail(actionHandler:)`).
  /// The `key` is used for equality — two `.custom` values are equal when their keys match.
  case custom(UICellAccessory, key: AnyHashable)

  // MARK: Public

  /// Converts to the UIKit `UICellAccessory` equivalent.
  @MainActor
  public var uiAccessory: UICellAccessory {
    switch self {
    case .disclosureIndicator:
      return .disclosureIndicator()

    case .checkmark:
      return .checkmark()

    case .delete:
      return .delete()

    case .reorder:
      return .reorder()

    case .outlineDisclosure:
      return .outlineDisclosure()

    case .detail:
      return .detail()

    case .multiselect:
      return .multiselect()

    case .label(let text):
      return .label(text: text)

    case .toggle(let isOn, let onChange, key: _):
      let toggle = UISwitch()
      toggle.isOn = isOn
      toggle.addAction(UIAction { action in
        guard let sender = action.sender as? UISwitch else {
          assertionFailure("Expected UISwitch sender for toggle action")
          return
        }
        onChange(sender.isOn)
      }, for: .valueChanged)
      return .customView(configuration: .init(customView: toggle, placement: .trailing()))

    case .badge(let text):
      let badgeLabel = BadgeLabel(text: text)
      return .customView(configuration: .init(customView: badgeLabel, placement: .trailing()))

    case .image(let systemName):
      let image = UIImage(systemName: systemName)
      assert(image != nil, "Invalid SF Symbol name: \(systemName)")
      let imageView = UIImageView(image: image)
      imageView.tintColor = .secondaryLabel
      imageView.contentMode = .scaleAspectFit
      return .customView(configuration: .init(customView: imageView, placement: .trailing()))

    case .progress(let value):
      assert((0.0...1.0).contains(value), "Progress value \(value) outside expected range 0.0...1.0")
      let progressView = UIProgressView(progressViewStyle: .default)
      progressView.progress = Float(value)
      return .customView(configuration: .init(customView: progressView, placement: .trailing(), reservedLayoutWidth: .custom(60)))

    case .activityIndicator:
      let spinner = UIActivityIndicatorView(style: .medium)
      spinner.startAnimating()
      return .customView(configuration: .init(customView: spinner, placement: .trailing()))

    case .popUpMenu(let menu, key: _):
      return .popUpMenu(menu)

    case .custom(let accessory, _):
      return accessory
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

  /// Creates an inline toggle switch with a default key.
  ///
  /// All `toggle` accessories created this way compare by `isOn` state and the default key.
  /// If you need multiple toggles in the same cell, use the case initializer directly
  /// with a unique key: `.toggle(isOn: value, onChange: handler, key: "uniqueID")`.
  public static func toggle(
    isOn: Bool,
    key: AnyHashable = AnyHashable("toggle"),
    onChange: @escaping @MainActor (Bool) -> Void
  ) -> ListAccessory {
    .toggle(isOn: isOn, onChange: onChange, key: key)
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
         (.multiselect, .multiselect),
         (.activityIndicator, .activityIndicator):
      true
    case (.label(let lhsText), .label(let rhsText)):
      lhsText == rhsText
    case (.toggle(let lhsOn, _, let lhsKey), .toggle(let rhsOn, _, let rhsKey)):
      lhsOn == rhsOn && lhsKey == rhsKey
    case (.badge(let lhsText), .badge(let rhsText)):
      lhsText == rhsText
    case (.image(let lhsName), .image(let rhsName)):
      lhsName == rhsName
    case (.progress(let lhsValue), .progress(let rhsValue)):
      lhsValue == rhsValue
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

    case .toggle(let isOn, _, let key):
      hasher.combine(10)
      hasher.combine(isOn)
      hasher.combine(key)

    case .badge(let text):
      hasher.combine(11)
      hasher.combine(text)

    case .image(let systemName):
      hasher.combine(12)
      hasher.combine(systemName)

    case .progress(let value):
      hasher.combine(13)
      hasher.combine(value)

    case .activityIndicator:
      hasher.combine(14)
    }
  }

  // MARK: Private

  /// A pill-shaped label used by the `.badge` accessory.
  private final class BadgeLabel: UILabel {

    // MARK: Lifecycle

    convenience init(text: String) {
      self.init(frame: .zero)
      self.text = text
      let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption2)
        .withSymbolicTraits(.traitBold) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption2)
      font = UIFont(descriptor: descriptor, size: 0)
      textColor = tintColor
      backgroundColor = tintColor.withAlphaComponent(0.15)
      textAlignment = .center
      clipsToBounds = true
    }

    // MARK: Internal

    override var intrinsicContentSize: CGSize {
      let base = super.intrinsicContentSize
      return CGSize(
        width: base.width + insets.left + insets.right,
        height: base.height + insets.top + insets.bottom
      )
    }

    override func tintColorDidChange() {
      super.tintColorDidChange()
      textColor = tintColor
      backgroundColor = tintColor.withAlphaComponent(0.15)
    }

    override func drawText(in rect: CGRect) {
      super.drawText(in: rect.inset(by: insets))
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      layer.cornerRadius = bounds.height / 2
    }

    // MARK: Private

    private let insets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)

  }

}
