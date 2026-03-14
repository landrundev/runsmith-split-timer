import Foundation

enum SplitMerger {

    // MARK: – Result Types

    struct MergedResult {
        let athleteId: UUID          // Host's athlete ID
        let athleteName: String
        let originalSplits: [Int]    // Host's elapsedMs values
        let coachSplits: [[Int]]     // Each imported coach's splits (parallel array)
        let mergedSplits: [Int]      // Final averaged or median values
        let flags: [SplitFlag]       // Per-split-index diagnostic flags
    }

    enum SplitFlag: Equatable {
        case clean                   // All values within dynamic tolerance (2% of median, floored at 200ms, capped at 1000ms)
        case outlier(coachIndex: Int) // One source exceeded dynamic tolerance (2% of median, floored at 200ms, capped at 1000ms); excluded
        case singleTimer             // Only one source recorded this split
    }

    enum MergeStrategy: String, CaseIterable {
        case median  = "Median"      // Middle value of sorted clean values (World Athletics standard)
        case average = "Average"     // Arithmetic mean of all clean values
    }

    // MARK: – Core Merge Function

    /// Merge splits from the host and one or more assistant coaches.
    ///
    /// For each split index:
    ///   - 1 value  → use as-is, flag `.singleTimer`
    ///   - 2+ values → compute median, exclude any value exceeding a dynamic tolerance
    ///                 (2% of median, floored at 200ms, capped at 1000ms) from the median
    ///                 (flag `.outlier`), then apply the chosen strategy to the remaining clean values.
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

            // Single source → nothing to compare against
            if values.count == 1 {
                merged.append(values[0].ms)
                flags.append(.singleTimer)
                continue
            }

            // Compute median of all values at this index
            let sorted = values.map(\.ms).sorted()
            let medianValue = sorted[sorted.count / 2]

            // Partition into clean (within dynamic tolerance) and outlier (exceeds tolerance)
            let tolerance = max(200, min(1000, Int(Double(medianValue) * 0.02)))
            var cleanValues: [Int] = []
            var firstOutlierSourceIndex: Int? = nil

            for (sourceIdx, ms) in values {
                if abs(ms - medianValue) > tolerance {
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
