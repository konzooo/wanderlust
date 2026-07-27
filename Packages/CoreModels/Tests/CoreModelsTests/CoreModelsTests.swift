import Foundation
import Testing
@testable import CoreModels

@Test func legacyTripWithoutShareCodeDecodesToNil() throws {
    let trip = Trip(
        details: .mock,
        itinerary: .mock,
        suggestions: .mock
    )
    let encoded = try JSONEncoder().encode(trip)
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object.removeValue(forKey: "shareCode")
    let legacyData = try JSONSerialization.data(withJSONObject: object)

    let decoded = try JSONDecoder().decode(Trip.self, from: legacyData)

    #expect(decoded.shareCode == nil)
}

@Test func tripShareCodeRoundTrips() throws {
    let shareCode = "cdf789e97451477d877228bfa7928bb1"
    let trip = Trip(
        details: .mock,
        itinerary: .mock,
        suggestions: .mock,
        shareCode: shareCode
    )

    let encoded = try JSONEncoder().encode(trip)
    let decoded = try JSONDecoder().decode(Trip.self, from: encoded)

    #expect(decoded.shareCode == shareCode)
}

@Test func unknownSuggestionCategoryIDDegradesToNil() throws {
    let data = Data(
        """
        {
          "dynamicSuggestions": [
            {
              "ID": "future-category",
              "title": "A category from a newer app",
              "texts": [{ "text": "Still useful advice" }]
            }
          ],
          "staticSuggestions": []
        }
        """.utf8
    )

    let suggestions = try JSONDecoder().decode(Trip.Suggestions.self, from: data)

    #expect(suggestions.dynamicSuggestions.count == 1)
    #expect(suggestions.dynamicSuggestions[0].ID == nil)
    #expect(suggestions.dynamicSuggestions[0].texts[0].text == "Still useful advice")
}
