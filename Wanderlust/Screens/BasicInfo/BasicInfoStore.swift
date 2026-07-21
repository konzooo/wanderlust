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

        var durationText: String {
            let roundedDuration = Int(round(duration))
            let daysString = roundedDuration == 1 ? "day" : "days"
            return "\(roundedDuration) \(daysString)"
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
                duration: Int(duration),
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
