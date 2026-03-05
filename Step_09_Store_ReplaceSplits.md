# Step 09 â Add `replaceSplits` to SplitDeckStore

**Depends on**: Steps 01â08 must be complete. In particular, `CoachSplitPayload.swift` and the `Split` model must exist so the method signature compiles.

---

## MODIFY `SplitDeck/Persistence/SplitDeckStore.swift`

Add the `replaceSplits` method in a new `// MARK: â Merge Support` section. Place it **after** the existing `// MARK: â Splits` section and **before** the closing brace of the class or any subsequent extensions.

### Before (find the end of the Splits section â look for the last method inside `// MARK: â Splits`)

```swift
    // MARK: â Splits
```

### After

```swift
    // MARK: â Splits

    // ... (existing splits methods remain unchanged) ...

    // MARK: â Merge Support

    /// Atomically replaces all splits for one athlete in one race with a new set.
    ///
    /// 1. Fetches every `SplitEntity` where `raceId` AND `athleteId` match.
    /// 2. Deletes all found entities.
    /// 3. Creates a new `SplitEntity` for each split in `newSplits` using the
    ///    existing `map(_:into:)` helper.
    /// 4. Saves the context.
    ///
    /// - Parameters:
    ///   - raceId:    The UUID of the race whose splits are being replaced.
    ///   - athleteId: The UUID of the athlete whose splits are being replaced.
    ///   - newSplits: The replacement `Split` values (ordered by `lapIndex`).
    /// - Throws: Any Core Data save error propagated from `ctx.save()`.
    func replaceSplits(for raceId: UUID, athleteId: UUID, with newSplits: [Split]) throws {
        let req = SplitEntity.fetchRequest()
        req.predicate = NSPredicate(
            format: "raceId == %@ AND athleteId == %@",
            raceId as CVarArg,
            athleteId as CVarArg
        )
        let existing = try ctx.fetch(req)
        existing.forEach { ctx.delete($0) }

        for split in newSplits {
            let entity = SplitEntity(context: ctx)
            map(split, into: entity)
        }

        try ctx.save()
    }
```

**Important**: The call to `map(split, into: entity)` uses the same private helper that the existing split-saving methods use. Do not inline the property assignments â call the helper so all mappings stay consistent.

---

## Verification Checklist

- [ ] Build succeeds with no errors or warnings
- [ ] `SplitDeckStore` now has a `replaceSplits(for:athleteId:with:)` method
- [ ] The method signature is `func replaceSplits(for raceId: UUID, athleteId: UUID, with newSplits: [Split]) throws`
- [ ] The method is in a `// MARK: â Merge Support` section placed after `// MARK: â Splits`
- [ ] The predicate uses both `raceId` and `athleteId` â not just one of them
- [ ] Conceptual correctness: given splits `[58410, 118650]` for athlete X in race Y, calling `replaceSplits(for: Y, athleteId: X, with: newSplits)` where `newSplits` has `elapsedMs` values `[58440, 118720]` should delete the two old entities and save two new ones; a subsequent `fetchSplits(for: Y)` should return only the new values for athlete X
- [ ] No existing Splits methods are modified or removed
