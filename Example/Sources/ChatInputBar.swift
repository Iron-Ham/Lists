import UIKit

// MARK: - ChatInputBar

/// Shared UIKit input bar used by the UIKit chat examples.
///
/// Contains a text field and send button in a horizontal layout with a top divider.
/// Hook `onSend` to receive submitted text. Toggle `isSendEnabled` to control the send button.
final class ChatInputBar: UIView, UITextFieldDelegate {

  // MARK: Lifecycle

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Internal

  var onSend: ((String) -> Void)?

  var isSendEnabled = true {
    didSet {
      updateSendButton()
    }
  }

  func textFieldShouldReturn(_: UITextField) -> Bool {
    submit()
    return false
  }

  // MARK: Private

  private let divider = UIView()
  private let textField = UITextField()
  private let sendButton = UIButton(type: .system)

  private func setup() {
    // Divider
    divider.backgroundColor = .separator
    divider.translatesAutoresizingMaskIntoConstraints = false
    addSubview(divider)

    // Text field
    textField.placeholder = "Message…"
    textField.borderStyle = .roundedRect
    textField.returnKeyType = .send
    textField.delegate = self
    textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    textField.translatesAutoresizingMaskIntoConstraints = false
    addSubview(textField)

    // Send button
    let config = UIImage.SymbolConfiguration(textStyle: .title2)
    sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill", withConfiguration: config), for: .normal)
    sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    sendButton.translatesAutoresizingMaskIntoConstraints = false
    addSubview(sendButton)

    NSLayoutConstraint.activate([
      divider.topAnchor.constraint(equalTo: topAnchor),
      divider.leadingAnchor.constraint(equalTo: leadingAnchor),
      divider.trailingAnchor.constraint(equalTo: trailingAnchor),
      divider.heightAnchor.constraint(equalToConstant: 1.0 / 3.0),

      textField.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 8),
      textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

      sendButton.leadingAnchor.constraint(equalTo: textField.trailingAnchor, constant: 8),
      sendButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      sendButton.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
    ])

    updateSendButton()
  }

  @objc
  private func sendTapped() {
    submit()
  }

  @objc
  private func textFieldDidChange() {
    updateSendButton()
  }

  private func submit() {
    guard let text = textField.text?.trimmingCharacters(in: .whitespaces), !text.isEmpty, isSendEnabled else { return }
    textField.text = ""
    updateSendButton()
    onSend?(text)
  }

  private func updateSendButton() {
    let hasText = !(textField.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    sendButton.isEnabled = hasText && isSendEnabled
  }
}
