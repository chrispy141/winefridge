//
//  WineStorageTests.swift
//  WineStorageTests
//
//  Created by Christa Porter on 8/29/26.
//

import XCTest
import SwiftData
@testable import WineFridge

final class WineStorageTests: XCTestCase {

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
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

/// Enabling CloudKit sync requires every stored `@Model` property to be
/// optional or have a default value. These tests exercise that every model
/// still round-trips correctly through a `ModelContext` when relying on
/// those defaults, so a regression here would show up before it reaches
/// CloudKit's schema validation.
@MainActor
final class PersistenceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Storage.self, Bottle.self, Shelf.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testBottleSurvivesRoundTripUsingSchemaDefaults() throws {
        // Only `name` is provided; every other stored property must fall
        // back to its schema-level default rather than crash or decode to
        // garbage, since CloudKit can omit fields when merging records.
        let bottle = Bottle(name: "Barolo")
        context.insert(bottle)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Bottle>())
        XCTAssertEqual(fetched.count, 1)
        let saved = fetched[0]
        XCTAssertEqual(saved.name, "Barolo")
        XCTAssertEqual(saved.producer, "")
        XCTAssertEqual(saved.wineType, .red)
        XCTAssertNil(saved.vintage)
        XCTAssertEqual(saved.region, "")
        XCTAssertEqual(saved.notes, "")
        XCTAssertNil(saved.slot)
    }

    func testStorageAndShelfSurviveRoundTripUsingSchemaDefaults() throws {
        let storage = Storage(name: "Cellar", position: 0)
        context.insert(storage)
        Shelf.seedDefaults(in: context, storageID: storage.storageID)
        try context.save()

        let storages = try context.fetch(FetchDescriptor<Storage>())
        XCTAssertEqual(storages.count, 1)
        XCTAssertEqual(storages[0].displayIcon, .tall)

        let shelves = try context.fetch(FetchDescriptor<Shelf>())
        XCTAssertEqual(shelves.count, 7)
        XCTAssertTrue(shelves.allSatisfy { $0.storageID == storage.storageID })
    }

    func testBottleSlotAssignmentRoundTrips() throws {
        let storage = Storage(name: "Cellar", position: 0)
        let shelf = Shelf(position: 0, storageID: storage.storageID)
        let bottle = Bottle(name: "Chablis", slot: SlotID(shelfID: shelf.shelfID, row: 1, column: 2))
        context.insert(storage)
        context.insert(shelf)
        context.insert(bottle)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<Bottle>()).first)
        XCTAssertEqual(fetched.slot, SlotID(shelfID: shelf.shelfID, row: 1, column: 2))

        fetched.clearSlot()
        XCTAssertNil(fetched.slot)
    }
}
