//
//  WinePlacementServiceTests.swift
//  WineStorageTests
//

import Testing
import Foundation
@testable import WineFridge

/// Tests for the Auto Assign placement algorithm: `WineSimilarity`,
/// `StorageDistance`, and `WinePlacementService`.
///
/// Storage in these tests is built directly with model initializers rather
/// than through a `ModelContext` — none of this logic touches persistence,
/// so plain in-memory objects (never inserted anywhere) are enough.
@Suite("Wine Placement")
struct WinePlacementServiceTests {
    // MARK: - Fixture helpers

    /// A two-row, four-column shelf, matching the app's default layout.
    private static func makeShelf(position: Int, storageID: UUID, rowSlotCounts: [Int] = [4, 4]) -> Shelf {
        Shelf(position: position, rowSlotCounts: rowSlotCounts, storageID: storageID)
    }

    private static func makeBottle(
        name: String = "",
        producer: String = "",
        wineType: WineType = .red,
        varietal: String = "",
        vintage: Int? = nil,
        country: String = "",
        region: String = "",
        appellation: String = "",
        designation: String = "",
        slot: SlotID? = nil
    ) -> Bottle {
        Bottle(
            name: name,
            producer: producer,
            wineType: wineType,
            varietal: varietal,
            vintage: vintage,
            country: country,
            region: region,
            appellation: appellation,
            designation: designation,
            slot: slot
        )
    }

    // MARK: - 1. Prefers an empty slot beside an existing similar cluster

    @Test("A new Napa Cabernet prefers a slot beside an existing Napa Cabernet cluster")
    func prefersSlotBesideSimilarCluster() {
        let storage = Storage(name: "Cellar", position: 0)
        let shelf = Self.makeShelf(position: 0, storageID: storage.storageID)

        // Row 0: [Cab] [Cab] [empty] [Chardonnay]
        let cab1 = Self.makeBottle(
            producer: "Stag's Leap", wineType: .red, varietal: "Cabernet Sauvignon",
            region: "Napa Valley", appellation: "Stags Leap District",
            slot: SlotID(shelfID: shelf.shelfID, row: 0, column: 0)
        )
        let cab2 = Self.makeBottle(
            producer: "Stag's Leap", wineType: .red, varietal: "Cabernet Sauvignon",
            region: "Napa Valley", appellation: "Stags Leap District",
            slot: SlotID(shelfID: shelf.shelfID, row: 0, column: 1)
        )
        let chardonnay = Self.makeBottle(
            wineType: .white, varietal: "Chardonnay",
            slot: SlotID(shelfID: shelf.shelfID, row: 0, column: 3)
        )
        // Row 1: [empty] [empty] [empty] [Pinot]
        let pinot = Self.makeBottle(
            wineType: .red, varietal: "Pinot Noir",
            slot: SlotID(shelfID: shelf.shelfID, row: 1, column: 3)
        )

        let newBottle = Self.makeBottle(
            producer: "Stag's Leap", wineType: .red, varietal: "Cabernet Sauvignon",
            region: "Napa Valley", appellation: "Stags Leap District"
        )

        let recommendation = WinePlacementService.findBestSlot(
            for: newBottle,
            in: storage,
            allShelves: [shelf],
            allBottles: [cab1, cab2, chardonnay, pinot]
        )

        #expect(recommendation?.slot == SlotID(shelfID: shelf.shelfID, row: 0, column: 2))
    }

    // MARK: - 2. Appellation match outranks region-only match

    @Test("A Stags Leap District Cabernet prefers nearby Stags Leap wines over equally distant unrelated Napa wines")
    func appellationMatchOutranksRegionOnlyMatch() {
        let storage = Storage(name: "Cellar", position: 0)
        let shelf = Self.makeShelf(position: 0, storageID: storage.storageID, rowSlotCounts: [5])

        // [Stags Leap Cab] [empty] [empty] [empty] [Napa Merlot, no appellation]
        let stagsLeapCab = Self.makeBottle(
            wineType: .red, varietal: "Cabernet Sauvignon",
            region: "Napa Valley", appellation: "Stags Leap District",
            slot: SlotID(shelfID: shelf.shelfID, row: 0, column: 0)
        )
        let unrelatedNapaWine = Self.makeBottle(
            wineType: .red, varietal: "Merlot",
            region: "Napa Valley",
            slot: SlotID(shelfID: shelf.shelfID, row: 0, column: 4)
        )

        let newBottle = Self.makeBottle(
            wineType: .red, varietal: "Cabernet Sauvignon",
            region: "Napa Valley", appellation: "Stags Leap District"
        )

        let recommendation = WinePlacementService.findBestSlot(
            for: newBottle,
            in: storage,
            allShelves: [shelf],
            allBottles: [stagsLeapCab, unrelatedNapaWine]
        )

        // Column 1 is one step from the Stags Leap Cab; column 3 is one step
        // from the unrelated Napa wine — equally distant from each cluster.
        #expect(recommendation?.slot == SlotID(shelfID: shelf.shelfID, row: 0, column: 1))
    }

    // MARK: - 3. Multiple matching characteristics outrank a type-only match

    @Test("Producer + grape + appellation matches outrank a Type-only match")
    func multipleCharacteristicsOutrankTypeOnly() {
        let storage = Storage(name: "Cellar", position: 0)
        let shelf = Self.makeShelf(position: 0, storageID: storage.storageID, rowSlotCounts: [5])

        let stronglyMatching = Self.makeBottle(
            producer: "Shafer", wineType: .red, varietal: "Cabernet Sauvignon",
            region: "Napa Valley", appellation: "Stags Leap District",
            slot: SlotID(shelfID: shelf.shelfID, row: 0, column: 0)
        )
        let typeOnlyMatch = Self.makeBottle(
            producer: "Some Other Winery", wineType: .red, varietal: "Zinfandel",
            region: "Paso Robles",
            slot: SlotID(shelfID: shelf.shelfID, row: 0, column: 4)
        )

        let newBottle = Self.makeBottle(
            producer: "Shafer", wineType: .red, varietal: "Cabernet Sauvignon",
            region: "Napa Valley", appellation: "Stags Leap District"
        )

        let recommendation = WinePlacementService.findBestSlot(
            for: newBottle,
            in: storage,
            allShelves: [shelf],
            allBottles: [stronglyMatching, typeOnlyMatch]
        )

        #expect(recommendation?.slot == SlotID(shelfID: shelf.shelfID, row: 0, column: 1))
    }

    // MARK: - 4. Immediate neighbor preferred when otherwise comparable

    @Test("An immediate neighbor is preferred when similarity scores are otherwise comparable")
    func immediateNeighborPreferredWhenComparable() {
        let storage = Storage(name: "Cellar", position: 0)
        let shelf = Self.makeShelf(position: 0, storageID: storage.storageID, rowSlotCounts: [5])

        // A single matching bottle, equidistant (one slot away) from two
        // empty candidates — one on the shelf's near side, one via the row
        // above, both at logical distance 1 in `StorageDistance`'s terms.
        let matchingBottle = Self.makeBottle(
            producer: "Shafer", wineType: .red, varietal: "Cabernet Sauvignon",
            slot: SlotID(shelfID: shelf.shelfID, row: 0, column: 2)
        )

        let newBottle = Self.makeBottle(
            producer: "Shafer", wineType: .red, varietal: "Cabernet Sauvignon"
        )

        let recommendation = WinePlacementService.findBestSlot(
            for: newBottle,
            in: storage,
            allShelves: [shelf],
            allBottles: [matchingBottle]
        )

        // Column 1 and column 3 are both immediate neighbors (distance 1);
        // column 1 wins the natural-order tie-break.
        #expect(recommendation?.slot == SlotID(shelfID: shelf.shelfID, row: 0, column: 1))
    }

    // MARK: - 5. A cluster can outweigh one isolated similar bottle

    @Test("Multiple nearby similar bottles can outweigh one isolated similar bottle")
    func clusterOutweighsIsolatedBottle() {
        let storage = Storage(name: "Cellar", position: 0)
        let shelf = Self.makeShelf(position: 0, storageID: storage.storageID, rowSlotCounts: [8])

        // [Cab] [Cab] [Cab] [empty] [empty] [empty] [isolated Cab] [empty]
        let cluster = (0...2).map { column in
            Self.makeBottle(
                wineType: .red, varietal: "Cabernet Sauvignon",
                slot: SlotID(shelfID: shelf.shelfID, row: 0, column: column)
            )
        }
        let isolated = Self.makeBottle(
            wineType: .red, varietal: "Cabernet Sauvignon",
            slot: SlotID(shelfID: shelf.shelfID, row: 0, column: 6)
        )

        let newBottle = Self.makeBottle(wineType: .red, varietal: "Cabernet Sauvignon")

        let recommendation = WinePlacementService.findBestSlot(
            for: newBottle,
            in: storage,
            allShelves: [shelf],
            allBottles: cluster + [isolated]
        )

        // Column 3 sits right beside the three-bottle cluster; column 7 sits
        // right beside the single isolated bottle. Despite being farther
        // from any one cluster bottle than column 7 is from the isolated
        // one, the cluster's combined pull should still win out.
        #expect(recommendation?.slot == SlotID(shelfID: shelf.shelfID, row: 0, column: 3))
    }

    // MARK: - 6. Missing metadata doesn't error or penalize

    @Test("Missing metadata does not cause errors or artificially penalize a bottle")
    func missingMetadataDoesNotPenalize() {
        let storage = Storage(name: "Cellar", position: 0)
        let shelf = Self.makeShelf(position: 0, storageID: storage.storageID, rowSlotCounts: [3])

        // An existing bottle with almost nothing filled in beyond varietal.
        let sparse = Self.makeBottle(
            varietal: "Cabernet Sauvignon",
            slot: SlotID(shelfID: shelf.shelfID, row: 0, column: 0)
        )
        let newBottle = Self.makeBottle(varietal: "Cabernet Sauvignon")

        let recommendation = WinePlacementService.findBestSlot(
            for: newBottle,
            in: storage,
            allShelves: [shelf],
            allBottles: [sparse]
        )

        #expect(recommendation != nil)
        #expect((recommendation?.totalScore ?? 0) > 0)
    }

    // MARK: - 7. No meaningful matches falls back to natural order

    @Test("With no meaningful matches, placement falls back to the first available slot in natural order")
    func fallsBackToNaturalOrderWithNoMatches() {
        let storage = Storage(name: "Cellar", position: 0)
        let shelf = Self.makeShelf(position: 0, storageID: storage.storageID, rowSlotCounts: [4])

        let unrelated = Self.makeBottle(
            producer: "Producer A", wineType: .white, varietal: "Riesling",
            country: "Germany",
            slot: SlotID(shelfID: shelf.shelfID, row: 0, column: 0)
        )
        // A bottle sharing literally nothing with the existing inventory.
        let newBottle = Self.makeBottle(
            producer: "Producer B", wineType: .red, varietal: "Nebbiolo",
            country: "Italy"
        )

        let recommendation = WinePlacementService.findBestSlot(
            for: newBottle,
            in: storage,
            allShelves: [shelf],
            allBottles: [unrelated]
        )

        #expect(recommendation?.slot == SlotID(shelfID: shelf.shelfID, row: 0, column: 1))
        #expect(recommendation?.totalScore == 0)
    }

    // MARK: - 8. Occupied slots are never returned

    @Test("Occupied slots are never returned")
    func occupiedSlotsAreNeverReturned() {
        let storage = Storage(name: "Cellar", position: 0)
        let shelf = Self.makeShelf(position: 0, storageID: storage.storageID, rowSlotCounts: [2])

        let occupying = Self.makeBottle(
            varietal: "Cabernet Sauvignon",
            slot: SlotID(shelfID: shelf.shelfID, row: 0, column: 0)
        )
        let newBottle = Self.makeBottle(varietal: "Cabernet Sauvignon")

        let recommendation = WinePlacementService.findBestSlot(
            for: newBottle,
            in: storage,
            allShelves: [shelf],
            allBottles: [occupying]
        )

        #expect(recommendation?.slot == SlotID(shelfID: shelf.shelfID, row: 0, column: 1))
    }

    // MARK: - 9. Irregular shelf/row sizes are handled correctly

    @Test("Irregular shelf/row sizes are handled correctly")
    func irregularShelfSizesHandledCorrectly() {
        let storage = Storage(name: "Cellar", position: 0)
        // A pyramid layout: 3, 4, 5 slots per row.
        let shelf = Self.makeShelf(position: 0, storageID: storage.storageID, rowSlotCounts: [3, 4, 5])

        let matching = Self.makeBottle(
            varietal: "Cabernet Sauvignon",
            slot: SlotID(shelfID: shelf.shelfID, row: 2, column: 4)
        )
        let newBottle = Self.makeBottle(varietal: "Cabernet Sauvignon")

        let recommendation = WinePlacementService.findBestSlot(
            for: newBottle,
            in: storage,
            allShelves: [shelf],
            allBottles: [matching]
        )

        #expect(recommendation?.slot == SlotID(shelfID: shelf.shelfID, row: 2, column: 3))
    }

    // MARK: - 10. Deterministic tie-breaking

    @Test("Multiple identical candidate scores produce deterministic results")
    func identicalScoresAreDeterministic() {
        let storage = Storage(name: "Cellar", position: 0)
        let shelf = Self.makeShelf(position: 0, storageID: storage.storageID, rowSlotCounts: [4])

        // No existing bottles at all — every candidate scores identically
        // (all zero), so the result must always be the first empty slot.
        let newBottle = Self.makeBottle(varietal: "Cabernet Sauvignon")

        let first = WinePlacementService.findBestSlot(for: newBottle, in: storage, allShelves: [shelf], allBottles: [])
        let second = WinePlacementService.findBestSlot(for: newBottle, in: storage, allShelves: [shelf], allBottles: [])

        #expect(first?.slot == second?.slot)
        #expect(first?.slot == SlotID(shelfID: shelf.shelfID, row: 0, column: 0))
    }

    // MARK: - 11. No available slots returns no recommendation

    @Test("Storage with no available slots returns no recommendation")
    func noAvailableSlotsReturnsNil() {
        let storage = Storage(name: "Cellar", position: 0)
        let shelf = Self.makeShelf(position: 0, storageID: storage.storageID, rowSlotCounts: [1])

        let occupying = Self.makeBottle(slot: SlotID(shelfID: shelf.shelfID, row: 0, column: 0))
        let newBottle = Self.makeBottle()

        let recommendation = WinePlacementService.findBestSlot(
            for: newBottle,
            in: storage,
            allShelves: [shelf],
            allBottles: [occupying]
        )

        #expect(recommendation == nil)
    }

    // MARK: - 12. Cross-storage-unit candidates are farther than same-unit ones

    @Test("A candidate in another storage unit is considered farther away than a nearby candidate in the same unit")
    func crossStorageUnitIsFartherThanSameUnit() {
        let storageA = Storage(name: "Cellar A", position: 0)
        let storageB = Storage(name: "Cellar B", position: 1)
        let shelfA = Self.makeShelf(position: 0, storageID: storageA.storageID, rowSlotCounts: [4])
        let shelfB = Self.makeShelf(position: 0, storageID: storageB.storageID, rowSlotCounts: [4])

        let farA = StorageDistance.coordinates(
            of: SlotID(shelfID: shelfA.shelfID, row: 0, column: 3),
            shelvesByID: [shelfA.shelfID: shelfA, shelfB.shelfID: shelfB]
        )!
        let nearA = StorageDistance.coordinates(
            of: SlotID(shelfID: shelfA.shelfID, row: 0, column: 1),
            shelvesByID: [shelfA.shelfID: shelfA, shelfB.shelfID: shelfB]
        )!
        let referenceInB = StorageDistance.coordinates(
            of: SlotID(shelfID: shelfB.shelfID, row: 0, column: 0),
            shelvesByID: [shelfA.shelfID: shelfA, shelfB.shelfID: shelfB]
        )!
        let referenceInA = StorageDistance.coordinates(
            of: SlotID(shelfID: shelfA.shelfID, row: 0, column: 0),
            shelvesByID: [shelfA.shelfID: shelfA, shelfB.shelfID: shelfB]
        )!

        let crossUnitDistance = StorageDistance.distance(nearA, referenceInB)
        let sameUnitFarDistance = StorageDistance.distance(farA, referenceInA)

        #expect(crossUnitDistance > sameUnitFarDistance)
    }
}
