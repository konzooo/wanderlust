//
//  WanderlustUITests.swift
//  WanderlustUITests
//
//  Created by Rodrigo Mato Castellano on 10/4/24.
//

import XCTest

final class WanderlustUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testTravellerDNAEntryFromNewTrip() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing-reset-profiles")
        app.launch()

        let lisbonSuggestion = app.buttons["Lisbon"]
        XCTAssertTrue(lisbonSuggestion.waitForExistence(timeout: 5))
        lisbonSuggestion.tap()

        let profileButton = app.buttons["profile-selection-button"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 3))
        profileButton.tap()

        let introCTA = app.buttons["Create my Traveller DNA"]
        XCTAssertTrue(introCTA.waitForExistence(timeout: 3))
        introCTA.tap()

        let profileNameField = app.textFields["profile-name-field"]
        XCTAssertTrue(profileNameField.waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        profileNameField.typeText("Me")
        XCTAssertEqual(profileNameField.value as? String, "Me")
        profileNameField.typeText("\n")

        for _ in 0..<5 {
            let middleAnswer = app.buttons["Position 3 of 5"]
            XCTAssertTrue(middleAnswer.waitForExistence(timeout: 2))
            middleAnswer.tap()

            let nextButton = app.buttons["Next"]
            XCTAssertTrue(nextButton.waitForExistence(timeout: 2))
            nextButton.tap()
        }

        let skipEntryField = app.textFields["e.g. crowded viewpoints"]
        XCTAssertTrue(skipEntryField.waitForExistence(timeout: 3))
        skipEntryField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(skipEntryField.isHittable)
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
