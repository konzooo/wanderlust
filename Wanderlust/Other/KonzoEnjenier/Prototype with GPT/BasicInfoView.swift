//
//  BasicInfoView.swift
//  Wanderlust
//
//  Created by Konstantin Kaschub on 10.01.25.
//
import SwiftUI

struct BasicInfoView: View {
    @ObservedObject var viewModel: UserInputViewModel
    
    let travelModes = ["Solo", "Couple", "Group", "Family"]
    let sliderValues = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 20, 30, 60, 90]
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    
    @State private var showSheet = false
    @State private var specified = false
    @State private var age: String = ""
    @State private var selectedGender = "men"
    @State private var customText = ""//
    
    let buttonPurple = Color(red: 0.5, green: 0.3, blue: 0.9)
    let buttonPurpleOpacity = Color(red: 0.5, green: 0.3, blue: 0.9, opacity: 0.3)
    let lightGrey = Color.gray.opacity(0.2)
    
    func displayText(for value: Int) -> String {
        value == 1 ? "1 day" : "\(value) days"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                HStack {
                    Button(action: {
                        print("Hamburger Menu Tapped")
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.title)
                            .foregroundColor(buttonPurple)
                    }
                    Spacer()
                }
                .padding(.top)
                
                Text("Your next trip")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                VStack(alignment: .leading) {
                    Text("Where are you going?")
                        .font(.headline)
                        .italic()
                    TextField("e.g. Barcelona", text: $viewModel.destination)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .italic()
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading) {
                    Text("Who are you travelling with?")
                        .font(.headline)
                        .italic()
                    Picker("Travel Mode", selection: $viewModel.travelMode) {
                        ForEach(travelModes, id: \.self) { mode in
                            Text(mode).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .accentColor(buttonPurple)
                }
                .padding(.horizontal)
                
                HStack {
                    Spacer()
                    Button(action: { showSheet.toggle() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "pencil")
                            Text(specified ? "Specified" : "Specify")
                        }
                        .foregroundColor(specified ? .white : buttonPurple)
                        .padding(6)
                        .background(specified ? buttonPurpleOpacity : Color.clear)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(buttonPurple, lineWidth: specified ? 0 : 1)
                        )
                        .scaleEffect(0.6)
                    }
                }
                .padding(.horizontal)
                
                VStack(alignment: .center) {
                    Text("How many days?")
                        .font(.headline)
                        .italic()
                    
                    Slider(value: Binding(
                        get: { Double(sliderValues.firstIndex(of: viewModel.numberOfDays) ?? 0) },
                        set: { viewModel.numberOfDays = sliderValues[Int($0)] }
                    ), in: 0...Double(sliderValues.count - 1), step: 1)
                    .accentColor(buttonPurple)
                    .padding()
                    .frame(height: 10)
                    .background(lightGrey)
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(lightGrey, lineWidth: 2)
                    )
                    
                    Text(displayText(for: viewModel.numberOfDays))
                        .foregroundColor(buttonPurple)
                        .font(.system(size: 20, weight: .bold))
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading) {
                    Text("Start of your trip?")
                        .font(.headline)
                        .italic()
                    
                    Picker("Month", selection: $viewModel.startMonthIndex) {
                        ForEach(0..<months.count, id: \.self) { index in
                            Text(months[index])
                                .tag(index)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(maxHeight: 150)
                }
                .padding(.horizontal)
                
                Spacer()
                
                NavigationLink(destination: MySwipeableCardsView(viewModel: viewModel)) {
                    Text("Let's go →")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(buttonPurple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .sheet(isPresented: $showSheet) {
                SpecifyGroupViewLegacy(specified: $specified, showSheet: $showSheet, age: $age, selectedGender: $selectedGender, customText: $customText)
                    .presentationDetents([.medium])
                    .background(Color.white)
                    .clipShape(RoundedCornersShape(radius: 30, corners: [.topLeft, .topRight])) // styleeee - More rounded top corners
            }
        }
    }
}

struct SpecifyGroupViewLegacy: View { // added specify structure
    @Binding var specified: Bool
    @Binding var showSheet: Bool
    @Binding var age: String
    @Binding var selectedGender: String
    @Binding var customText: String
    
    let buttonPurple = Color(red: 0.5, green: 0.3, blue: 0.9)
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Close") {
                    showSheet = false
                }
                .foregroundColor(buttonPurple)
                Spacer()
                Button("Save") { // good to have 2 statuses clearly here
                    specified = true
                    showSheet = false
                }
                .foregroundColor(buttonPurple)
            }
            .padding()
            
            Text("Specify your group")
                .font(.headline)
                .padding(.top, -10) // ✅ Moved higher
            
            VStack(alignment: .leading) {
                Text("Average Age") // ✅ Smaller font, italic
                    .font(.subheadline)
                    .italic()
                TextField("", text: $age)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        Text(age.isEmpty ? "32" : "")
                            .foregroundColor(.gray)
                            .italic()
                            .padding(.leading, 8),
                        alignment: .leading
                    )
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading) {
                Text("Genda") // smaller font and italic - looks better
                    .font(.subheadline)
                    .italic()
                Picker("Gender", selection: $selectedGender) {
                    Text("Men").tag("men")
                    Text("Women").tag("women")
                    Text("Mixed").tag("mixed")
                }
                .pickerStyle(SegmentedPickerStyle())
                .accentColor(buttonPurple)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading) {
                Text("Custom") //  Smaller font, italic - looks better
                    .font(.subheadline)
                    .italic()
                TextField("", text: $customText)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        Text(customText.isEmpty ? "E.g: 4 girls on a bachelorette weekend" : "")
                            .foregroundColor(.gray)
                            .italic()
                            .padding(.leading, 8),
                        alignment: .leading
                    )
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

// Custom Shape for Rounded Top Corners // I feel like this gave it a better look
struct RoundedCornersShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
