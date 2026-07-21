//
//  CleanTopInsetsModifier.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 4/19/25.
//

import SwiftUI

struct CleanTopInsetsModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
    }
}

public extension View {
    func cleanTopInsets() -> some View {
        self.modifier(CleanTopInsetsModifier())
    }
}
