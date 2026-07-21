//
//  Card.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 1/30/25.
//

struct Card: Identifiable, Equatable, Hashable {
    let step: QuestionaireStep

    var id: String {
        step.id
    }
    
    var image: String {
        step.image
    }

    var leftText: String {
        step.answers[.left] ?? "no left text? o.O"
    }

    var rightText: String {
        step.answers[.right] ?? "no right text? o.O"
    }

    var middleText: String {
        step.answers[.both] ?? "no middle text? o.O"
    }
}
