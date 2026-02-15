import Testing
import UIKit
@testable import Lists

@MainActor
struct ListAccessoryTests {
  @Test
  func labelEqualityWithSameText() {
    let a = ListAccessory.label(text: "Count")
    let b = ListAccessory.label(text: "Count")
    #expect(a == b)
  }

  @Test
  func labelInequalityWithDifferentText() {
    let a = ListAccessory.label(text: "A")
    let b = ListAccessory.label(text: "B")
    #expect(a != b)
  }

  @Test
  func labelNotEqualToOtherCases() {
    let label = ListAccessory.label(text: "Test")
    #expect(label != .detail)
    #expect(label != .checkmark)
    #expect(label != .disclosureIndicator)
  }

  @Test
  func labelHashesDifferForDifferentText() {
    let a = ListAccessory.label(text: "A")
    let b = ListAccessory.label(text: "B")
    #expect(a.hashValue != b.hashValue)
  }

  @Test
  func labelHashesMatchForSameText() {
    let a = ListAccessory.label(text: "Same")
    let b = ListAccessory.label(text: "Same")
    #expect(a.hashValue == b.hashValue)
  }

  @Test
  func labelUIAccessoryProducesLabel() {
    let accessory = ListAccessory.label(text: "42")
    // Verify it produces a valid UICellAccessory (no crash)
    _ = accessory.uiAccessory
  }

  @Test
  func detailActionHandlerFactoryUsesDefaultKey() {
    let a = ListAccessory.detail(actionHandler: { })
    let b = ListAccessory.detail(actionHandler: { })
    // Both use the same default key, so they should be equal
    #expect(a == b)
  }

  @Test
  func detailActionHandlerFactoryCustomKeysCompare() {
    let a = ListAccessory.detail(actionHandler: { }, key: "key-1")
    let b = ListAccessory.detail(actionHandler: { }, key: "key-2")
    // Different keys → not equal
    #expect(a != b)
  }

  @Test
  func detailActionHandlerNotEqualToPlainDetail() {
    let action = ListAccessory.detail(actionHandler: { })
    let plain = ListAccessory.detail
    // .custom(_, key:) vs .detail are different cases
    #expect(action != plain)
  }

  @Test
  func simpleCasesEquality() {
    #expect(ListAccessory.disclosureIndicator == .disclosureIndicator)
    #expect(ListAccessory.checkmark == .checkmark)
    #expect(ListAccessory.delete == .delete)
    #expect(ListAccessory.reorder == .reorder)
    #expect(ListAccessory.outlineDisclosure == .outlineDisclosure)
    #expect(ListAccessory.detail == .detail)
    #expect(ListAccessory.multiselect == .multiselect)
  }

  @Test
  func simpleCasesInequality() {
    #expect(ListAccessory.disclosureIndicator != .checkmark)
    #expect(ListAccessory.delete != .reorder)
    #expect(ListAccessory.detail != .outlineDisclosure)
    #expect(ListAccessory.multiselect != .checkmark)
    #expect(ListAccessory.multiselect != .detail)
  }

  @Test
  func multiselectUIAccessoryProducesAccessory() {
    let accessory = ListAccessory.multiselect
    // Verify it produces a valid UICellAccessory (no crash)
    _ = accessory.uiAccessory
  }

  @Test
  func multiselectEqualToItself() {
    #expect(ListAccessory.multiselect == .multiselect)
    #expect(ListAccessory.multiselect.hashValue == ListAccessory.multiselect.hashValue)
  }

  @Test
  func popUpMenuDefaultKeyEquality() {
    let menu1 = UIMenu(children: [UIAction(title: "A") { _ in }])
    let menu2 = UIMenu(children: [UIAction(title: "B") { _ in }])
    let a = ListAccessory.popUpMenu(menu1)
    let b = ListAccessory.popUpMenu(menu2)
    // Both use the default key, so they are equal
    #expect(a == b)
  }

  @Test
  func popUpMenuCustomKeyInequality() {
    let menu1 = UIMenu(children: [UIAction(title: "A") { _ in }])
    let menu2 = UIMenu(children: [UIAction(title: "B") { _ in }])
    let a = ListAccessory.popUpMenu(menu1, key: "menu-a")
    let b = ListAccessory.popUpMenu(menu2, key: "menu-b")
    // Different keys → not equal
    #expect(a != b)
  }

  @Test
  func popUpMenuCustomKeySameKeyEquality() {
    let menu1 = UIMenu(children: [UIAction(title: "X") { _ in }])
    let menu2 = UIMenu(children: [UIAction(title: "Y") { _ in }])
    let a = ListAccessory.popUpMenu(menu1, key: "shared")
    let b = ListAccessory.popUpMenu(menu2, key: "shared")
    #expect(a == b)
  }

  @Test
  func popUpMenuNotEqualToOtherCases() {
    let menu = UIMenu(children: [])
    let popup = ListAccessory.popUpMenu(menu)
    #expect(popup != .detail)
    #expect(popup != .checkmark)
    #expect(popup != .multiselect)
  }

  @Test
  func popUpMenuUIAccessoryProducesAccessory() {
    let menu = UIMenu(children: [UIAction(title: "Test") { _ in }])
    let accessory = ListAccessory.popUpMenu(menu)
    // Verify it produces a valid UICellAccessory (no crash)
    _ = accessory.uiAccessory
  }

  @Test
  func popUpMenuHashConsistency() {
    let menu = UIMenu(children: [])
    let a = ListAccessory.popUpMenu(menu)
    let b = ListAccessory.popUpMenu(menu)
    #expect(a.hashValue == b.hashValue)
  }

  @Test
  func popUpMenuCustomKeyHashDiffers() {
    let menu = UIMenu(children: [])
    let a = ListAccessory.popUpMenu(menu, key: "key-1")
    let b = ListAccessory.popUpMenu(menu, key: "key-2")
    #expect(a.hashValue != b.hashValue)
  }

  @Test
  func canBeUsedInSet() {
    let set: Set<ListAccessory> = [
      .disclosureIndicator,
      .checkmark,
      .label(text: "A"),
      .label(text: "B"),
      .detail,
      .multiselect,
    ]
    #expect(set.count == 6)
    #expect(set.contains(.label(text: "A")))
    #expect(!set.contains(.label(text: "C")))
    #expect(set.contains(.multiselect))
  }

  @Test
  func canBeUsedInSetWithPopUpMenu() {
    let menu = UIMenu(children: [])
    let set: Set<ListAccessory> = [
      .disclosureIndicator,
      .popUpMenu(menu),
      .multiselect,
    ]
    #expect(set.count == 3)
  }
}
