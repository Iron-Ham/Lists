// ABOUTME: Chat UI built with raw CollectionViewDiffableDataSource and pure UIKit cells.
// ABOUTME: Manually reconfigures cells during streaming via UIContentConfiguration.
import ListKit
import SwiftUI
import UIKit

// MARK: - ListKitChatExampleViewController

/// Mock LLM chat interface demonstrating raw `CollectionViewDiffableDataSource` with pure UIKit cells.
///
/// Unlike the `Lists` counterparts that use `@Observable` + `UIHostingConfiguration` for automatic
/// updates, this example manually reconfigures cells during streaming by directly setting a new
/// `UIContentConfiguration` on the visible cell. This shows the lowest-level approach to building
/// a performant chat interface with ListKit.
final class ListKitChatExampleViewController: UIViewController, UICollectionViewDelegate {

  // MARK: Lifecycle

  deinit {
    demoTask?.cancel()
  }

  // MARK: Internal

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Chat ListKit"
    view.backgroundColor = .systemBackground

    setupCollectionView()
    setupInputBar()
    setupScrollToBottomButton()

    demoTask = Task {
      await runDemo()
    }
  }

  func collectionView(
    _: UICollectionView,
    contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
    point _: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard
      let indexPath = indexPaths.first,
      let ref = dataSource.itemIdentifier(for: indexPath),
      let model = store.model(for: ref.id)
    else { return nil }

    return UIContextMenuConfiguration(actionProvider: { _ in
      UIMenu(children: [
        UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
          UIPasteboard.general.string = model.text
        }
      ])
    })
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    store.scrollViewDidScroll(scrollView)
  }

  // MARK: Private

  private var collectionView: UICollectionView!
  private var dataSource: CollectionViewDiffableDataSource<Int, ChatMessageRef>!
  private let store = ListKitChatStore()
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

  private func setupCollectionView() {
    var listConfig = UICollectionLayoutListConfiguration(appearance: .plain)
    listConfig.showsSeparators = false
    listConfig.headerTopPadding = 0
    let layout = UICollectionViewCompositionalLayout.list(using: listConfig)

    collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.selfSizingInvalidation = .disabled
    collectionView.allowsSelection = false
    collectionView.delegate = self
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(collectionView)

    let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, ChatMessageRef> {
      [weak self] cell, _, ref in
      guard let model = self?.store.model(for: ref.id) else {
        assertionFailure("ChatStore missing model for ref \(ref.id)")
        return
      }
      cell.contentConfiguration = ChatBubbleContentConfiguration(
        role: model.role,
        text: model.displayText,
        isStreaming: model.isStreaming
      )
      cell.backgroundConfiguration = .clear()
    }

    dataSource = CollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, ref in
      cv.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: ref)
    }

    store.collectionView = collectionView
  }

  private func setupInputBar() {
    inputBar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(inputBar)

    inputBar.onSend = { [weak self] text in
      self?.sendMessage(text)
    }

    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: view.topAnchor),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: inputBar.topAnchor),

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
    applySnapshot()
    store.scrollToBottomAfterInsert()

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
    applySnapshot()
    store.scrollToBottomAfterInsert()

    let words = response.split(separator: " ").map(String.init)
    for i in words.indices {
      do { try await Task.sleep(for: .milliseconds(50)) } catch { break }
      model.text = words[0...i].joined(separator: " ")

      // Direct cell reconfiguration — no @Observable, no snapshot apply.
      reconfigureStreamingCell(model: model)

      store.invalidateLayout()
    }

    model.isStreaming = false
    reconfigureStreamingCell(model: model)
    store.invalidateLayout()

    store.isStreaming = false
    inputBar.isSendEnabled = true
  }

  /// Reconfigures the last cell in-place during streaming without a snapshot apply.
  private func reconfigureStreamingCell(model: ChatMessageModel) {
    guard
      let ref = store.messageRefs.last,
      let indexPath = dataSource.indexPath(for: ref),
      let cell = collectionView.cellForItem(at: indexPath) as? UICollectionViewListCell
    else { return }
    cell.contentConfiguration = ChatBubbleContentConfiguration(
      role: model.role,
      text: model.displayText,
      isStreaming: model.isStreaming
    )
  }

  private func applySnapshot() {
    var snapshot = DiffableDataSourceSnapshot<Int, ChatMessageRef>()
    snapshot.appendSections([0])
    snapshot.appendItems(store.messageRefs, toSection: 0)
    dataSource.apply(snapshot, animatingDifferences: false)
  }

  private func runDemo() async {
    do { try await Task.sleep(for: .seconds(1)) } catch { return }

    for qa in ChatConversation.canned {
      guard !stopDemo else { return }

      store.addMessage(role: .user, text: qa.question)
      applySnapshot()
      store.scrollToBottomAfterInsert()
      await streamResponse(qa.answer)

      guard !stopDemo else { return }
      do { try await Task.sleep(for: .seconds(2)) } catch { return }
    }
  }
}

// MARK: - ChatBubbleContentConfiguration

/// Pure UIKit content configuration for chat bubbles, used with `UICollectionViewListCell`.
///
/// Unlike the Lists example that leverages `@Observable` + `UIHostingConfiguration`,
/// this is a simple value type — each streaming tick creates a new instance.
private struct ChatBubbleContentConfiguration: UIContentConfiguration, Hashable {

  let role: ChatMessageModel.Role
  let text: String
  let isStreaming: Bool

  func makeContentView() -> UIView & UIContentView {
    ChatBubbleContentView(configuration: self)
  }

  func updated(for _: UIConfigurationState) -> ChatBubbleContentConfiguration {
    self
  }
}

// MARK: - ChatBubbleContentView

/// Pure UIKit chat bubble with auto-layout constraints.
///
/// Alignment switches based on role: user bubbles align trailing (blue), assistant bubbles
/// align leading (gray). Max width is capped at 75% of the container.
private final class ChatBubbleContentView: UIView, UIContentView {

  // MARK: Lifecycle

  init(configuration: ChatBubbleContentConfiguration) {
    appliedConfiguration = configuration
    super.init(frame: .zero)
    setup()
    apply(configuration)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Internal

  var configuration: UIContentConfiguration {
    get { appliedConfiguration }
    set {
      guard
        let newConfig = newValue as? ChatBubbleContentConfiguration,
        newConfig != appliedConfiguration
      else { return }
      appliedConfiguration = newConfig
      apply(newConfig)
    }
  }

  // MARK: Private

  private var appliedConfiguration: ChatBubbleContentConfiguration

  private let bubbleContainer = UIView()
  private let label = UILabel()

  private var leadingConstraint: NSLayoutConstraint!
  private var trailingConstraint: NSLayoutConstraint!

  private func setup() {
    // Bubble container
    bubbleContainer.layer.cornerRadius = 16
    bubbleContainer.translatesAutoresizingMaskIntoConstraints = false
    addSubview(bubbleContainer)

    // Label
    label.numberOfLines = 0
    label.font = .preferredFont(forTextStyle: .body)
    label.adjustsFontForContentSizeCategory = true
    label.translatesAutoresizingMaskIntoConstraints = false
    bubbleContainer.addSubview(label)

    // Constraints
    leadingConstraint = bubbleContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
    trailingConstraint = bubbleContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)

    NSLayoutConstraint.activate([
      bubbleContainer.topAnchor.constraint(equalTo: topAnchor, constant: 2),
      bubbleContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
      bubbleContainer.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.75),

      label.topAnchor.constraint(equalTo: bubbleContainer.topAnchor, constant: 8),
      label.bottomAnchor.constraint(equalTo: bubbleContainer.bottomAnchor, constant: -8),
      label.leadingAnchor.constraint(equalTo: bubbleContainer.leadingAnchor, constant: 12),
      label.trailingAnchor.constraint(equalTo: bubbleContainer.trailingAnchor, constant: -12),
    ])
  }

  private func apply(_ config: ChatBubbleContentConfiguration) {
    label.text = config.text

    switch config.role {
    case .user:
      bubbleContainer.backgroundColor = .systemBlue
      label.textColor = .white
      leadingConstraint.isActive = false
      trailingConstraint.isActive = true

    case .assistant:
      bubbleContainer.backgroundColor = .systemGray5
      label.textColor = .label
      trailingConstraint.isActive = false
      leadingConstraint.isActive = true
    }
  }
}

// MARK: - ListKitChatStore

@MainActor
final class ListKitChatStore: NSObject, ChatScrollManaging {

  // MARK: Internal

  private(set) var messageRefs = [ChatMessageRef]()
  var isStreaming = false
  var streamingTask: Task<Void, Never>?

  var onScrollToBottomChanged: ((Bool) -> Void)?

  weak var collectionView: UICollectionView?

  @discardableResult
  func addMessage(role: ChatMessageModel.Role, text: String, isStreaming: Bool = false) -> ChatMessageModel {
    let model = ChatMessageModel(role: role, text: text, isStreaming: isStreaming)
    models[model.id] = model
    messageRefs.append(ChatMessageRef(id: model.id))
    return model
  }

  func model(for id: UUID) -> ChatMessageModel? {
    models[id]
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let nearBottom = isNearBottom(in: scrollView)
    if showScrollToBottom == nearBottom {
      showScrollToBottom = !nearBottom
      onScrollToBottomChanged?(showScrollToBottom)
    }
  }

  // MARK: Private

  private var models = [UUID: ChatMessageModel]()
  private var showScrollToBottom = false
}
