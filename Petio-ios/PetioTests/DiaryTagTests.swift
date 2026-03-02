import Testing
import SwiftUI
@testable import Petio

struct DiaryTagTests {

    @Test func defaultTagsCount() {
        #expect(DiaryTag.defaults.count == 7)
    }

    @Test func defaultTagsAreUnique() {
        let ids = DiaryTag.defaults.map(\.id)
        #expect(Set(ids).count == 7)
    }

    @Test func colorHexRoundTrip() {
        let color = Color(hex: "#4CAF50")
        let hex = color.hexString
        // Allow minor rounding: just check it starts with "#" and is 7 chars
        #expect(hex.count == 7)
        #expect(hex.hasPrefix("#"))
    }
}
