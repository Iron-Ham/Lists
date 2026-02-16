import Lists
import SwiftUI
import UIKit

// MARK: - ChatExampleView

/// Mock LLM chat interface demonstrating `SimpleListView` with live-updating data.
///
/// Content updates flow through `@Observable` (no cell reconfiguration, no flash). Cell resizing
/// is handled via manual animated layout invalidation with `selfSizingInvalidation: .disabled`
/// (no bounce). The result is smooth bubble growth as words stream in.
struct ChatExampleView: View {

  // MARK: Internal

  var body: some View {
    VStack(spacing: 0) {
      ZStack(alignment: .bottomTrailing) {
        SimpleListView(
          items: store.messageRefs,
          showsSeparators: false,
          headerTopPadding: 0,
          selfSizingInvalidation: .disabled,
          separatorHandler: { _, config in
            var config = config
            config.topSeparatorVisibility = .hidden
            config.bottomSeparatorVisibility = .hidden
            return config
          },
          collectionViewHandler: { [store] cv in
            store.collectionView = cv
            cv.allowsSelection = false
          },
          scrollViewDelegate: store
        ) { [store] ref in
          ChatBubbleView(model: store.model(for: ref.id))
        }

        if store.showScrollToBottom {
          Button {
            store.scrollToBottom(animated: true)
          } label: {
            Image(systemName: "chevron.down.circle.fill")
              .font(.title)
              .foregroundStyle(.white, .blue)
              .shadow(radius: 4)
          }
          .padding(.trailing, 16)
          .padding(.bottom, 12)
          .transition(.opacity.combined(with: .scale))
        }
      }

      Divider()

      HStack(spacing: 8) {
        TextField("Message…", text: $inputText)
          .textFieldStyle(.roundedBorder)
          .onSubmit(sendMessage)

        Button(action: sendMessage) {
          Image(systemName: "arrow.up.circle.fill")
            .font(.title2)
        }
        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || store.isStreaming)
      }
      .padding(.horizontal)
      .padding(.vertical, 8)
    }
    .task {
      await runDemo()
    }
  }

  // MARK: Private

  private static let cannedConversation: [(question: String, answer: String)] = [
    (
      "What is Swift's actor model?",
      "Swift actors provide data-race safety by isolating their mutable state. Only one task can access an actor's properties at a time, and all cross-actor calls are asynchronous. This eliminates a whole class of concurrency bugs at compile time rather than runtime."
    ),
    (
      "How does diffable data source work?",
      "NSDiffableDataSource takes snapshots of your data and automatically computes the difference between the old and new states. It then applies only the necessary insertions, deletions, and moves with smooth animations — no more calling reloadData or manually managing index paths."
    ),
    (
      "What makes SwiftUI declarative?",
      "In SwiftUI you describe what your UI should look like for a given state, and the framework figures out how to transition between states. You don't imperatively add or remove views — instead you express the view hierarchy as a function of your data, and SwiftUI handles the rest."
    ),
    (
      "Explain structured concurrency.",
      "Structured concurrency ties the lifetime of child tasks to their parent scope. When you use async let or a task group, child tasks are automatically cancelled if the parent is cancelled, and the parent waits for all children to finish. This prevents leaked tasks and makes concurrency predictable."
    ),
    (
      "What is copy-on-write?",
      "Copy-on-write is an optimization where value types like Array and Dictionary share the same underlying storage until one copy is mutated. At that point, Swift creates a unique copy of the buffer. This gives you the safety of value semantics with the performance of reference types for the common case where copies are never modified."
    ),
    (
      "How do property wrappers work?",
      "A property wrapper is a type that encapsulates read and write access to a property. You define a struct or class with a wrappedValue property, then annotate stored properties with @YourWrapper. The compiler synthesizes a backing _property that holds the wrapper instance. This is how @State, @Binding, @Published, and many other SwiftUI and Combine features work under the hood."
    ),
    (
      "What are existential types in Swift?",
      "An existential type is the runtime box Swift creates when you use a protocol as a type (e.g., `any Drawable`). It stores the value, a pointer to its type metadata, and a witness table of protocol conformances. Existentials add indirection and heap allocation, which is why Swift introduced the `any` keyword to make the cost explicit and encourages generics (`some Drawable`) when possible."
    ),
    (
      "Explain Swift's result builder DSL.",
      "Result builders transform a sequence of statements into a single value using static buildBlock, buildOptional, buildEither, and other methods. SwiftUI's @ViewBuilder is the most famous example — it turns your if/else and sequential view declarations into a type-erased tree of views. You can create your own result builders for HTML, regex, configuration DSLs, and more."
    ),
    (
      "What is the Sendable protocol?",
      "Sendable marks types that are safe to pass across concurrency boundaries. Value types with Sendable fields conform automatically, actors are always Sendable, and classes need to be final with immutable stored properties. The compiler checks Sendable constraints at boundaries like Task creation and actor calls, catching data races before they happen."
    ),
    (
      "How does Swift's type inference work?",
      "Swift's type inference uses a constraint-based solver. When you write `let x = [1, 2, 3]`, the compiler generates constraints from the literal expressions and context, then solves them to determine that x is [Int]. It works bidirectionally — context flows both from initializers upward and from type annotations downward. This is why you can write `.blue` instead of `Color.blue` when the expected type is known."
    ),
  ]

  @State private var store = ChatStore()
  @State private var inputText = ""
  @State private var stopDemo = false

  private func sendMessage() {
    let text = inputText.trimmingCharacters(in: .whitespaces)
    guard !text.isEmpty, !store.isStreaming else { return }
    inputText = ""
    stopDemo = true

    store.addMessage(role: .user, text: text)
    store.scrollToBottomAfterInsert()

    let response = Self.cannedConversation
      .first { text.localizedCaseInsensitiveContains(String($0.question.prefix(20))) }?.answer
      ?? "That's an interesting question! In a real app this is where the LLM API response would stream in token by token, with each update triggering a smooth diff in the collection view."

    store.streamingTask?.cancel()
    store.streamingTask = Task {
      await streamResponse(response)
    }
  }

  private func streamResponse(_ response: String) async {
    store.isStreaming = true
    do { try await Task.sleep(for: .milliseconds(400)) } catch {
      store.isStreaming = false
      return
    }

    let model = store.addMessage(role: .assistant, text: "", isStreaming: true)
    store.scrollToBottomAfterInsert()

    let words = response.split(separator: " ").map(String.init)
    for i in words.indices {
      do { try await Task.sleep(for: .milliseconds(50)) } catch { break }
      model.text = words[0...i].joined(separator: " ")
      store.invalidateLayout()
    }

    model.isStreaming = false
    store.invalidateLayout()
    store.isStreaming = false
  }

  private func runDemo() async {
    do { try await Task.sleep(for: .seconds(1)) } catch { return }

    for qa in Self.cannedConversation {
      guard !stopDemo else { return }

      store.addMessage(role: .user, text: qa.question)
      store.scrollToBottomAfterInsert()
      await streamResponse(qa.answer)

      guard !stopDemo else { return }
      do { try await Task.sleep(for: .seconds(2)) } catch { return }
    }
  }
}

// MARK: - ChatStore

@Observable
@MainActor
final class ChatStore: NSObject, UIScrollViewDelegate {

  // MARK: Internal

  private(set) var messageRefs = [ChatMessageRef]()
  var isStreaming = false
  var showScrollToBottom = false
  var streamingTask: Task<Void, Never>?

  weak var collectionView: UICollectionView?

  @discardableResult
  func addMessage(role: ChatMessageModel.Role, text: String, isStreaming: Bool = false) -> ChatMessageModel {
    let model = ChatMessageModel(role: role, text: text, isStreaming: isStreaming)
    models[model.id] = model
    messageRefs.append(ChatMessageRef(id: model.id))
    return model
  }

  func model(for id: UUID) -> ChatMessageModel? {
    let result = models[id]
    assert(result != nil, "ChatStore.model(for:) — no model found for id \(id)")
    return result
  }

  /// Performs a non-animated layout pass so cell heights match their current content.
  /// The text itself already updates smoothly via `@Observable` — this just keeps the
  /// cell frame in sync without any UIKit animation artifacts.
  func invalidateLayout() {
    guard let collectionView else { return }
    UIView.performWithoutAnimation {
      collectionView.collectionViewLayout.invalidateLayout()
      collectionView.layoutIfNeeded()
    }
    if isNearBottom, !collectionView.isTracking, !collectionView.isDecelerating {
      scrollToBottom(animated: false)
    }
  }

  func scrollToBottom(animated: Bool) {
    guard let collectionView else { return }
    let sections = collectionView.numberOfSections
    guard sections > 0 else { return }
    let lastSection = sections - 1
    let items = collectionView.numberOfItems(inSection: lastSection)
    guard items > 0 else { return }
    collectionView.scrollToItem(
      at: IndexPath(item: items - 1, section: lastSection),
      at: .bottom,
      animated: animated
    )
  }

  func scrollToBottomAfterInsert() {
    guard isNearBottom, let collectionView, !collectionView.isTracking, !collectionView.isDecelerating else { return }
    // Dispatch to next run loop so the snapshot apply has finished layout.
    DispatchQueue.main.async { [weak self] in
      self?.scrollToBottom(animated: true)
    }
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let nearBottom = isNearBottom(in: scrollView)
    if showScrollToBottom == nearBottom {
      showScrollToBottom = !nearBottom
    }
  }

  // MARK: Private

  private var models = [UUID: ChatMessageModel]()

  private var isNearBottom: Bool {
    guard let collectionView else { return true }
    return isNearBottom(in: collectionView)
  }

  private func isNearBottom(in scrollView: UIScrollView) -> Bool {
    let offsetY = scrollView.contentOffset.y
    let contentHeight = scrollView.contentSize.height
    let frameHeight = scrollView.bounds.height
    let insetBottom = scrollView.adjustedContentInset.bottom
    // Consider "near bottom" if within 80pt of the bottom edge.
    return offsetY >= contentHeight - frameHeight - insetBottom - 80
  }
}

// MARK: - ChatMessageRef

struct ChatMessageRef: Hashable, Sendable {
  let id: UUID
}

// MARK: - ChatMessageModel

@Observable
@MainActor
final class ChatMessageModel {

  // MARK: Lifecycle

  init(role: Role, text: String, isStreaming: Bool = false) {
    id = UUID()
    self.role = role
    self.text = text
    self.isStreaming = isStreaming
  }

  // MARK: Internal

  enum Role: Sendable {
    case user
    case assistant
  }

  let id: UUID
  let role: Role
  var text: String
  var isStreaming: Bool
}

// MARK: - ChatBubbleView

private struct ChatBubbleView: View {

  // MARK: Internal

  let model: ChatMessageModel?

  var body: some View {
    if let model {
      HStack {
        if model.role == .user {
          Spacer(minLength: 60)
        }

        Text(displayText(for: model))
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(model.role == .user ? Color.blue : Color(.systemGray5))
          .foregroundStyle(model.role == .user ? Color.white : Color.primary)
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .contextMenu {
            Button {
              UIPasteboard.general.string = model.text
            } label: {
              Label("Copy", systemImage: "doc.on.doc")
            }
          }

        if model.role == .assistant {
          Spacer(minLength: 60)
        }
      }
      .padding(.vertical, 2)
      .transaction { $0.animation = nil }
    }
  }

  // MARK: Private

  private func displayText(for model: ChatMessageModel) -> String {
    if model.isStreaming {
      return model.text.isEmpty ? "▍" : model.text + " ▍"
    }
    return model.text
  }
}
