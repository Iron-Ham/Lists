import Lists
import SwiftUI
import UIKit

// MARK: - ListsChatExampleViewController

/// Mock LLM chat interface demonstrating `SimpleList` + `CellViewModel` + `UIHostingConfiguration`.
///
/// This is the UIKit counterpart to `ChatExampleView` (SwiftUI). It uses the same `@Observable`
/// `ChatMessageModel` to drive live updates — `UIHostingConfiguration` automatically re-renders
/// when the observed model changes, so no manual cell reconfiguration is needed during streaming.
final class ListsChatExampleViewController: UIViewController {

  // MARK: Lifecycle

  deinit {
    demoTask?.cancel()
  }

  // MARK: Internal

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Chat Lists"
    view.backgroundColor = .systemBackground

    setupList()
    setupInputBar()
    setupScrollToBottomButton()

    store.list = list

    demoTask = Task {
      await runDemo()
    }
  }

  // MARK: Private

  private var list: SimpleList<ChatBubbleItem>!
  private let store = ListsChatStore()
  private let inputBar = ChatInputBar()
  private nonisolated(unsafe) var demoTask: Task<Void, Never>?
  private var stopDemo = false

  private let scrollToBottomButton: UIButton = {
    let config = UIImage.SymbolConfiguration(textStyle: .title1)
    let image = UIImage(systemName: "chevron.down.circle.fill", withConfiguration: config)
    let button = UIButton(type: .system)
    button.setImage(image, for: .normal)
    button.tintColor = .systemBlue
    button.layer.shadowColor = UIColor.black.cgColor
    button.layer.shadowOpacity = 0.25
    button.layer.shadowRadius = 4
    button.layer.shadowOffset = CGSize(width: 0, height: 2)
    button.alpha = 0
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()

  private func setupList() {
    list = SimpleList<ChatBubbleItem>(
      appearance: .plain,
      showsSeparators: false,
      headerTopPadding: 0,
      selfSizingInvalidation: .disabled
    )
    list.scrollViewDelegate = store

    list.separatorHandler = { _, config in
      var config = config
      config.topSeparatorVisibility = .hidden
      config.bottomSeparatorVisibility = .hidden
      return config
    }

    list.contextMenuProvider = { item in
      UIContextMenuConfiguration(actionProvider: { _ in
        UIMenu(children: [
          UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
            UIPasteboard.general.string = item.model.text
          }
        ])
      })
    }

    let cv = list.collectionView
    cv.allowsSelection = false
    cv.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(cv)
  }

  private func setupInputBar() {
    inputBar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(inputBar)

    inputBar.onSend = { [weak self] text in
      self?.sendMessage(text)
    }

    let cv = list.collectionView
    NSLayoutConstraint.activate([
      cv.topAnchor.constraint(equalTo: view.topAnchor),
      cv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      cv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      cv.bottomAnchor.constraint(equalTo: inputBar.topAnchor),

      inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      inputBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
    ])
  }

  private func setupScrollToBottomButton() {
    view.addSubview(scrollToBottomButton)
    scrollToBottomButton.addTarget(self, action: #selector(scrollToBottomTapped), for: .touchUpInside)

    NSLayoutConstraint.activate([
      scrollToBottomButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      scrollToBottomButton.bottomAnchor.constraint(equalTo: inputBar.topAnchor, constant: -12),
    ])

    store.onScrollToBottomChanged = { [weak self] show in
      UIView.animate(withDuration: 0.2) {
        self?.scrollToBottomButton.alpha = show ? 1 : 0
        self?.scrollToBottomButton.transform = show ? .identity : CGAffineTransform(scaleX: 0.5, y: 0.5)
      }
    }
  }

  @objc
  private func scrollToBottomTapped() {
    store.scrollToBottom(animated: true)
  }

  private func sendMessage(_ text: String) {
    guard !store.isStreaming else { return }
    stopDemo = true

    store.addMessage(role: .user, text: text)
    applySnapshot(scrollToBottom: true)

    let response = ChatConversation.response(for: text)

    store.streamingTask?.cancel()
    store.streamingTask = Task {
      await streamResponse(response)
    }
  }

  private func streamResponse(_ response: String) async {
    store.isStreaming = true
    inputBar.isSendEnabled = false
    do { try await Task.sleep(for: .milliseconds(400)) } catch {
      store.isStreaming = false
      inputBar.isSendEnabled = true
      return
    }

    let model = store.addMessage(role: .assistant, text: "", isStreaming: true)
    applySnapshot(scrollToBottom: true)

    let words = response.split(separator: " ").map(String.init)
    for i in words.indices {
      do { try await Task.sleep(for: .milliseconds(50)) } catch { break }
      model.text = words[0...i].joined(separator: " ")
      store.invalidateLayout()
    }

    model.isStreaming = false
    store.invalidateLayout()
    store.isStreaming = false
    inputBar.isSendEnabled = true
  }

  /// Applies the current items and optionally scrolls to the bottom after the snapshot lands.
  private func applySnapshot(scrollToBottom: Bool = false) {
    Task {
      await list.setItems(store.items, animatingDifferences: false)
      if scrollToBottom {
        store.scrollToBottomAfterInsert()
      }
    }
  }

  private func runDemo() async {
    do { try await Task.sleep(for: .seconds(1)) } catch { return }

    for qa in ChatConversation.canned {
      guard !stopDemo else { return }

      store.addMessage(role: .user, text: qa.question)
      applySnapshot(scrollToBottom: true)
      await streamResponse(qa.answer)

      guard !stopDemo else { return }
      do { try await Task.sleep(for: .seconds(2)) } catch { return }
    }
  }
}

// MARK: - ChatBubbleItem

/// `CellViewModel` that wraps a `ChatMessageModel` and renders via `UIHostingConfiguration`.
///
/// Equality is based on `id` alone — the `@Observable` model handles content updates automatically
/// without requiring the diffable data source to detect value changes.
struct ChatBubbleItem: CellViewModel, Identifiable {

  let id: UUID
  let model: ChatMessageModel

  static func ==(lhs: ChatBubbleItem, rhs: ChatBubbleItem) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  func configure(_ cell: UICollectionViewListCell) {
    cell.contentConfiguration = UIHostingConfiguration {
      ChatBubbleView(model: model)
    }
    .margins(.all, 0)
    cell.backgroundConfiguration = .clear()
  }
}

// MARK: - ListsChatStore

@MainActor
final class ListsChatStore: NSObject, UIScrollViewDelegate, ChatScrollManaging {

  // MARK: Internal

  private(set) var items = [ChatBubbleItem]()
  var isStreaming = false
  var streamingTask: Task<Void, Never>?

  var onScrollToBottomChanged: ((Bool) -> Void)?

  weak var list: SimpleList<ChatBubbleItem>?

  var collectionView: UICollectionView? {
    list?.collectionView
  }

  @discardableResult
  func addMessage(role: ChatMessageModel.Role, text: String, isStreaming: Bool = false) -> ChatMessageModel {
    let model = ChatMessageModel(role: role, text: text, isStreaming: isStreaming)
    items.append(ChatBubbleItem(id: model.id, model: model))
    return model
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let nearBottom = isNearBottom(in: scrollView)
    if showScrollToBottom == nearBottom {
      showScrollToBottom = !nearBottom
      onScrollToBottomChanged?(showScrollToBottom)
    }
  }

  // MARK: Private

  private var showScrollToBottom = false
}
