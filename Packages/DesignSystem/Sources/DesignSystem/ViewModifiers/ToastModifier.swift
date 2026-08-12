//
//  ToastModifier.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 5/12/25.
//

import Foundation
import SwiftUI

struct ToastModifier: ViewModifier {
    let style: DS.Toast.Style
    let title: String
    let subtitle: String?
    @Binding var isPresented: Bool
    let position: DS.Toast.Position
    private var duration: TimeInterval { subtitle == nil ? 2.2 : 3 }

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                VStack {
                    if position == .top {
                        toastView
                        Spacer()
                    } else {
                        Spacer()
                        toastView
                    }
                }
                .zIndex(1)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        isPresented = false
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: isPresented)
    }

    private var toastView: some View {
        DS.Toast(style: style, title: title, subtitle: subtitle)
            .transition(
                .move(edge: position == .top ? .top : .bottom)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.96))
            )
            .padding(.top, position == .top ? 18 : 0)
            .padding(.bottom, position == .bottom ? 28 : 0)
    }
}

public extension View {
    func toast(style: DS.Toast.Style,
               title: String,
               subtitle: String?,
               isPresented: Binding<Bool>,
               position: DS.Toast.Position = .top) -> some View {
        self.modifier(
            ToastModifier(
                style: style,
                title: title,
                subtitle: subtitle,
                isPresented: isPresented,
                position: position
            )
        )
    }
}
