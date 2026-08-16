//
//  ErrorView.swift
//  DesignSystem
//
//  Created by Rodrigo Mato Castellano
//

import Foundation
import SwiftUI

/// Shown when generating the itinerary fails.
/// • The *Retry* button is always visible.
/// • After a failed retry a *Restart* button fades-in, letting the user go back to the very first screen.
public struct RetryErrorView: View {
    /// bind from the parent so the parent can bump it on every retry attempt
    @Binding var retryCount: Int
    
    /// call the store again
    let retryAction: () -> Void
    /// wipes the navigation stack
    let restartAction: () -> Void
    /// Specific, actionable copy supplied by the feature that owns the error.
    let message: String
    
    public init(
        retryCount: Binding<Int>,
        message: String = "We couldn’t finish building your itinerary.\nPlease try again.",
        retryAction: @escaping () -> Void,
        restartAction: @escaping () -> Void
    ) {
        self._retryCount   = retryCount
        self.message = message
        self.retryAction = retryAction
        self.restartAction = restartAction
    }
    
    public var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // –– Illustration
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 86)
                .foregroundColor(.appTint)
                .padding()
            
            // –– Copy
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.kanitMedium(22))
                    .foregroundColor(.appTint)
                
                Text(message)
                    .font(.kanit(16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black.opacity(0.7))
            }
            .padding(.horizontal, .Padding.sm2)
            
            // –– Actions
            VStack(spacing: 12) {
                Button("Retry", action: retryAction)
                    .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                
                if retryCount >= 1 {
                    Button("Restart", action: restartAction)
                        .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.spring(), value: retryCount)
                }
            }
            .padding(.horizontal, .Padding.md)
            
            Spacer(minLength: 40)
        }
        .gradientBackground()     // your existing helper
        .ignoresSafeArea()
    }
}

#Preview {
    RetryErrorView(retryCount: Binding<Int>(get: { 2 }, set: { _ in })) {
        
    } restartAction: {
        
    }
}
