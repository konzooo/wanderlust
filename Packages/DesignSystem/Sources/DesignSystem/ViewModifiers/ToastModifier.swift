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
    let duration: TimeInterval = 3

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
                        withAnimation {
                            isPresented = false
                        }
                    }
                }
            }
        }
        .animation(.easeInOut, value: isPresented)
    }

    private var toastView: some View {
        DS.Toast(style: style, title: title, subtitle: subtitle)
            .transition(.move(edge: position == .top ? .top : .bottom))//.combined(with: .opacity))
            .padding(.top, position == .top ? 16 : 0)
            .padding(.bottom, position == .bottom ? 16 : 0)
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
