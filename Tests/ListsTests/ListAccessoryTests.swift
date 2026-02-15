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
  }

  @Test
  func simpleCasesInequality() {
    #expect(ListAccessory.disclosureIndicator != .checkmark)
    #expect(ListAccessory.delete != .reorder)
    #expect(ListAccessory.detail != .outlineDisclosure)
  }

  @Test
  func canBeUsedInSet() {
    let set: Set<ListAccessory> = [
      .disclosureIndicator,
      .checkmark,
      .label(text: "A"),
      .label(text: "B"),
      .detail,
    ]
    #expect(set.count == 5)
    #expect(set.contains(.label(text: "A")))
    #expect(!set.contains(.label(text: "C")))
  }
}
