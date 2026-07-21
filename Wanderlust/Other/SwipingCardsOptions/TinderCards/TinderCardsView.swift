//
//  TinderCardsView.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 12/17/24.
//
// https://medium.com/@jaredcassoutt/creating-tinder-like-swipeable-cards-in-swiftui-193fab1427b8

import SwiftUI

struct TinderCardsView: View {
    var body: some View {
        VStack {
            let cards = [
                CardView.Model(text: "Card 1"),
                CardView.Model(text: "Card 2"),
                CardView.Model(text: "Card 3"),
                CardView.Model(text: "Card 4")
            ]

            let model = SwipeableCardsView.Model(cards: cards)
            SwipeableCardsView(model: model) { model in
                print(model.swipedCards)
                model.reset()
            }
        }
        .padding()
    }
}
