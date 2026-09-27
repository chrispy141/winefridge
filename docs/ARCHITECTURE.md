# WineStorage Architecture

UML diagrams of the app's structure, written in [Mermaid](https://mermaid.js.org/) so they render directly on GitHub.

The app is a SwiftUI + SwiftData iOS app, synced through CloudKit. It has three layers:

- **Models** (`WineStorage/Models`): SwiftData entities plus stateless domain logic for slot assignment and smart placement.
- **Services** (`WineStorage/Services`): label scanning. Vision OCR, then Apple Foundation Models interpret the text.
- **Views** (`WineStorage/Views`): SwiftUI screens that read data through `@Query` and write through `ModelContext`.

## 1. Data model

`Storage`, `Shelf` and `Bottle` are the three `@Model` classes registered in the `ModelContainer` (`WineStorageApp.swift`). There are no SwiftData `@Relationship`s between them. They link through stable UUIDs instead, which keeps the schema CloudKit-compatible:

- `Shelf.storageID` → `Storage.storageID`
- `Bottle.slot` (`SlotID`, stored as private `shelfID`/`row`/`column`) → `Shelf.shelfID`

A bottle with `slot == nil` is unplaced. It sits in the shared inventory and belongs to no storage unit.

```mermaid
classDiagram
    direction LR

    class Storage {
        <<@Model>>
        +String name
        +Int position
        +Date dateCreated
        +UUID storageID
        +FridgeIcon? icon
        +FridgeIcon displayIcon
    }

    class Shelf {
        <<@Model>>
        +Int position
        +UUID shelfID
        +[Int] rowSlotCounts
        +UUID storageID
        +Bool isOffsetRows
        +Int rowCount
        +seedDefaults(context, storageID)$
    }

    class Bottle {
        <<@Model>>
        +String name
        +String producer
        +WineType wineType
        +String varietal
        +Int? vintage
        +Bool isNonVintage
        +String country
        +String region
        +String appellation
        +String vineyard
        +String designation
        +BottleSize bottleSize
        +Double? abv
        +String notes
        +Date dateAdded
        +Data? photoData
        +SlotID? slot
        +VintageSelection vintageSelection
        +String? vintageDisplayText
        +clearSlot()
    }

    class SlotID {
        <<struct · Hashable, Codable, Transferable>>
        +UUID shelfID
        +Int row
        +Int column
        +String id
        +locationDescription(slot, shelves)$ String
    }

    class VintageSelection {
        <<enum>>
        unknown
        nonVintage
        year(Int)
    }

    class WineType {
        <<enum>>
        red
        white
        rose
        sparkling
        dessert
        fortified
        +Color color
    }

    class BottleSize {
        <<enum>>
        quarter
        half
        standard
        magnum
        doubleMagnum
    }

    class FridgeIcon {
        <<enum>>
        small
        tall
        shelfOne
        shelfTwo
        +String displayName
        +String imageName
    }

    class ShelfLayoutPreset {
        <<struct>>
        +String name
        +[Int] rowSlotCounts
        +Bool isOffsetRows
        +all$ [ShelfLayoutPreset]
    }

    Storage "1" <.. "0..*" Shelf : storageID
    Shelf "1" <.. "0..*" SlotID : shelfID
    Bottle "0..1" --> "0..1" SlotID : slot
    Bottle --> WineType
    Bottle --> BottleSize
    Bottle ..> VintageSelection
    Storage --> FridgeIcon
    ShelfLayoutPreset ..> Shelf : configures rowSlotCounts
```

## 2. Domain logic and services

These are stateless `enum`/`struct` namespaces. Only the views call them, and none of them touches `ModelContext` except `BackupPackage`.

**Smart placement** (`QuickAddBottleView`) uses `WinePlacementService.findBestSlot`. It scores every free slot (from `StorageSlotAssigner`) by combining how similar the new bottle is to nearby bottles (`WineSimilarity`) with how far away they are (`StorageDistance`). It also adds a small bonus for similar immediate neighbours and a penalty for fragmenting free space.

**Label scanning** goes through `WineLabelScanner`, the single entry point that views call. The scanner runs OCR with `WineLabelTextRecognizer`, then hands the text to `WineLabelInterpreter`. The interpreter uses on-device Foundation Models guided generation to produce `WineLabelInfo`, which it maps to a typed `WineLabelExtraction`.

```mermaid
classDiagram
    direction TB

    namespace Placement {
        class WinePlacementService {
            <<enum>>
            +findBestSlot(bottle, storage, allShelves, allBottles)$ PlacementRecommendation?
            +scoreCandidateSlot(...)$ CandidateSlotScore
        }
        class PlacementRecommendation {
            <<struct>>
            +SlotID slot
            +Double totalScore
            +[String] matchedCharacteristics
            +[NearbyBottle] nearestBottles
            +[CandidateSlotScore] candidateScores
        }
        class CandidateSlotScore {
            <<struct>>
            +SlotID slot
            +Double similarityDistanceScore
            +Double neighborBonus
            +Double fragmentationScore
            +Double total
        }
        class WineSimilarity {
            <<enum>>
            +similarity(a, b)$ Result
        }
        class StorageDistance {
            <<enum>>
            +coordinates(slot, shelvesByID)$ Coordinates?
            +distance(a, b)$ Double
            +distanceWeight(distance)$ Double
            +areImmediateNeighbors(a, b)$ Bool
            +immediateNeighborSlots(slot, shelf)$ [SlotID]
        }
        class StorageSlotAssigner {
            <<enum>>
            +occupiedSlots(bottles)$ Set~SlotID~
            +availableSlots(shelves, bottles)$ [SlotID]
            +firstAvailableSlot(shelves, bottles)$ SlotID?
            +isAvailable(slot, bottles)$ Bool
        }
    }

    namespace LabelScanning {
        class WineLabelScanner {
            <<enum>>
            +scan(image)$ Outcome
        }
        class Outcome {
            <<enum>>
            extracted(WineLabelExtraction)
            interpreterUnavailable(reason)
        }
        class WineLabelTextRecognizer {
            <<enum · Vision>>
            +recognizeText(image)$ String
        }
        class WineLabelInterpreter {
            <<struct · FoundationModels>>
            +availability()$ Availability
            +interpret(ocrText) WineLabelExtraction
        }
        class WineLabelInfo {
            <<@Generable struct>>
            raw model output
        }
        class WineLabelExtraction {
            <<struct>>
            typed, optional label fields
        }
    }

    namespace Backup {
        class BackupPackage {
            <<struct · Codable>>
            +Date createdDate
            +[StorageRecord] storages
            +[ShelfRecord] shelves
            +[BottleRecord] bottles
            +init(modelContext)
            +init(data)
            +encoded() Data
            +restore(into modelContext)
        }
        class BackupDocument {
            <<struct · FileDocument>>
            +Data data
        }
    }

    WinePlacementService ..> StorageSlotAssigner : candidate slots
    WinePlacementService ..> WineSimilarity : score similarity
    WinePlacementService ..> StorageDistance : weight by distance
    WinePlacementService --> PlacementRecommendation : returns
    PlacementRecommendation *-- CandidateSlotScore

    WineLabelScanner ..> WineLabelTextRecognizer : 1. OCR
    WineLabelScanner ..> WineLabelInterpreter : 2. interpret
    WineLabelScanner --> Outcome : returns
    WineLabelInterpreter ..> WineLabelInfo : generates
    WineLabelInterpreter --> WineLabelExtraction : maps to
    Outcome --> WineLabelExtraction

    BackupDocument ..> BackupPackage : wraps encoded
```

## 3. Views and navigation

`ContentView` is a `TabView` with three `NavigationStack`s. Each edge label gives the kind of link: a tab, a `push` (navigation), a `sheet` (a sheet or full-screen cover), or `uses` (an embedded subview or a service call).

```mermaid
flowchart TD
    App["WineStorageApp<br/>(@main, ModelContainer + CloudKit)"] --> CV[ContentView<br/>TabView]

    CV -->|Storage tab| SLV[StorageListView]
    CV -->|Inventory tab| ILV[InventoryListView]
    CV -->|Settings tab| BRV[BackupRestoreView]

    SLV -.->|sheet| ASV[AddStorageView]
    SLV -->|push| SV[StorageView]

    SV -.->|sheet| BDV[BottleDetailView]
    SV -.->|sheet: empty slot| SPV[SlotPickerView]
    SV -.->|sheet| ESV[EditStorageView]
    SV -.->|sheet| QAV[QuickAddBottleView]

    SPV -.->|sheet| BFV[BottleFormView]
    BDV -.->|sheet: edit| BFV
    ILV -.->|sheet| BDV
    ILV -.->|sheet: add| BFV
    QAV -.->|review| BFV
    QAV -.->|camera| CAM[CameraCaptureView]
    BFV -.->|camera| CAM

    subgraph Components [Reusable components]
        ShV[ShelfView]
        BSC[BottleSlotCellView]
        ACT[AutocompleteTextField]
        BRL[BottleRowLabel]
        FIO[FridgeIconOption]
    end

    SV -. uses .-> ShV
    ShV -. uses .-> BSC
    QAV -. "uses (manual pick)" .-> SV
    BFV -. uses .-> ACT
    ILV -. uses .-> BRL
    SPV -. uses .-> BRL
    ASV -. uses .-> FIO
    ESV -. uses .-> FIO

    subgraph Services [Domain logic / services]
        WLS[WineLabelScanner]
        WPS[WinePlacementService]
        SSA[StorageSlotAssigner]
        BP[BackupPackage]
    end

    BFV -. scan label .-> WLS
    QAV -. scan label .-> WLS
    QAV -. recommend slot .-> WPS
    QAV -. check/fallback slot .-> SSA
    BRV -. export/restore .-> BP
    SV -. "Shelf.seedDefaults" .-> SH[(SwiftData:<br/>Storage · Shelf · Bottle)]
```

## Tests

- `WineStorageTests/WinePlacementServiceTests.swift` covers the placement scoring in diagram 2.
- `WineStorageUITests/` holds the default Xcode UI test scaffolding.
