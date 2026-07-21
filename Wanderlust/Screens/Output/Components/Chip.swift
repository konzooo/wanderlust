//
//  Chip.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 10/6/25.
//

import SwiftUI

struct Chip: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.kanitLight(16))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 0)
            .background(.thinMaterial.opacity(0.5), in: Capsule())
    }
}
