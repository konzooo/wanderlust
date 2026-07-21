//
//  View+ConditionalModifier.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 4/24/25.
//

import SwiftUI

public extension View {
    /// Applies `transform` only when `condition` is `true`.
    @ViewBuilder
    func conditional<Transformed: View>(
        _ condition: Bool,
        @ViewBuilder transform: (Self) -> Transformed
    ) -> some View {
        if condition {
            transform(self)          // <-- modifier(s) when true
        } else {
            self                     // <-- unchanged view when false
        }
    }
}
