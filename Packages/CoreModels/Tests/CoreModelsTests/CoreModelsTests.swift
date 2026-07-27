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

@Test func travellerProfileSnapshotContainsEveryScaleAndOmitsLocalIdentity() throws {
    let answers = TravellerDNADimension.allCases.map {
        ProfileScaleAnswer(dimension: $0, value: 4)
    }
    let profile = TravellerProfile(
        name: "Me",
        scaleAnswers: answers,
        usuallySkip: ["Crowded tours"],
        mustHaves: ["Morning coffee"]
    )

    #expect(profile.snapshot.hasEveryScaleAnswer)
    #expect(profile.snapshot.score(for: .structure) == 4)

    let object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(profile.snapshot))
            as? [String: Any]
    )
    #expect(object["id"] == nil)
    #expect(object["name"] == nil)
}

@Test func legacyMemberPreferencesDecodeWithoutProfile() throws {
    let data = Data(
        """
        {
          "questionnaireVersion": 1,
          "answers": [{"questionID": "1", "choice": "left"}]
        }
        """.utf8
    )

    let decoded = try JSONDecoder().decode(MemberPreferences.self, from: data)

    #expect(decoded.profile == nil)
}

@Test func archetypeUsesStrongestBehaviouralDimension() {
    let values: [TravellerDNADimension: Int] = [
        .adviceDetail: 5,
        .physicalEnergy: 3,
        .experienceBreadth: 1,
        .dayRhythm: 5,
        .structure: 4
    ]
    let profile = TravellerProfile(
        name: "Deep traveler",
        scaleAnswers: TravellerDNADimension.allCases.map {
            ProfileScaleAnswer(dimension: $0, value: values[$0] ?? 3)
        }
    )

    #expect(profile.archetype == "The Deep Diver")
}
