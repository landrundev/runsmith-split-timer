# Step 04 â Create SplitMerger with Median/Average Merge Logic and Outlier Detection

**Depends on**: `SharedRaceConfig.swift` and `CoachSplitPayload.swift` from Step 02 must already be in the project.

---

## CREATE `SplitDeck/Domain/SplitMerger.swift`

```swift
import Foundation

enum SplitMerger {

    // MARK: â Result Types

    struct MergedResult {
        let athleteId: UUID          // Host's athlete ID
        let athleteName: String
        let originalSplits: [Int]    // Host's elapsedMs values
        let coachSplits: [[Int]]     // Each imported coach's splits (parallel array)
        let mergedSplits: [Int]      // Final averaged or median values
        let flags: [SplitFlag]       // Per-split-index diagnostic flags
    }

    enum SplitFlag: Equatable {
        case clean                   // All values within 500ms tolerance of median
        case outlier(coachIndex: Int) // One source was >500ms off the median; excluded
        case singleTimer             // Only one source recorded this split
    }

    enum MergeStrategy: String, CaseIterable {
        case median  = "Median"      // Middle value of sorted clean values (World Athletics standard)
        case average = "Average"     // Arithmetic mean of all clean values
    }

    // MARK: â Core Merge Function

    /// Merge splits from the host and one or more assistant coaches.
    ///
    /// For each split index:
    ///   - 1 value  â use as-is, flag `.singleTimer`
    ///   - 2+ values â compute median, exclude any value >500ms from median (flag `.outlier`),
    ///                 then apply the chosen strategy to the remaining clean values.
    ///
    /// - Parameters:
    ///   - hostSplits:   The host coach's elapsedMs values, ordered by split index.
    ///   - coachSplits:  Array of assistant split arrays. `coachSplits[0]` = first assistant, etc.
    ///   - strategy:     Whether to take the median or arithmetic mean of clean values.
    /// - Returns: Parallel arrays of merged millisecond values and per-split flags.
    static func merge(
        hostSplits: [Int],
        coachSplits: [[Int]],
        strategy: MergeStrategy
    ) -> (merged: [Int], flags: [SplitFlag]) {

        let allSources = [hostSplits] + coachSplits
        let maxCount = allSources.map(\.count).max() ?? 0

        var merged: [Int] = []
        var flags:  [SplitFlag] = []

        for i in 0..<maxCount {
            // Collect every source's value at split index i
            var values: [(sourceIndex: Int, ms: Int)] = []
            for (sourceIdx, source) in allSources.enumerated() {
                if i < source.count {
                    values.append((sourceIdx, source[i]))
                }
            }

            guard !values.isEmpty else { continue }

            // Single source â nothing to compare against
            if values.count == 1 {
                merged.append(values[0].ms)
                flags.append(.singleTimer)
                continue
            }

            // Compute median of all values at this index
            let sorted = values.map(\.ms).sorted()
            let medianValue = sorted[sorted.count / 2]

            // Partition into clean (within 500ms) and outlier (>500ms off median)
            var cleanValues: [Int] = []
            var firstOutlierSourceIndex: Int? = nil

            for (sourceIdx, ms) in values {
                if abs(ms - medianValue) > 500 {
                    // Record the first outlier's source index for the flag
                    if firstOutlierSourceIndex == nil {
                        // sourceIdx 0 = host, sourceIdx 1+ = coachSplits[sourceIdx - 1]
                        // The flag stores the index into the coachSplits array (0-based),
                        // or 0 if the outlier is the host (sourceIdx == 0).
                        firstOutlierSourceIndex = sourceIdx
                    }
                } else {
                    cleanValues.append(ms)
                }
            }

            // Fallback: if all values were outliers (extremely rare), use original sorted set
            let valuesToMerge = cleanValues.isEmpty ? sorted : cleanValues

            let result: Int
            switch strategy {
            case .median:
                let s = valuesToMerge.sorted()
                result = s[s.count / 2]
            case .average:
                result = valuesToMerge.reduce(0, +) / valuesToMerge.count
            }

            merged.append(result)

            if let outlierSource = firstOutlierSourceIndex {
                // coachIndex is the 0-based index into the coachSplits array.
                // sourceIdx 0 = host (report coachIndex: 0 to indicate host was the outlier).
                // sourceIdx k = coachSplits[k - 1], so coachIndex = max(0, outlierSource - 1).
                let coachIndex = outlierSource > 0 ? outlierSource - 1 : 0
                flags.append(.outlier(coachIndex: coachIndex))
            } else {
                flags.append(.clean)
            }
        }

        return (merged, flags)
    }
}
```

---

## Verification Checklist

- [ ] Build succeeds with no errors or warnings
- [ ] Three-source median: `merge(hostSplits: [58410, 118650], coachSplits: [[58600, 118900], [58440, 118720]], strategy: .median)` produces `merged == [58440, 118720]` with `flags == [.clean, .clean]`
- [ ] Three-source average: same inputs with `strategy: .average` produces `merged == [58483, 118757]` (i.e., `(58410+58600+58440)/3 = 58483`, `(118650+118900+118720)/3 = 118757`)
- [ ] Single source: `merge(hostSplits: [58410], coachSplits: [], strategy: .median)` produces `flags == [.singleTimer]`
- [ ] Single source with empty coach: `merge(hostSplits: [58410, 118650], coachSplits: [[]], strategy: .median)` produces `flags == [.singleTimer, .singleTimer]`
- [ ] Outlier detection: `merge(hostSplits: [58410], coachSplits: [[59200], [58440]], strategy: .median)` â value 59200 is 790ms off median (~58440); it should be excluded and flagged as `.outlier`
- [ ] `SplitFlag.clean == SplitFlag.clean` compiles (Equatable conformance works)
- [ ] `SplitFlag.singleTimer == SplitFlag.singleTimer` compiles
- [ ] `SplitFlag.outlier(coachIndex: 0) == SplitFlag.outlier(coachIndex: 0)` compiles
- [ ] `MergeStrategy.allCases` returns `[.median, .average]`
- [ ] `MergeStrategy.median.rawValue == "Median"` and `MergeStrategy.average.rawValue == "Average"`
- [ ] `MergedResult` can be instantiated with all required fields

### Sample verification snippet (paste into a Preview or test)

```swift
// Three sources â clean result
let (merged1, flags1) = SplitMerger.merge(
    hostSplits: [58410, 118650],
    coachSplits: [[58600, 118900], [58440, 118720]],
    strategy: .median
)
// Sorted at index 0: [58410, 58440, 58600] â median = 58440
// Sorted at index 1: [118650, 118720, 118900] â median = 118720
assert(merged1 == [58440, 118720])
assert(flags1 == [.clean, .clean])

// Single source
let (merged2, flags2) = SplitMerger.merge(
    hostSplits: [58410],
    coachSplits: [],
    strategy: .median
)
assert(merged2 == [58410])
assert(flags2 == [.singleTimer])

// Outlier: 65000 is >500ms off median (~58440), should be excluded
let (merged3, flags3) = SplitMerger.merge(
    hostSplits: [58410],
    coachSplits: [[65000], [58440]],
    strategy: .median
)
// Median of [58410, 65000, 58440] = 58440; 65000 is 6560ms off â outlier
// Clean values: [58410, 58440] â median = 58440
assert(merged3 == [58440])
if case .outlier = flags3[0] { /* pass */ } else { fatalError("Expected .outlier flag") }
```
