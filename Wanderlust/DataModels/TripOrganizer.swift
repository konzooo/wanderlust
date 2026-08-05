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
    func generateTripSummary(profile: TravellerProfileSnapshot? = nil) -> String {
        // 1. Compute the numeric month index
        //    (so that January = 1, February = 2, etc.)
        let monthIndex = Month.all.firstIndex(of: tripDetails.month) ?? 0

        // 2. Start building the summary
        var summary = """
        Basic Information:
        - Destination: \(tripDetails.destination.name)
        - Travel Mode: \(tripDetails.members.groupType.rawValue.capitalized)
        - Number of Days: \(tripDetails.duration)
        - Start Month: \(monthIndex + 1)
        """

        // 3. Add group specification details if available
        if tripDetails.members.avgAge != nil || tripDetails.members.gender != nil || tripDetails.members.customizations != nil {
            summary += "\n\nGroup Specification:"
            
            if let avgAge = tripDetails.members.avgAge {
                summary += "\n- Average Age: \(avgAge)"
            }
            
            if let gender = tripDetails.members.gender {
                summary += "\n- Gender: \(gender.rawValue.capitalized)"
            }
            
            if let customizations = tripDetails.members.customizations, !customizations.isEmpty {
                summary += "\n- Extra details: \(customizations)"
            }
        }

        summary += "\n\nPreferences:"

        // 4. Append each questionnaire answer by question ID
        for step in questionaireList {
            // If no response is given yet, show "N/A" or some placeholder
            let responseString = step.response?.rawValue.capitalized ?? "N/A"

            // Here, `step.id` is the question number in your default data
            summary += "\nQuestion \(step.id): \(responseString)"
        }

        if let profile {
            summary += "\n\nTraveller DNA (persistent fallback context):"
            summary += profile.promptSummary
        }

        print("\n ---- SUMMARY: ---- \n\(summary)")
        return summary
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
    var basicInfoEventProperties: [String: AnalyticsValue] {
        var properties: [String: AnalyticsValue] = [
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
            "profile_usage": .string(selectedProfileID == nil ? "none" : "selected")
        ]

        if let destination = AnalyticsSanitizer.destination(tripDetails.destination.name) {
            properties["destination"] = .string(destination)
        }
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
