//
//  WanderlustTests.swift
//  WanderlustTests
//
//  Created by Rodrigo Mato Castellano on 10/4/24.
//

import XCTest
import CoreModels
@testable import Wanderlust

final class WanderlustTests: XCTestCase {

    @MainActor
    func testBasicInfoDurationUsesTheValueShownToTheTraveller() {
        var state = BasicInfoStore.State()
        state.duration = 1.999

        XCTAssertEqual(state.durationText, "2 days")
        XCTAssertEqual(state.durationDays, 2)
        XCTAssertEqual(state.details.duration, 2)
    }

    @MainActor
    func testGroupDurationUsesTheValueShownToTheTraveller() {
        var state = GroupTripCreateStore.State()
        state.duration = 1.999

        XCTAssertEqual(state.durationText, "2 days")
        XCTAssertEqual(state.durationDays, 2)
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

    @MainActor
    func testProfileLibraryMaintainsMainAndDefaultInvariants() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = TravellerProfileLibrary(
            fileURL: directory.appendingPathComponent("profiles.json")
        )

        let first = makeProfile(name: "Me")
        let second = makeProfile(name: "Family")
        try library.save(first)
        try library.save(second)

        XCTAssertEqual(library.mainProfileID, first.id)
        XCTAssertTrue(library.attachByDefault)

        library.makeMain(second.id)
        library.delete(second.id)
        XCTAssertEqual(library.mainProfileID, first.id)

        library.delete(first.id)
        XCTAssertNil(library.mainProfileID)
        XCTAssertFalse(library.attachByDefault)
    }

    @MainActor
    func testProfileLibraryRejectsDuplicateNames() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = TravellerProfileLibrary(
            fileURL: directory.appendingPathComponent("profiles.json")
        )

        try library.save(makeProfile(name: "Me"))
        XCTAssertThrowsError(try library.save(makeProfile(name: "me")))
    }

    private func makeProfile(name: String) -> TravellerProfile {
        TravellerProfile(
            name: name,
            scaleAnswers: TravellerDNADimension.allCases.map {
                ProfileScaleAnswer(dimension: $0, value: 3)
            }
        )
    }

}
