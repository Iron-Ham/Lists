import Foundation
import SwiftUI
import UIKit

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

  enum Role: Hashable, Sendable {
    case user
    case assistant
  }

  let id: UUID
  let role: Role
  var text: String
  var isStreaming: Bool

  /// Display text with a streaming cursor when active.
  var displayText: String {
    if isStreaming {
      return text.isEmpty ? "▍" : text + " ▍"
    }
    return text
  }
}

// MARK: - ChatBubbleView

/// Reusable SwiftUI chat bubble used by the SwiftUI and Lists chat examples.
struct ChatBubbleView: View {

  let model: ChatMessageModel

  var body: some View {
    HStack {
      if model.role == .user {
        Spacer(minLength: 60)
      }

      Text(model.displayText)
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

// MARK: - ChatConversation

enum ChatConversation {
  static let canned: [(question: String, answer: String)] = [
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

  /// Returns a canned response matching the input, or a generic fallback.
  static func response(for input: String) -> String {
    canned
      .first { input.localizedCaseInsensitiveContains(String($0.question.prefix(20))) }?.answer
      ?? "That's an interesting question! In a real app this is where the LLM API response would stream in token by token, with each update triggering a smooth diff in the collection view."
  }
}

// MARK: - ChatScrollManaging

/// Shared scroll-to-bottom behavior for chat stores.
///
/// Conforming types only need to provide a `collectionView` accessor —
/// all scroll tracking, auto-scroll, and layout invalidation come for free.
@MainActor
protocol ChatScrollManaging: AnyObject {
  var collectionView: UICollectionView? { get }
}

extension ChatScrollManaging {

  var isNearBottom: Bool {
    guard let collectionView else { return true }
    return isNearBottom(in: collectionView)
  }

  func isNearBottom(in scrollView: UIScrollView) -> Bool {
    let offsetY = scrollView.contentOffset.y
    let contentHeight = scrollView.contentSize.height
    let frameHeight = scrollView.bounds.height
    let insetBottom = scrollView.adjustedContentInset.bottom
    return offsetY >= contentHeight - frameHeight - insetBottom - 80
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
    DispatchQueue.main.async { [weak self] in
      self?.scrollToBottom(animated: true)
    }
  }

  /// Invalidates layout without animation and auto-scrolls if near the bottom.
  ///
  /// Used during streaming to resize cells as text grows. The `performWithoutAnimation`
  /// block prevents UIKit from animating the height change, while the auto-scroll keeps
  /// the latest content visible.
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
}
