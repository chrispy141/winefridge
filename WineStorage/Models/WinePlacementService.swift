//
//  WinePlacementService.swift
//  WineStorage
//

import Foundation

/// Chooses where Quick Add's "Auto Assign" should place a new bottle by
/// scoring every empty slot in a storage unit on how strongly it's
/// surrounded by similar wines, rather than simply taking the first empty
/// slot (see `StorageSlotAssigner.firstAvailableSlot`, which remains the
/// fallback/tie-break policy this builds on).
///
/// Conceptually, each candidate slot's score is:
///
///     sum over every already-placed bottle of:
///         wineSimilarity(newBottle, existingBottle) × distanceWeight(slot, existingBottle's slot)
///
/// plus a modest bonus for being an immediate neighbor of a highly similar
/// bottle, plus a small tie-breaking preference for keeping remaining empty
/// space contiguous. The highest-scoring empty slot wins; ties fall back to
/// the existing natural (shelf, then row, then column) display order.
///
/// Kept as a plain model-layer type, independent of SwiftUI/SwiftData
/// fetching concerns — callers hand it the bottles/shelves they've already
/// fetched.
enum WinePlacementService {
    /// Named weights for the non-similarity parts of scoring. See
    /// `WineSimilarity.Weights` for wine-similarity weights and
    /// `StorageDistance.Weights` for physical-distance weights.
    enum PlacementWeights {
        /// Multiplies the strongest similarity among a candidate slot's
        /// immediate physical neighbors. Kept modest, and based on the
        /// single strongest neighbor rather than summed across neighbors,
        /// so one highly similar adjacent bottle nudges placement toward
        /// compact groups without ever outweighing a larger nearby cluster
        /// (which accumulates through the main distance-weighted sum
        /// instead).
        static let neighborBonusFactor: Double = 0.15
        /// Multiplies the fraction of a candidate slot's immediate
        /// neighbors that are already occupied (by any bottle). A small,
        /// low-weight tie-breaker that prefers keeping empty storage
        /// contiguous — it should never outrank a meaningfully better
        /// similarity/distance score.
        static let fragmentationWeight: Double = 0.5
        /// Score differences smaller than this are treated as a tie and
        /// broken using natural storage order, so floating-point noise
        /// never makes placement non-deterministic.
        static let tieEpsilon: Double = 0.0001
    }

    /// An already-placed bottle that's at least somewhat similar to the new
    /// bottle, along with where it sits and why it matched.
    struct RelevantBottle {
        let bottle: Bottle
        let slot: SlotID
        let coordinates: StorageDistance.Coordinates
        let similarity: Double
        let matchedCharacteristics: [String]
    }

    /// A relevant bottle's distance from one particular candidate slot —
    /// only meaningful in the context of the candidate it was computed for.
    struct NearbyBottle {
        let bottle: Bottle
        let distance: Double
        let similarity: Double
    }

    /// One candidate slot's score breakdown — exposed (not just the
    /// winner) so the algorithm can be inspected/tuned; see
    /// `PlacementRecommendation.candidateScores`.
    struct CandidateSlotScore {
        let slot: SlotID
        let similarityDistanceScore: Double
        let neighborBonus: Double
        let fragmentationScore: Double

        var total: Double { similarityDistanceScore + neighborBonus + fragmentationScore }
    }

    /// The outcome of `findBestSlot`, with enough detail to explain the
    /// choice for debugging or a future UI, even though nothing surfaces
    /// this in production UI yet.
    struct PlacementRecommendation {
        let slot: SlotID
        let totalScore: Double
        /// The characteristics that contributed most to this slot's score,
        /// strongest first (e.g. "Same Grape/Blend: Cabernet Sauvignon").
        let matchedCharacteristics: [String]
        /// The nearest relevant (similar) bottles to the winning slot,
        /// closest first.
        let nearestBottles: [NearbyBottle]
        /// Every candidate slot that was considered, best-scoring first —
        /// useful for debugging/tuning (see the module doc comment).
        let candidateScores: [CandidateSlotScore]
    }

    /// The slot Auto Assign should use for `bottle` within `storage`, or
    /// `nil` if that storage unit has no empty slots.
    ///
    /// - Parameters:
    ///   - bottle: The bottle being placed. Not expected to already occupy a
    ///     slot, but if it does (e.g. retrying Auto Assign), it's excluded
    ///     from its own similarity/distance comparisons.
    ///   - storage: The storage unit whose empty slots are candidates.
    ///     Bottles placed in *other* storage units still count toward
    ///     similarity (a matching bottle elsewhere is real signal), but
    ///     `StorageDistance` scores them as substantially farther away, so
    ///     in practice they rarely change the outcome.
    ///   - allShelves: Every shelf across every storage unit, needed to
    ///     resolve any bottle's slot into logical coordinates.
    ///   - allBottles: Every bottle, placed or not.
    static func findBestSlot(
        for bottle: Bottle,
        in storage: Storage,
        allShelves: [Shelf],
        allBottles: [Bottle]
    ) -> PlacementRecommendation? {
        let shelvesByID = Dictionary(uniqueKeysWithValues: allShelves.map { ($0.shelfID, $0) })
        let candidateShelves = allShelves
            .filter { $0.storageID == storage.storageID }
            .sorted { $0.position < $1.position }

        let candidates = StorageSlotAssigner.availableSlots(onShelves: candidateShelves, occupying: allBottles)
        guard !candidates.isEmpty else { return nil }

        let placedBottles = allBottles.filter { $0 !== bottle && $0.slot != nil }
        let relevantBottles: [RelevantBottle] = placedBottles.compactMap { existing in
            guard let slot = existing.slot,
                  let coordinates = StorageDistance.coordinates(of: slot, shelvesByID: shelvesByID) else { return nil }
            let result = WineSimilarity.similarity(bottle, existing)
            guard result.score > 0 else { return nil }
            return RelevantBottle(
                bottle: existing,
                slot: slot,
                coordinates: coordinates,
                similarity: result.score,
                matchedCharacteristics: result.matchedCharacteristics
            )
        }

        // No meaningful similarity signal anywhere — fall back to the
        // predictable, existing natural-order policy rather than letting a
        // secondary factor like fragmentation produce seemingly arbitrary
        // placement.
        guard !relevantBottles.isEmpty else {
            return PlacementRecommendation(
                slot: candidates[0],
                totalScore: 0,
                matchedCharacteristics: [],
                nearestBottles: [],
                candidateScores: candidates.map {
                    CandidateSlotScore(slot: $0, similarityDistanceScore: 0, neighborBonus: 0, fragmentationScore: 0)
                }
            )
        }

        let occupiedSlots = StorageSlotAssigner.occupiedSlots(in: allBottles)
        let naturalIndex = Dictionary(uniqueKeysWithValues: candidates.enumerated().map { ($1, $0) })

        var scores: [CandidateSlotScore] = []
        var matchedCharacteristicsBySlot: [SlotID: [String: Double]] = [:]
        var nearbyBySlot: [SlotID: [NearbyBottle]] = [:]

        for candidate in candidates {
            guard let candidateShelf = shelvesByID[candidate.shelfID],
                  let candidateCoordinates = StorageDistance.coordinates(of: candidate, shelvesByID: shelvesByID) else { continue }

            let (score, matchedCharacteristics, nearby) = scoreCandidateSlot(
                candidate,
                coordinates: candidateCoordinates,
                shelf: candidateShelf,
                relevantBottles: relevantBottles,
                occupiedSlots: occupiedSlots
            )
            scores.append(score)
            matchedCharacteristicsBySlot[candidate] = matchedCharacteristics
            nearbyBySlot[candidate] = nearby
        }

        let ranked = scores.sorted { lhs, rhs in
            if abs(lhs.total - rhs.total) > PlacementWeights.tieEpsilon {
                return lhs.total > rhs.total
            }
            // Effectively tied — prefer the earlier slot in natural display order.
            return (naturalIndex[lhs.slot] ?? 0) < (naturalIndex[rhs.slot] ?? 0)
        }
        guard let winner = ranked.first else { return nil }

        let topCharacteristics = (matchedCharacteristicsBySlot[winner.slot] ?? [:])
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map(\.key)
        let nearest = (nearbyBySlot[winner.slot] ?? [])
            .sorted { $0.distance < $1.distance }
            .prefix(5)

        return PlacementRecommendation(
            slot: winner.slot,
            totalScore: winner.total,
            matchedCharacteristics: Array(topCharacteristics),
            nearestBottles: Array(nearest),
            candidateScores: ranked
        )
    }

    /// Scores a single candidate slot against every relevant (similar)
    /// bottle, returning its score breakdown plus debugging detail (which
    /// characteristics drove the score, and which bottles were nearest).
    /// Separated from `findBestSlot`'s loop so it's independently testable.
    static func scoreCandidateSlot(
        _ candidate: SlotID,
        coordinates: StorageDistance.Coordinates,
        shelf: Shelf,
        relevantBottles: [RelevantBottle],
        occupiedSlots: Set<SlotID>
    ) -> (score: CandidateSlotScore, matchedCharacteristics: [String: Double], nearbyBottles: [NearbyBottle]) {
        var similarityDistanceScore = 0.0
        var neighborSimilarityMax = 0.0
        var contributionByCharacteristic: [String: Double] = [:]
        var nearby: [NearbyBottle] = []

        for relevant in relevantBottles {
            let distance = StorageDistance.distance(coordinates, relevant.coordinates)
            let weight = StorageDistance.distanceWeight(forDistance: distance)
            let contribution = relevant.similarity * weight
            similarityDistanceScore += contribution

            for characteristic in relevant.matchedCharacteristics {
                contributionByCharacteristic[characteristic, default: 0] += contribution
            }
            nearby.append(NearbyBottle(bottle: relevant.bottle, distance: distance, similarity: relevant.similarity))

            if StorageDistance.areImmediateNeighbors(coordinates, relevant.coordinates) {
                neighborSimilarityMax = max(neighborSimilarityMax, relevant.similarity)
            }
        }

        let neighborBonus = neighborSimilarityMax * PlacementWeights.neighborBonusFactor

        let neighborSlots = StorageDistance.immediateNeighborSlots(of: candidate, on: shelf)
        let fragmentationScore: Double
        if neighborSlots.isEmpty {
            fragmentationScore = 0
        } else {
            let occupiedNeighborCount = neighborSlots.filter { occupiedSlots.contains($0) }.count
            fragmentationScore = PlacementWeights.fragmentationWeight
                * Double(occupiedNeighborCount) / Double(neighborSlots.count)
        }

        let score = CandidateSlotScore(
            slot: candidate,
            similarityDistanceScore: similarityDistanceScore,
            neighborBonus: neighborBonus,
            fragmentationScore: fragmentationScore
        )
        return (score, contributionByCharacteristic, nearby)
    }
}
