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
          }
        ) { [store] ref in
          if let model = store.model(for: ref.id) {
            ChatBubbleView(model: model)
          }
        }
        .collectionViewHandler { [store] cv in
          store.collectionView = cv
          cv.allowsSelection = false
        }
        .scrollViewDelegate(store)

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

    let response = ChatConversation.response(for: text)

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

    for qa in ChatConversation.canned {
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
final class ChatStore: NSObject, UIScrollViewDelegate, ChatScrollManaging {

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
    models[id]
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let nearBottom = isNearBottom(in: scrollView)
    if showScrollToBottom == nearBottom {
      showScrollToBottom = !nearBottom
    }
  }

  // MARK: Private

  private var models = [UUID: ChatMessageModel]()
}
