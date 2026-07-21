//
//  First Screen - Main info.swift
//  Wanderlust
//
//  Created by Konstantin Kaschub on 21.12.24.
//

import SwiftUI

struct InputBasicInfoView: View {
    @StateObject private var viewModel = GPTManager()
    @State private var destination = ""  // For user input in the "Where are you going?" field
    @State private var selectedTravelMode = "Solo" // For the travel mode selection
    @State private var selectedDays: Int = 1  // Slider for selecting number of days
    @State private var selectedSeason = "Spring"  // For time of the year selection
    
    let travelModes = ["Solo", "Couple", "Group"]
    let seasons = ["Spring", "Summer", "Autumn", "Winter"]
    let normalBlue = Color.blue
    let sliderValues = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 20, 30, 60, 90]
    
    func displayText(for value: Int) -> String {
        if value == 1 {
            return "1 day"
        } else {
            return "\(value) days"
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Top Header with Hamburger Menu and Title
                HStack {
                    Button(action: {
                        print("Hamburger Menu Tapped")
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.title)
                            .foregroundColor(normalBlue)
                    }
                    Spacer()
                }
                .padding(.top)
                
                // Title
                Text("Your next trip")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(normalBlue)
                    .padding(.top, 10)
                
                // "Where are you going?" TextField
                VStack(alignment: .leading) {
                    Text("Where are you going?")
                        .font(.headline)
                        .italic()
                    TextField("e.g. Barcelona", text: $destination)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.top, 30)
                
                // Travel Mode Picker
                VStack(alignment: .leading) {
                    Text("How are you travelling?")
                        .font(.headline)
                        .italic()
                    Picker("Travel Mode", selection: $selectedTravelMode) {
                        ForEach(travelModes, id: \.self) { mode in
                            Text(mode).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .background(normalBlue.opacity(0.2))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Days Slider
                VStack(alignment: .leading) {
                    Text("How many days?")
                        .font(.headline)
                        .italic()
                    Slider(value: Binding(
                        get: {
                            Double(sliderValues.firstIndex(of: selectedDays) ?? 0)
                        },
                        set: { newIndex in
                            selectedDays = sliderValues[Int(newIndex)]
                        }
                    ), in: 0...Double(sliderValues.count - 1), step: 1)
                        .accentColor(normalBlue)
                    
                    Text(displayText(for: selectedDays))
                        .foregroundColor(normalBlue)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Season Picker
                VStack(alignment: .leading) {
                    Text("Time of the year?")
                        .font(.headline)
                        .italic()
                    Picker("Season", selection: $selectedSeason) {
                        ForEach(seasons, id: \.self) { season in
                            Text(season).tag(season)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .background(normalBlue.opacity(0.2))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
                
                // NavigationLink to InputView with GPTManager
                NavigationLink(
                    destination: InputView(viewModel: viewModel)
                ) {
                    Text("Let's go →")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(normalBlue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .font(.custom("Kanit", size: 18))
            .navigationTitle("")
        }
    }
}

struct InputBasicInfoView_Previews: PreviewProvider {
    static var previews: some View {
        InputBasicInfoView()
    }
}
