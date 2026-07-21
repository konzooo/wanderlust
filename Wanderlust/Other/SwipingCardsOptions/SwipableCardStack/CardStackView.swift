//
//  CardStackView.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 12/17/24.
//

import SwiftUI

struct Card: Identifiable {
    let id = UUID()
    let color: Color
    let text: String
    let image: String? = nil
}

struct CardStackView: View {
    @State private var cards: [Card] = [
        Card(color: .red, text: "Card 1"),
        Card(color: .orange, text: "Card 2"),
        Card(color: .yellow, text: "Card 3"),
        Card(color: .green, text: "Card 4"),
        Card(color: .blue, text: "Card 5")
    ]

    var body: some View {
        ZStack {
            ForEach(cards.reversed()) { card in
                CardViewSCS(card: card, onRemove: { removedCard in
                    self.cards.removeAll { $0.id == removedCard.id }
                })
                .stacked(at: self.index(of: card), in: self.cards.count)
                .disabled(!isTopCard(card))
            }
        }
    }

    private func index(of card: Card) -> Int {
        return cards.firstIndex(where: { $0.id == card.id }) ?? 0
    }

    private func isTopCard(_ card: Card) -> Bool {
        return cards.first?.id == card.id
    }
}

extension View {
    func stacked(at position: Int, in total: Int) -> some View {
        let offset = CGFloat(position) * -10
        return self.offset(CGSize(width: offset, height: offset))
    }
}

struct CardViewSCS: View {
    let card: Card
    let onRemove: (Card) -> Void

    @State private var offset = CGSize.zero

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(card.color)
            .frame(width: 300, height: 400)
            .overlay(
                Text(card.text)
                    .font(.largeTitle)
                    .foregroundColor(.white)
            )
            .offset(x: offset.width, y: offset.height)
            .rotationEffect(Angle(degrees: Double(offset.width / 10)))
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        self.offset = gesture.translation
                    }
                    .onEnded { gesture in
                        if abs(gesture.translation.width) > 200 {
                            withAnimation {
                                self.onRemove(self.card)
                            }
                        } else {
                            self.offset = .zero
                        }
                    }
            )
            .animation(.spring(), value: offset)
    }
}

struct DemoView: View {
    var body: some View {
        CardStackView()
    }
}

#Preview {
    DemoView()
}
