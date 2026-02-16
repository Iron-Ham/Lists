import UIKit

extension UICollectionViewListCell {

  /// Applies a standard list content configuration in a single call.
  ///
  /// This is a convenience wrapper around the common four-line pattern of creating a default
  /// content configuration, setting properties, and assigning it back to the cell.
  ///
  /// ```swift
  /// // Before:
  /// func configure(_ cell: UICollectionViewListCell) {
  ///     var content = cell.defaultContentConfiguration()
  ///     content.text = name
  ///     content.secondaryText = email
  ///     content.image = UIImage(systemName: "person")
  ///     cell.contentConfiguration = content
  ///     cell.accessories = [.disclosureIndicator()]
  /// }
  ///
  /// // After:
  /// func configure(_ cell: UICollectionViewListCell) {
  ///     cell.setListContent(
  ///         text: name,
  ///         secondaryText: email,
  ///         image: UIImage(systemName: "person"),
  ///         accessories: [.disclosureIndicator]
  ///     )
  /// }
  /// ```
  ///
  /// For advanced customization beyond text/image/secondaryText, use the closure-based
  /// ``setListContent(accessories:configure:)`` overload or fall back to manual configuration.
  ///
  /// - Parameters:
  ///   - text: Primary text displayed in the cell.
  ///   - secondaryText: Secondary text displayed below or beside the primary text.
  ///   - image: An optional leading image.
  ///   - accessories: Cell accessories (e.g., disclosure indicators, badges). Defaults to empty.
  @MainActor
  public func setListContent(
    text: String? = nil,
    secondaryText: String? = nil,
    image: UIImage? = nil,
    accessories: [ListAccessory] = []
  ) {
    var config = defaultContentConfiguration()
    config.text = text
    config.secondaryText = secondaryText
    config.image = image
    contentConfiguration = config
    self.accessories = accessories.map(\.uiAccessory)
  }

  /// Applies a list content configuration using a closure for full customization.
  ///
  /// Use this when you need access to all `UIListContentConfiguration` properties beyond
  /// the common text/image shortcuts.
  ///
  /// ```swift
  /// func configure(_ cell: UICollectionViewListCell) {
  ///     cell.setListContent(accessories: [.disclosureIndicator]) { content in
  ///         content.text = name
  ///         content.textProperties.font = .preferredFont(forTextStyle: .headline)
  ///         content.secondaryText = subtitle
  ///         content.secondaryTextProperties.color = .secondaryLabel
  ///         content.image = avatar
  ///         content.imageProperties.cornerRadius = 20
  ///     }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - accessories: Cell accessories to apply. Defaults to empty.
  ///   - configure: A closure that receives a mutable `UIListContentConfiguration` to customize.
  @MainActor
  public func setListContent(
    accessories: [ListAccessory] = [],
    configure: (inout UIListContentConfiguration) -> Void
  ) {
    var config = defaultContentConfiguration()
    configure(&config)
    contentConfiguration = config
    self.accessories = accessories.map(\.uiAccessory)
  }
}
