// ABOUTME: Tests for ListAccessory enum: equality, hashing, and UICellAccessory production.
// ABOUTME: Covers all cases: label, badge, toggle, image, progress, popUpMenu, and more.
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

  @Test
  func toggleEqualityWithSameState() {
    let a = ListAccessory.toggle(isOn: true) { _ in }
    let b = ListAccessory.toggle(isOn: true) { _ in }
    #expect(a == b)
  }

  @Test
  func toggleInequalityWithDifferentState() {
    let a = ListAccessory.toggle(isOn: true) { _ in }
    let b = ListAccessory.toggle(isOn: false) { _ in }
    #expect(a != b)
  }

  @Test
  func toggleInequalityWithDifferentKeys() {
    let a = ListAccessory.toggle(isOn: true, key: "a") { _ in }
    let b = ListAccessory.toggle(isOn: true, key: "b") { _ in }
    #expect(a != b)
  }

  @Test
  func toggleHashesMatchForSameState() {
    let a = ListAccessory.toggle(isOn: false) { _ in }
    let b = ListAccessory.toggle(isOn: false) { _ in }
    #expect(a.hashValue == b.hashValue)
  }

  @Test
  func toggleHashesDifferForDifferentState() {
    let a = ListAccessory.toggle(isOn: true) { _ in }
    let b = ListAccessory.toggle(isOn: false) { _ in }
    #expect(a.hashValue != b.hashValue)
  }

  @Test
  func toggleNotEqualToOtherCases() {
    let toggle = ListAccessory.toggle(isOn: true) { _ in }
    #expect(toggle != .checkmark)
    #expect(toggle != .detail)
    #expect(toggle != .activityIndicator)
  }

  @Test
  func toggleUIAccessoryProducesAccessory() {
    let accessory = ListAccessory.toggle(isOn: true) { _ in }
    _ = accessory.uiAccessory
  }

  @Test
  func badgeEqualityWithSameText() {
    let a = ListAccessory.badge("3")
    let b = ListAccessory.badge("3")
    #expect(a == b)
  }

  @Test
  func badgeInequalityWithDifferentText() {
    let a = ListAccessory.badge("3")
    let b = ListAccessory.badge("99")
    #expect(a != b)
  }

  @Test
  func badgeHashesMatchForSameText() {
    let a = ListAccessory.badge("New")
    let b = ListAccessory.badge("New")
    #expect(a.hashValue == b.hashValue)
  }

  @Test
  func badgeHashesDifferForDifferentText() {
    let a = ListAccessory.badge("A")
    let b = ListAccessory.badge("B")
    #expect(a.hashValue != b.hashValue)
  }

  @Test
  func badgeNotEqualToOtherCases() {
    let badge = ListAccessory.badge("1")
    #expect(badge != .checkmark)
    #expect(badge != .label(text: "1"))
  }

  @Test
  func badgeUIAccessoryProducesAccessory() {
    let accessory = ListAccessory.badge("42")
    _ = accessory.uiAccessory
  }

  @Test
  func imageEqualityWithSameName() {
    let a = ListAccessory.image(systemName: "star")
    let b = ListAccessory.image(systemName: "star")
    #expect(a == b)
  }

  @Test
  func imageInequalityWithDifferentName() {
    let a = ListAccessory.image(systemName: "star")
    let b = ListAccessory.image(systemName: "heart")
    #expect(a != b)
  }

  @Test
  func imageHashesMatchForSameName() {
    let a = ListAccessory.image(systemName: "star")
    let b = ListAccessory.image(systemName: "star")
    #expect(a.hashValue == b.hashValue)
  }

  @Test
  func imageHashesDifferForDifferentName() {
    let a = ListAccessory.image(systemName: "star")
    let b = ListAccessory.image(systemName: "heart")
    #expect(a.hashValue != b.hashValue)
  }

  @Test
  func imageNotEqualToOtherCases() {
    let image = ListAccessory.image(systemName: "star")
    #expect(image != .checkmark)
    #expect(image != .detail)
  }

  @Test
  func imageUIAccessoryProducesAccessory() {
    let accessory = ListAccessory.image(systemName: "chevron.right")
    _ = accessory.uiAccessory
  }

  @Test
  func progressEqualityWithSameValue() {
    let a = ListAccessory.progress(0.5)
    let b = ListAccessory.progress(0.5)
    #expect(a == b)
  }

  @Test
  func progressInequalityWithDifferentValue() {
    let a = ListAccessory.progress(0.25)
    let b = ListAccessory.progress(0.75)
    #expect(a != b)
  }

  @Test
  func progressHashesMatchForSameValue() {
    let a = ListAccessory.progress(0.5)
    let b = ListAccessory.progress(0.5)
    #expect(a.hashValue == b.hashValue)
  }

  @Test
  func progressHashesDifferForDifferentValue() {
    let a = ListAccessory.progress(0.0)
    let b = ListAccessory.progress(1.0)
    #expect(a.hashValue != b.hashValue)
  }

  @Test
  func progressNotEqualToOtherCases() {
    let progress = ListAccessory.progress(0.5)
    #expect(progress != .checkmark)
    #expect(progress != .activityIndicator)
  }

  @Test
  func progressUIAccessoryProducesAccessory() {
    let accessory = ListAccessory.progress(0.75)
    _ = accessory.uiAccessory
  }

  @Test
  func activityIndicatorEquality() {
    #expect(ListAccessory.activityIndicator == .activityIndicator)
  }

  @Test
  func activityIndicatorHashConsistency() {
    #expect(ListAccessory.activityIndicator.hashValue == ListAccessory.activityIndicator.hashValue)
  }

  @Test
  func activityIndicatorNotEqualToOtherCases() {
    #expect(ListAccessory.activityIndicator != .checkmark)
    #expect(ListAccessory.activityIndicator != .detail)
    #expect(ListAccessory.activityIndicator != .progress(1.0))
  }

  @Test
  func activityIndicatorUIAccessoryProducesAccessory() {
    let accessory = ListAccessory.activityIndicator
    _ = accessory.uiAccessory
  }

  @Test
  func canBeUsedInSetWithNewCases() {
    let set: Set<ListAccessory> = [
      .disclosureIndicator,
      .badge("3"),
      .badge("5"),
      .image(systemName: "star"),
      .progress(0.5),
      .activityIndicator,
      .toggle(isOn: true) { _ in },
      .toggle(isOn: false) { _ in },
    ]
    #expect(set.count == 8)
    #expect(set.contains(.badge("3")))
    #expect(!set.contains(.badge("99")))
    #expect(set.contains(.activityIndicator))
    #expect(set.contains(.toggle(isOn: true) { _ in }))
    #expect(set.contains(.toggle(isOn: false) { _ in }))
  }

  @Test
  func toggleEqualityIgnoresOnChangeClosure() {
    var capturedA = false
    var capturedB = false
    let a = ListAccessory.toggle(isOn: true) { capturedA = $0 }
    let b = ListAccessory.toggle(isOn: true) { capturedB = $0 }
    // Different closures, same isOn/key → equal
    #expect(a == b)
    _ = capturedA
    _ = capturedB
  }

  @Test
  func progressBoundaryValues() {
    let zero = ListAccessory.progress(0.0)
    let one = ListAccessory.progress(1.0)
    #expect(zero == .progress(0.0))
    #expect(one == .progress(1.0))
    #expect(zero != one)
    _ = zero.uiAccessory
    _ = one.uiAccessory
  }

  @Test
  func badgeWithEmptyString() {
    let empty = ListAccessory.badge("")
    #expect(empty == .badge(""))
    #expect(empty != .badge("x"))
    _ = empty.uiAccessory
  }
}
