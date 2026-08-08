//
//  HomeStore.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 1/6/25.
//

import CoreArchitecture
import CoreModels
import Foundation

class BasicInfoStore: ObservableStore {
    init () {}
    @Published var state: State = State()

    func send(_ action: Action) {
        switch action {
        case .continue:
            TripOrganizer.shared.tripDetails = state.details

        case let .saveGroupSpecification(averageAge, gender, description):
            state.groupSpecification = .init(
                groupType: state.groupSpecification.groupType,
                avgAge: averageAge,
                gender: gender,
                customizations: description
            )
        }
    }
}

extension BasicInfoStore {
    struct State: Hashable, Equatable, KeyPathMutable {
        var presentSpecifySheet: Bool = false
        var destination: String = ""
        var duration: Float = 1
        var month: Month = Self.currentMonth
        var groupSpecification: Trip.Details.Members = .init(groupType: .solo)

        var readyToContinue: Bool {
            !destination.isEmpty && duration > 0
        }

        /// The slider and its label must resolve to the same integer. Truncating
        /// a floating-point value such as 1.999 displayed "2 days" but sent 1.
        var durationDays: Int {
            Int(round(duration))
        }

        var durationText: String {
            let daysString = durationDays == 1 ? "day" : "days"
            return "\(durationDays) \(daysString)"
        }

        var specifyGroupText: String {
            groupSpecified ? "customized" : "customize"
        }

        var groupSpecified: Bool {
            groupSpecification.avgAge != nil ||
            groupSpecification.gender != nil ||
            groupSpecification.customizations != nil
        }

        var details: Trip.Details {
            Trip.Details(
                destination: .init(name: destination),
                members: groupSpecification,
                duration: durationDays,
                month: month
            )
        }
        
        static var currentMonth: Month {
            let currentMonthIndex = Calendar.current.component(.month, from: Date()) - 1 // Calendar months are 1-based
            let monthIndex = max(0, min(currentMonthIndex, Month.all.count - 1)) // Ensure valid range
            return Month.all[monthIndex]
        }
    }

    enum Action: Equatable {
        case `continue`
        case saveGroupSpecification(Int?, Trip.Details.Gender?, String?)
    }
}
