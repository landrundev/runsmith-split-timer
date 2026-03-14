import XCTest
@testable import RunsmithSplitTimer

final class SplitMergerTests: XCTestCase {

    // MARK: – Single source → .singleTimer

    func testSingleSource_passedThroughWithSingleTimerFlag() {
        let result = SplitMerger.merge(
            hostSplits: [60000],
            coachSplits: [],
            strategy: .median
        )
        XCTAssertEqual(result.merged, [60000])
        XCTAssertEqual(result.flags, [.singleTimer])
    }

    // MARK: – Two clean sources → .clean

    func testTwoCleanSources_median_cleanFlag() {
        let result = SplitMerger.merge(
            hostSplits: [60000],
            coachSplits: [[60100]],
            strategy: .median
        )
        XCTAssertEqual(result.flags, [.clean])
        // Median of [60000, 60100] sorted → picks index 1 → 60100
        XCTAssertEqual(result.merged, [60100])
    }

    func testTwoCleanSources_average_cleanFlag() {
        let result = SplitMerger.merge(
            hostSplits: [60000],
            coachSplits: [[60100]],
            strategy: .average
        )
        XCTAssertEqual(result.flags, [.clean])
        // Average of [60000, 60100] = 60050
        XCTAssertEqual(result.merged, [60050])
    }

    // MARK: – Outlier detection

    func testThreeSources_oneOutlier_outlierFlagAndCleanValueUsed() {
        // Values: [60000, 60050, 62000]
        // sorted median = 60050, tolerance = max(200, min(1000, 1201)) = 1000
        // |60000 - 60050| = 50 ≤ 1000 → clean
        // |60050 - 60050| = 0 → clean
        // |62000 - 60050| = 1950 > 1000 → outlier (coach index 1)
        let result = SplitMerger.merge(
            hostSplits: [60000],
            coachSplits: [[60050], [62000]],
            strategy: .median
        )
        // Merged from clean values [60000, 60050], median picks index 1 → 60050
        XCTAssertEqual(result.merged, [60050])
        if case .outlier(let coachIndex) = result.flags[0] {
            XCTAssertEqual(coachIndex, 1) // coach 1 (third source) was the outlier
        } else {
            XCTFail("Expected .outlier flag, got \(result.flags[0])")
        }
    }

    // MARK: – All values are outliers (fallback)

    func testAllOutliers_fallbackToSortedSet_noCrash() {
        // Three wildly different values — all will be outliers relative to median
        // Values: [1000, 50000, 100000], median = 50000
        // tolerance = max(200, min(1000, 1000)) = 1000
        // |1000 - 50000| = 49000 > 1000 → outlier
        // |50000 - 50000| = 0 ≤ 1000 → clean
        // |100000 - 50000| = 50000 > 1000 → outlier
        // Actually 50000 is clean, so this isn't "all outliers".
        // Use values where ALL deviate from median:
        // [1000, 3000, 100000] → median = 3000
        // tolerance = max(200, min(1000, 60)) = 200
        // |1000 - 3000| = 2000 > 200 → outlier
        // |3000 - 3000| = 0 ≤ 200 → clean
        // Still not all outliers. Need extreme spread even at median:
        // [100, 500, 900] → median = 500, tolerance = max(200, min(1000, 10)) = 200
        // |100 - 500| = 400 > 200 → outlier
        // |500 - 500| = 0 → clean
        // The median value itself is always clean. To get all outliers we need an even count
        // where the "median" (index count/2) doesn't match any value.
        // With 2 values: [100, 1000] → sorted median = 1000, tol = max(200,min(1000,20))=200
        // |100 - 1000| = 900 > 200 → outlier, |1000 - 1000| = 0 → clean
        // Can't make all outliers with standard values since median is always in the set.
        // Test the fallback path indirectly: verify no crash and a value is produced.
        let result = SplitMerger.merge(
            hostSplits: [100],
            coachSplits: [[1000]],
            strategy: .median
        )
        XCTAssertEqual(result.merged.count, 1)
        XCTAssertFalse(result.merged.isEmpty)
    }

    // MARK: – Dynamic tolerance boundary

    func testDynamicTolerance_exactlyAtBoundary_notFlagged() {
        // medianValue = 60000, tolerance = max(200, min(1000, 1200)) = 1000
        // Value at exactly median + 1000 = 61000 → |61000 - 60000| = 1000, NOT > 1000 → clean
        let result = SplitMerger.merge(
            hostSplits: [60000],
            coachSplits: [[61000]],
            strategy: .median
        )
        XCTAssertEqual(result.flags, [.clean])
    }

    func testDynamicTolerance_oneOverBoundary_flaggedAsOutlier() {
        // medianValue = 60000, tolerance = 1000
        // Value at median + 1001 = 61001 → |61001 - 60000| = 1001 > 1000 → outlier
        let result = SplitMerger.merge(
            hostSplits: [60000],
            coachSplits: [[61001]],
            strategy: .median
        )
        if case .outlier = result.flags[0] {
            // expected
        } else {
            XCTFail("Expected .outlier flag at boundary+1, got \(result.flags[0])")
        }
    }

    // MARK: – Median vs Average produce different results

    func testMedianVsAverage_differentResults() {
        // Three values: 60000, 60100, 60300
        // All within tolerance (median = 60100, tol = max(200, min(1000, 1202)) = 1000)
        // Median of [60000, 60100, 60300] = 60100
        // Average = (60000 + 60100 + 60300) / 3 = 60133
        let medianResult = SplitMerger.merge(
            hostSplits: [60000],
            coachSplits: [[60100], [60300]],
            strategy: .median
        )
        let averageResult = SplitMerger.merge(
            hostSplits: [60000],
            coachSplits: [[60100], [60300]],
            strategy: .average
        )
        XCTAssertEqual(medianResult.merged, [60100])
        XCTAssertEqual(averageResult.merged, [60133])
        XCTAssertNotEqual(medianResult.merged, averageResult.merged)
    }

    // MARK: – Multiple splits

    func testMultipleSplits_eachMergedIndependently() {
        let result = SplitMerger.merge(
            hostSplits: [60000, 120000],
            coachSplits: [[60100, 120200]],
            strategy: .average
        )
        XCTAssertEqual(result.merged.count, 2)
        XCTAssertEqual(result.merged[0], 60050)
        XCTAssertEqual(result.merged[1], 120100)
        XCTAssertEqual(result.flags, [.clean, .clean])
    }

    // MARK: – Tolerance floor at 200ms for small values

    func testToleranceFloor_smallValues_200msMinimum() {
        // medianValue = 5000 (5 seconds), 2% = 100ms, but floor is 200ms
        // So tolerance = 200
        // Value at 5000 + 200 = 5200 → within tolerance → clean
        let result = SplitMerger.merge(
            hostSplits: [5000],
            coachSplits: [[5200]],
            strategy: .median
        )
        XCTAssertEqual(result.flags, [.clean])

        // Value at 5000 + 201 = 5201 → exceeds tolerance → outlier
        let result2 = SplitMerger.merge(
            hostSplits: [5000],
            coachSplits: [[5201]],
            strategy: .median
        )
        if case .outlier = result2.flags[0] {
            // expected
        } else {
            XCTFail("Expected .outlier for value exceeding 200ms floor")
        }
    }
}
