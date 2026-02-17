// ABOUTME: Pure SwiftUI demo of SimpleListView, GroupedListView, and OutlineListView wrappers.
// ABOUTME: Segmented picker switches between simple, grouped, and outline list demos.
import Lists
import SwiftUI
import UIKit

// MARK: - SwiftUIWrappersExampleView

/// Demonstrates the shipped UIViewRepresentable wrappers: SimpleListView,
/// GroupedListView, and OutlineListView — all driven by SwiftUI @State.
struct SwiftUIWrappersExampleView: View {

  // MARK: Internal

  enum Demo: String, CaseIterable {
    case simple = "Simple"
    case grouped = "Grouped"
    case outline = "Outline"
  }

  var body: some View {
    VStack(spacing: 0) {
      Picker("Demo", selection: $selectedDemo) {
        ForEach(Demo.allCases, id: \.self) { demo in
          Text(demo.rawValue).tag(demo)
        }
      }
      .pickerStyle(.segmented)
      .padding()

      switch selectedDemo {
      case .simple:
        SimpleDemoView()
      case .grouped:
        GroupedDemoView()
      case .outline:
        OutlineDemoView()
      }
    }
  }

  // MARK: Private

  @State private var selectedDemo = Demo.simple

}

// MARK: - SimpleDemoView

/// Uses the inline content closure API — no separate struct needed.
/// Also demonstrates separator customization, pull-to-refresh, swipe actions,
/// and context menus (long-press preview).
private struct SimpleDemoView: View {

  // MARK: Internal

  var body: some View {
    SimpleListView(
      items: fruits,
      separatorColor: .systemBlue,
      onSelect: { fruit in
        print("Selected: \(fruit.name)")
      },
      trailingSwipeActionsProvider: { fruit in
        let pin = UIContextualAction(style: .normal, title: "Pin") { _, _, completion in
          print("Pinned \(fruit.name)")
          completion(true)
        }
        pin.image = UIImage(systemName: "pin.fill")
        pin.backgroundColor = .systemOrange

        let archive = UIContextualAction(style: .normal, title: "Archive") { _, _, completion in
          print("Archived \(fruit.name)")
          completion(true)
        }
        archive.image = UIImage(systemName: "archivebox.fill")
        archive.backgroundColor = .systemPurple

        return UISwipeActionsConfiguration(actions: [pin, archive])
      },
      leadingSwipeActionsProvider: { fruit in
        let favorite = UIContextualAction(style: .normal, title: "Favorite") { _, _, completion in
          print("Favorited \(fruit.name)")
          completion(true)
        }
        favorite.image = UIImage(systemName: "heart.fill")
        favorite.backgroundColor = .systemPink
        return UISwipeActionsConfiguration(actions: [favorite])
      },
      contextMenuProvider: { fruit in
        UIContextMenuConfiguration(actionProvider: { _ in
          let favorite = UIAction(title: "Favorite", image: UIImage(systemName: "heart")) { _ in
            print("Favorited \(fruit.name)")
          }
          let share = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { _ in
            print("Shared \(fruit.name)")
          }
          return UIMenu(children: [favorite, share])
        })
      },
      separatorHandler: { fruit, config in
        var config = config
        if fruit == fruits.first {
          config.topSeparatorInsets = .init(top: 0, leading: 60, bottom: 0, trailing: 0)
        }
        return config
      }
    ) { fruit in
      HStack {
        Text(fruit.emoji)
          .font(.title2)
        Text(fruit.name)
      }
      .padding(.vertical, 4)
    }
    .onRefresh {
      try? await Task.sleep(for: .seconds(1))
      fruits.shuffle()
    }
  }

  // MARK: Private

  @State private var fruits: [Fruit] = [
    Fruit(name: "Apple", emoji: "🍎"),
    Fruit(name: "Banana", emoji: "🍌"),
    Fruit(name: "Cherry", emoji: "🍒"),
    Fruit(name: "Grape", emoji: "🍇"),
    Fruit(name: "Mango", emoji: "🥭"),
    Fruit(name: "Orange", emoji: "🍊"),
    Fruit(name: "Peach", emoji: "🍑"),
    Fruit(name: "Strawberry", emoji: "🍓"),
  ]

}

// MARK: - GroupedDemoView

private struct GroupedDemoView: View {

  // MARK: Internal

  var body: some View {
    GroupedListView(
      sections: [
        SectionModel(
          id: "languages",
          items: languages,
          header: "Languages",
          footer: "\(languages.count) items"
        ),
        SectionModel(
          id: "frameworks",
          items: frameworks,
          header: "Frameworks",
          footer: "\(frameworks.count) items"
        ),
      ]
    )
    .editing(isEditing)
    .allowsMultipleSelection(isEditing)
    .onSelect { item in
      print("Selected: \(item.name)")
    }
    .onDelete { item in
      languages.removeAll { $0.id == item.id }
      frameworks.removeAll { $0.id == item.id }
    }
    .leadingSwipeActions { item in
      let flag = UIContextualAction(style: .normal, title: "Flag") { _, _, completion in
        print("Flagged \(item.name)")
        completion(true)
      }
      flag.image = UIImage(systemName: "flag.fill")
      flag.backgroundColor = .systemIndigo
      return UISwipeActionsConfiguration(actions: [flag])
    }
    .separatorHandler { item, config in
      // Hide separator for the last item in each section
      if item == languages.last || item == frameworks.last {
        var config = config
        config.bottomSeparatorVisibility = .hidden
        return config
      }
      return config
    }
    .onRefresh {
      // Simulate network fetch
      try? await Task.sleep(for: .seconds(1))
      languages.shuffle()
      frameworks.shuffle()
    }
    .overlay(alignment: .bottom) {
      HStack(spacing: 12) {
        Button(isEditing ? "Done" : "Edit") {
          isEditing.toggle()
        }
        .buttonStyle(.borderedProminent)

        Button("Shuffle") {
          languages.shuffle()
          frameworks.shuffle()
        }
        .buttonStyle(.bordered)
      }
      .padding()
    }
  }

  // MARK: Private

  @State private var isEditing = false

  @State private var languages = [
    LanguageItem(name: "Swift", year: 2014),
    LanguageItem(name: "Kotlin", year: 2011),
    LanguageItem(name: "Rust", year: 2010),
  ]

  @State private var frameworks = [
    LanguageItem(name: "SwiftUI", year: 2019),
    LanguageItem(name: "Jetpack Compose", year: 2021),
    LanguageItem(name: "Flutter", year: 2017),
  ]

}

// MARK: - OutlineDemoView

/// Uses the inline content closure API for outline lists — no CellViewModel needed.
/// Also demonstrates pull-to-refresh and context menus on outline items.
private struct OutlineDemoView: View {

  // MARK: Internal

  var body: some View {
    OutlineListView(
      items: items,
      separatorColor: .separator,
      onSelect: { category in
        print("Selected: \(category.name)")
      },
      onDelete: { category in
        items = items.compactMap { topLevel in
          if topLevel.item.id == category.id { return nil }
          let filtered = topLevel.children.filter { $0.item.id != category.id }
          return OutlineItem(
            item: topLevel.item,
            children: filtered,
            isExpanded: topLevel.isExpanded
          )
        }
      },
      contextMenuProvider: { category in
        UIContextMenuConfiguration(actionProvider: { _ in
          let copy = UIAction(title: "Copy Name", image: UIImage(systemName: "doc.on.doc")) { _ in
            UIPasteboard.general.string = category.name
          }
          return UIMenu(children: [copy])
        })
      }
    ) { category in
      Text(category.name)
        .padding(.vertical, 2)
    }
    .onRefresh {
      try? await Task.sleep(for: .seconds(1))
      // Randomize expansion state
      items = items.map { topLevel in
        OutlineItem(
          item: topLevel.item,
          children: topLevel.children.shuffled(),
          isExpanded: Bool.random()
        )
      }
    }
  }

  // MARK: Private

  @State private var items: [OutlineItem<EmojiCategory>] = [
    OutlineItem(
      item: EmojiCategory(name: "Animals"),
      children: [
        OutlineItem(item: EmojiCategory(name: "🐶 Dog")),
        OutlineItem(item: EmojiCategory(name: "🐱 Cat")),
        OutlineItem(item: EmojiCategory(name: "🐦 Bird")),
      ],
      isExpanded: true
    ),
    OutlineItem(
      item: EmojiCategory(name: "Food"),
      children: [
        OutlineItem(item: EmojiCategory(name: "🍕 Pizza")),
        OutlineItem(item: EmojiCategory(name: "🍔 Burger")),
        OutlineItem(item: EmojiCategory(name: "🌮 Taco")),
      ],
      isExpanded: true
    ),
    OutlineItem(
      item: EmojiCategory(name: "Sports"),
      children: [
        OutlineItem(item: EmojiCategory(name: "⚽ Soccer")),
        OutlineItem(item: EmojiCategory(name: "🏀 Basketball")),
        OutlineItem(item: EmojiCategory(name: "🎾 Tennis")),
      ]
    ),
  ]

}

// MARK: - Fruit

private struct Fruit: Hashable, Identifiable, Sendable {
  let id = UUID()
  let name: String
  let emoji: String
}

// MARK: - EmojiCategory

private struct EmojiCategory: Hashable, Identifiable, Sendable {
  let id = UUID()
  let name: String
}

// MARK: - LanguageItem

private struct LanguageItem: SwiftUICellViewModel, Identifiable {
  let id = UUID()
  let name: String
  let year: Int
  var isFavorite = false

  var body: some View {
    Text(name)
      .font(.body)
      .padding(.vertical, 2)
  }

  var accessories: [ListAccessory] {
    [
      .badge(String(year)),
      .image(systemName: isFavorite ? "star.fill" : "star"),
      .popUpMenu(UIMenu(title: "", children: [
        UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
          UIPasteboard.general.string = name
        },
        UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { _ in
          print("Share \(name)")
        },
      ])),
      .disclosureIndicator,
    ]
  }
}
