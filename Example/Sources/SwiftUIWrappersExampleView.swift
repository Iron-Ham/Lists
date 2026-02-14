import Lists
import SwiftUI
import UIKit

/// Demonstrates the shipped UIViewRepresentable wrappers: SimpleListView,
/// GroupedListView, and OutlineListView — all driven by SwiftUI @State.
struct SwiftUIWrappersExampleView: View {
    enum Demo: String, CaseIterable {
        case simple = "Simple"
        case grouped = "Grouped"
        case outline = "Outline"
    }

    @State private var selectedDemo: Demo = .simple

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
}

// MARK: - Simple Demo (Inline Content + Swipe Actions + Context Menu)

/// Uses the inline content closure API — no separate struct needed.
/// Also demonstrates trailing swipe actions and context menus (long-press preview).
private struct SimpleDemoView: View {
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

    var body: some View {
        SimpleListView(
            items: fruits,
            onSelect: { fruit in
                print("Selected: \(fruit.name)")
            },
            trailingSwipeActionsProvider: { fruit in
                let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
                    fruits.removeAll { $0.id == fruit.id }
                    completion(true)
                }
                return UISwipeActionsConfiguration(actions: [deleteAction])
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
            }
        ) { fruit in
            HStack {
                Text(fruit.emoji)
                    .font(.title2)
                Text(fruit.name)
            }
            .padding(.vertical, 4)
        }
        .overlay(alignment: .bottom) {
            Button("Shuffle") { fruits.shuffle() }
                .buttonStyle(.borderedProminent)
                .padding()
        }
    }
}

// MARK: - Grouped Demo (Pull-to-Refresh + ListAccessory + Context Menu)

private struct GroupedDemoView: View {
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
            ],
            onSelect: { item in
                print("Selected: \(item.name)")
            },
            onRefresh: {
                // Simulate network fetch
                try? await Task.sleep(for: .seconds(1))
                languages.shuffle()
                frameworks.shuffle()
            }
        )
        .overlay(alignment: .bottom) {
            Button("Shuffle") {
                languages.shuffle()
                frameworks.shuffle()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}

// MARK: - Outline Demo (Inline Content + Pull-to-Refresh + Context Menu)

/// Uses the inline content closure API for outline lists — no CellViewModel needed.
/// Also demonstrates pull-to-refresh and context menus on outline items.
private struct OutlineDemoView: View {
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

    var body: some View {
        OutlineListView(
            items: items,
            onSelect: { category in
                print("Selected: \(category.name)")
            },
            contextMenuProvider: { category in
                UIContextMenuConfiguration(actionProvider: { _ in
                    let copy = UIAction(title: "Copy Name", image: UIImage(systemName: "doc.on.doc")) { _ in
                        UIPasteboard.general.string = category.name
                    }
                    return UIMenu(children: [copy])
                })
            },
            onRefresh: {
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
        ) { category in
            Text(category.name)
                .padding(.vertical, 2)
        }
    }
}

// MARK: - Data Models

private struct Fruit: Hashable, Identifiable, Sendable {
    let id = UUID()
    let name: String
    let emoji: String
}

private struct EmojiCategory: Hashable, Identifiable, Sendable {
    let id = UUID()
    let name: String
}

// MARK: - Cell View Models

private struct LanguageItem: SwiftUICellViewModel, Identifiable {
    let id = UUID()
    let name: String
    let year: Int

    var body: some View {
        HStack {
            Text(name)
                .font(.body)
            Spacer()
            Text(String(year))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    var accessories: [ListAccessory] {
        [.disclosureIndicator]
    }
}
