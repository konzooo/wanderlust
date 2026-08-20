import CoreArchitecture
import CoreModels
import Foundation

class TripOrganizer: ObservableObject {
    static let shared = TripOrganizer()
    private init() {}

    var tripDetails: Trip.Details = Trip.Details()
    @Published var selectedProfileID: UUID?
    private(set) var questionaireList: [QuestionaireStep] = TripOrganizer.defaultQuestionaire
}

extension TripOrganizer {
    func set(response: QuestionaireStep.Option, for step: QuestionaireStep) {
        guard let index = questionaireList.firstIndex(of: step) else { return }
        questionaireList[index].response = response
    }

    func addStep(_ step: QuestionaireStep) {
        questionaireList.append(step)
    }
    
    func clear(_ step: QuestionaireStep) {
        guard let index = questionaireList.firstIndex(of: step) else { return }
        questionaireList[index].response = nil
    }
    
    func undoLastStep() {
        // Find the last step with a recorded response
        if let lastAnsweredIndex = questionaireList.lastIndex(where: { $0.response != nil }) {
            questionaireList[lastAnsweredIndex].response = nil
        }
    }
}

extension TripOrganizer {
    static var defaultQuestionaire: [QuestionaireStep] =
    [
        QuestionaireStep(
            id: "1",
            image: "Card1"
        ),
        QuestionaireStep(
            id: "2",
            image: "Card2"
        ),
        QuestionaireStep(
            id: "3",
            image: "Card3"
        ),
        QuestionaireStep(
            id: "4",
            image: "Card4"
        ),
        QuestionaireStep(
            id: "5",
            image: "Card5"
        ),
        QuestionaireStep(
            id: "6",
            image: "Card6"
        ),
        QuestionaireStep(
            id: "7",
            image: "Card7"
        ),
//        QuestionaireStep(
//            id: "8",
//            question: "What's your style?",
//            image: "TB - on a budget or happy to spend"
//        )
    ]
}

extension TripOrganizer {
    /// The structured inputs the backend needs to generate this trip.
    ///
    /// Replaces the old prose trip summary. The app used to flatten these
    /// answers into a paragraph and hand it to the model, which made the app a
    /// co-author of the prompt; now it hands over data and the backend writes
    /// every word the model reads.
    func generationInput(profile: TravellerProfileSnapshot? = nil) -> TripGenerationInput {
        let answers: [PreferenceAnswer] = questionaireList.compactMap { step in
            guard let response = step.response,
                  let choice = PreferenceChoice(rawValue: response.rawValue)
            else { return nil }
            return PreferenceAnswer(questionID: step.id, choice: choice)
        }
        return TripGenerationInput(
            details: tripDetails,
            answers: answers,
            profile: profile
        )
    }
}

extension Array where Element == QuestionaireStep {
    func prettyPrint() {
        print("=== Questionnaire Steps ===")

        for step in self {
            print("Step ID: \(step.id)")

            print("Possible answers:")
            for (option, text) in step.answers {
                print("  - \(option.rawValue.capitalized): \(text)")
            }

            if let response = step.response {
                print("Response: \(response.rawValue.capitalized)")
            } else {
                print("Response: (none)")
            }

            print("---------------------------")
        }
    }
}

// MARK: - Analytics Event

extension TripOrganizer {
    @MainActor
    var basicInfoEventProperties: [String: AnalyticsValue] {
        let properties: [String: AnalyticsValue] = [
            "duration_days": .integer(tripDetails.duration),
            "start_month": .string(tripDetails.month.rawValue.lowercased()),
            "party_type": .string(tripDetails.members.groupType.rawValue),
            "party_age_bucket": .string(
                AnalyticsSanitizer.ageBucket(tripDetails.members.avgAge)
            ),
            "party_gender": .string(tripDetails.members.gender?.rawValue ?? "unknown"),
            "has_custom_notes": .boolean(
                !(tripDetails.members.customizations?
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            ),
            "profile_usage": .string(selectedProfileID == nil ? "none" : "selected"),
            "profile_count": .integer(TravellerProfileLibrary.shared.profiles.count),
            "profile_attachment_source": .string(
                TravellerProfileLibrary.shared.analyticsAttachmentSource(
                    for: selectedProfileID
                )
            )
        ]
        return properties
    }

    var questionnaireEventProperties: [String: AnalyticsValue] {
        questionaireList.reduce(into: [:]) { properties, step in
            guard let response = step.response else { return }
            let paddedID = step.id.count == 1 ? "0\(step.id)" : step.id
            properties["q\(paddedID)_choice"] = .string(response.rawValue)
        }
    }
}
