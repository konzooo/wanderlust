//
//  QuestionaireStep.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 1/6/25.
//

struct QuestionaireStep: Hashable, Equatable {
    let id: String

    let question: String

    /** Always a maximum size of 3, in general "both" will be not present
     ``` [
     .left : "I prefer the left option",
     .right : "I prefer right option",
     .both : "I like both options"
     ] ```
     */
    let answers: [Option: String]

    // For now hardcoded in the app (in the future maybe server stored)
    // So this string will be the name of the iamge in the app's bundle
    let image: String

    // The user response to the question
    // (nil if the user hasn't responded yet)
    var response: Option?

    init(
        id: String,
        image: String,
        question: String = "",
        answers: [Option : String] = Self.defaultAnswers,
        response: Option? = nil
    ) {
        self.id = id
        self.question = question
        self.answers = answers
        self.image = image
        self.response = response
    }

    static var defaultAnswers: [Option : String] {
        [
            .left : "Left",
            .right : "Right",
            .both : "Both"
        ]
    }
}

extension QuestionaireStep {
    enum Option: String {
        case left
        case right
        case both
    }
}

