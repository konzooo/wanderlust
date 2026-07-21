//
//  UserInputViewModel.swift.swift
//  Wanderlust
//
//  Created by Konstantin Kaschub on 12.01.25.
//
import SwiftUI

class UserInputViewModel: ObservableObject {
    @Published var destination: String = ""
    @Published var travelMode: String = "Solo"
    @Published var numberOfDays: Int = 1
    @Published var startMonthIndex: Int = 2
    @Published var responses: [String] = []
}

