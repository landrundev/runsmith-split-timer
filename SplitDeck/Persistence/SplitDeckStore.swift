import CoreData
import Foundation

final class SplitDeckStore: ObservableObject {

    private let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SplitDeck")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error { fatalError("Core Data store failed: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private var ctx: NSManagedObjectContext { container.viewContext }

    /// In-memory cache: athlete ID → races containing that athlete.
    /// Populated lazily by fetchRaces(forAthlete:); invalidated by save(_:Race) and delete(raceId:).
    private var athleteRaceCache: [UUID: [Race]] = [:]

    // MARK: – Athletes

    func fetchAthletes() throws -> [Athlete] {
        let req = AthleteEntity.fetchRequest()
        req.predicate = NSPredicate(format: "isArchived == NO OR isArchived == nil")
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return try ctx.fetch(req).map(map)
    }

    func save(_ athlete: Athlete) throws {
        let entity: AthleteEntity
        if let existing = try fetchAthleteEntity(id: athlete.id) {
            entity = existing
        } else {
            entity = AthleteEntity(context: ctx)
        }
        map(athlete, into: entity)
        try ctx.save()
    }

    /// Finds an existing athlete by name (case-insensitive) or silently creates
    /// a new one with a minimal profile. Used by spectator mode to avoid forcing
    /// parents through full roster setup.
    func findOrCreateSpectatorAthlete(name: String, gender: Gender = .male) throws -> Athlete {
        let req = AthleteEntity.fetchRequest()
        req.predicate = NSPredicate(format: "name ==[cd] %@", name)
        req.fetchLimit = 1
        if let existing = try ctx.fetch(req).first {
            return map(existing)
        }
        let athlete = Athlete(
            name: name,
            colorHex: RosterImporter.colorPalette.randomElement() ?? "#FF3B30",
            gender: gender
        )
        try save(athlete)
        return athlete
    }

    func delete(athleteId: UUID) throws {
        guard let entity = try fetchAthleteEntity(id: athleteId) else { return }
        ctx.delete(entity)
        try ctx.save()
    }

    // MARK: – Meets

    func fetchMeets() throws -> [Meet] {
        let req = MeetEntity.fetchRequest()
        req.predicate = NSPredicate(format: "isArchived == NO OR isArchived == nil")
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return try ctx.fetch(req).map(map)
    }

    func save(_ meet: Meet) throws {
        let entity: MeetEntity
        if let existing = try fetchMeetEntity(id: meet.id) {
            entity = existing
        } else {
            entity = MeetEntity(context: ctx)
        }
        map(meet, into: entity)
        try ctx.save()
    }

    func delete(meetId: UUID) throws {
        let races = try fetchRaces(for: meetId)
        for race in races { try delete(raceId: race.id) }
        guard let entity = try fetchMeetEntity(id: meetId) else { return }
        ctx.delete(entity)
        try ctx.save()
    }

    // MARK: – Races

    func fetchRaces(for meetId: UUID?) throws -> [Race] {
        let req = RaceEntity.fetchRequest()
        let archiveFilter = NSPredicate(format: "isArchived == NO OR isArchived == nil")
        if let meetId {
            let meetFilter = NSPredicate(format: "meetId == %@", meetId as CVarArg)
            req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [meetFilter, archiveFilter])
        } else {
            let nilFilter = NSPredicate(format: "meetId == nil")
            req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [nilFilter, archiveFilter])
        }
        if meetId != nil {
            // Meet races: respect user-defined sort order
            req.sortDescriptors = [
                NSSortDescriptor(key: "sortOrder", ascending: true),
                NSSortDescriptor(key: "name", ascending: true)
            ]
        } else {
            // Quick races: status first (pending → started), then by date
            req.sortDescriptors = [
                NSSortDescriptor(key: "status", ascending: true),
                NSSortDescriptor(key: "sortOrder", ascending: true),
                NSSortDescriptor(key: "startedAt", ascending: false),
                NSSortDescriptor(key: "name", ascending: true)
            ]
        }
        return try ctx.fetch(req).map(map)
    }

    func save(_ race: Race) throws {
        let entity: RaceEntity
        if let existing = try fetchRaceEntity(id: race.id) {
            entity = existing
        } else {
            entity = RaceEntity(context: ctx)
        }
        map(race, into: entity)
        try ctx.save()
        // Invalidate cached athlete→race mappings for all athletes in this race
        for id in race.athleteIds { athleteRaceCache.removeValue(forKey: id) }
    }

    func delete(raceId: UUID) throws {
        let req = SplitEntity.fetchRequest()
        req.predicate = NSPredicate(format: "raceId == %@", raceId as CVarArg)
        let splits = try ctx.fetch(req)
        splits.forEach { ctx.delete($0) }
        guard let entity = try fetchRaceEntity(id: raceId) else { return }
        // Capture athlete IDs before deleting so we can invalidate the cache
        let race = map(entity)
        ctx.delete(entity)
        try ctx.save()
        for id in race.athleteIds { athleteRaceCache.removeValue(forKey: id) }
    }

    // MARK: – Import Support

    /// Create a Race and any missing Athletes from a SharedRaceConfig.
    ///
    /// - Upserts athletes by UUID: if an Athlete with the same UUID already exists, it is
    ///   left unchanged. Otherwise a new Athlete is created from the SharedAthlete data.
    /// - Creates a new Race with `meetId: nil` and `status: .notStarted`.
    /// - Returns the created Race for immediate navigation to LiveTimingView.
    func importRace(from config: SharedRaceConfig) throws -> Race {
        // Upsert athletes
        for sharedAthlete in config.athletes {
            if (try? fetchAthleteEntity(id: sharedAthlete.id)) == nil {
                let athlete = Athlete(
                    id: sharedAthlete.id,
                    name: sharedAthlete.name,
                    teamName: nil,
                    colorHex: sharedAthlete.colorHex,
                    notes: nil,
                    gender: sharedAthlete.gender ?? .male
                )
                try save(athlete)
            }
        }

        // Create the race (Quick Race on this device, no meet association)
        let race = Race(
            meetId: nil,
            configId: config.configId,
            name: config.raceName,
            eventType: config.eventType,
            distanceMeters: config.distanceMeters,
            trackLengthMeters: config.trackLengthMeters,
            splitsPerLap: config.splitsPerLap,
            isUnlimitedSplits: config.isUnlimitedSplits,
            athleteIds: config.athletes.map(\.id),
            status: .notStarted
        )
        try save(race)
        return race
    }

    /// Create a Meet, its Races, and any missing Athletes from a SharedMeetConfig.
    ///
    /// - Creates the meet with the shared name, date, and location.
    /// - For each race in the config, upserts athletes and creates the race
    ///   associated with the new meet.
    /// - Returns the created Meet for navigation.
    func importMeet(from config: SharedMeetConfig) throws -> Meet {
        // Create the meet
        let meet = Meet(
            name: config.meetName,
            date: config.meetDate,
            location: config.meetLocation
        )
        try save(meet)

        // Import each race into this meet
        for raceConfig in config.races {
            // Upsert athletes
            for sharedAthlete in raceConfig.athletes {
                if (try? fetchAthleteEntity(id: sharedAthlete.id)) == nil {
                    let athlete = Athlete(
                        id: sharedAthlete.id,
                        name: sharedAthlete.name,
                        teamName: nil,
                        colorHex: sharedAthlete.colorHex,
                        notes: nil,
                        gender: sharedAthlete.gender ?? .male
                    )
                    try save(athlete)
                }
            }

            let race = Race(
                meetId: meet.id,
                configId: raceConfig.configId,
                name: raceConfig.raceName,
                eventType: raceConfig.eventType,
                distanceMeters: raceConfig.distanceMeters,
                trackLengthMeters: raceConfig.trackLengthMeters,
                splitsPerLap: raceConfig.splitsPerLap,
                isUnlimitedSplits: raceConfig.isUnlimitedSplits,
                athleteIds: raceConfig.athletes.map(\.id),
                status: .notStarted
            )
            try save(race)
        }

        return meet
    }

    // MARK: – Splits

    func fetchSplits(for raceId: UUID) throws -> [Split] {
        let req = SplitEntity.fetchRequest()
        req.predicate = NSPredicate(format: "raceId == %@", raceId as CVarArg)
        req.sortDescriptors = [NSSortDescriptor(key: "lapIndex", ascending: true)]
        return try ctx.fetch(req).map(map)
    }

    func save(_ split: Split) throws {
        let entity: SplitEntity
        if let existing = try fetchSplitEntity(id: split.id) {
            entity = existing
        } else {
            entity = SplitEntity(context: ctx)
        }
        map(split, into: entity)
        try ctx.save()
    }

    func delete(splitId: UUID) throws {
        guard let entity = try fetchSplitEntity(id: splitId) else { return }
        ctx.delete(entity)
        try ctx.save()
    }

    func saveBatch(_ splits: [Split]) throws {
        for split in splits {
            let entity: SplitEntity
            if let existing = try fetchSplitEntity(id: split.id) {
                entity = existing
            } else {
                entity = SplitEntity(context: ctx)
            }
            map(split, into: entity)
        }
        try ctx.save()
    }

    // MARK: – Merge Support

    /// Atomically replaces all splits for one athlete in one race with a new set.
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

    func markAsMerged(raceId: UUID) throws {
        let req = RaceEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", raceId as CVarArg)
        guard let entity = try ctx.fetch(req).first else { return }
        entity.isMerged = true
        try ctx.save()
    }

    // MARK: – Saved Relay Teams

    func fetchSavedRelayTeams() throws -> [SavedRelayTeam] {
        let req = SavedRelayTeamEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return try ctx.fetch(req).map(map)
    }

    func save(_ team: SavedRelayTeam) throws {
        let entity: SavedRelayTeamEntity
        if let existing = try fetchSavedRelayTeamEntity(id: team.id) {
            entity = existing
        } else {
            entity = SavedRelayTeamEntity(context: ctx)
        }
        map(team, into: entity)
        try ctx.save()
    }

    func delete(relayTeamId: UUID) throws {
        guard let entity = try fetchSavedRelayTeamEntity(id: relayTeamId) else { return }
        ctx.delete(entity)
        try ctx.save()
    }

    // MARK: – Cross-meet queries

    func fetchAllCompletedRaces() throws -> [Race] {
        let req = RaceEntity.fetchRequest()
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "status == %d", RaceStatus.completed.rawValue),
            NSPredicate(format: "isArchived == NO OR isArchived == nil")
        ])
        req.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        return try ctx.fetch(req).map(map)
    }

    // MARK: – Single race lookup

    func fetchRace(id: UUID) throws -> Race? {
        guard let entity = try fetchRaceEntity(id: id) else { return nil }
        return map(entity)
    }

    // MARK: – Athlete-centric queries (for profiles)

    func fetchRaces(forAthlete athleteId: UUID) throws -> [Race] {
        if let cached = athleteRaceCache[athleteId] { return cached }

        let req = RaceEntity.fetchRequest()
        req.predicate = NSPredicate(format: "isArchived == NO OR isArchived == nil")
        req.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        req.fetchLimit = 500
        let allRaces = try ctx.fetch(req).map(map)
        let result = allRaces.filter { $0.athleteIds.contains(athleteId) }
        athleteRaceCache[athleteId] = result
        return result
    }

    func fetchSplits(forAthlete athleteId: UUID) throws -> [Split] {
        let req = SplitEntity.fetchRequest()
        req.predicate = NSPredicate(format: "athleteId == %@", athleteId as CVarArg)
        req.sortDescriptors = [NSSortDescriptor(key: "elapsedMs", ascending: true)]
        return try ctx.fetch(req).map(map)
    }

    // MARK: – Archive / Unarchive

    func archive(athleteId: UUID) throws {
        guard let entity = try fetchAthleteEntity(id: athleteId) else { return }
        entity.isArchived = true
        try ctx.save()
    }

    func unarchive(athleteId: UUID) throws {
        guard let entity = try fetchAthleteEntity(id: athleteId) else { return }
        entity.isArchived = false
        try ctx.save()
    }

    func archive(meetId: UUID) throws {
        guard let entity = try fetchMeetEntity(id: meetId) else { return }
        entity.isArchived = true
        try ctx.save()
    }

    func unarchive(meetId: UUID) throws {
        guard let entity = try fetchMeetEntity(id: meetId) else { return }
        entity.isArchived = false
        try ctx.save()
    }

    func archive(raceId: UUID) throws {
        guard let entity = try fetchRaceEntity(id: raceId) else { return }
        entity.isArchived = true
        try ctx.save()
    }

    func unarchive(raceId: UUID) throws {
        guard let entity = try fetchRaceEntity(id: raceId) else { return }
        entity.isArchived = false
        try ctx.save()
    }

    /// Bulk-update sortOrder for an ordered list of race IDs.
    func updateRaceSortOrders(_ orderedIds: [UUID]) throws {
        for (index, id) in orderedIds.enumerated() {
            if let entity = try fetchRaceEntity(id: id) {
                entity.sortOrder = Int16(index)
            }
        }
        try ctx.save()
    }

    // MARK: – Existence Checks

    /// Returns true if a meet with this ID exists in Core Data.
    func meetExists(id: UUID) -> Bool {
        (try? fetchMeetEntity(id: id)) != nil
    }

    /// Returns true if a race with this configId exists in Core Data.
    func raceExists(configId: UUID) -> Bool {
        let req = RaceEntity.fetchRequest()
        req.predicate = NSPredicate(format: "configId == %@", configId as CVarArg)
        req.fetchLimit = 1
        return (try? ctx.count(for: req)) ?? 0 > 0
    }

    /// Returns the Race matching a configId, if it exists.
    func fetchRace(byConfigId configId: UUID) -> Race? {
        let req = RaceEntity.fetchRequest()
        req.predicate = NSPredicate(format: "configId == %@", configId as CVarArg)
        req.fetchLimit = 1
        guard let entity = try? ctx.fetch(req).first else { return nil }
        return map(entity)
    }

    // MARK: – Coach Import Cache

    /// Saves a CoachMeetPayload to the app's cache directory for later review.
    func cacheImportedPayload(_ payload: CoachMeetPayload) {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CoachImports", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let filename = "\(payload.id.uuidString).json"
        let fileURL = cacheDir.appendingPathComponent(filename)

        if let data = PayloadEncoder.encodeJSON(payload) {
            try? data.write(to: fileURL)
        }
    }

    /// Loads all cached CoachMeetPayloads, sorted by export date descending.
    func fetchCachedPayloads() -> [CoachMeetPayload] {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CoachImports", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> CoachMeetPayload? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return PayloadEncoder.decodeMeetPayload(from: data)
            }
            .sorted { $0.exportedAt > $1.exportedAt }
    }

    /// Deletes a cached payload by its ID.
    func deleteCachedPayload(id: UUID) {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CoachImports", isDirectory: true)
        let fileURL = cacheDir.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: – Fetch Archived

    func fetchArchivedAthletes() throws -> [Athlete] {
        let req = AthleteEntity.fetchRequest()
        req.predicate = NSPredicate(format: "isArchived == YES")
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return try ctx.fetch(req).map(map)
    }

    func fetchArchivedMeets() throws -> [Meet] {
        let req = MeetEntity.fetchRequest()
        req.predicate = NSPredicate(format: "isArchived == YES")
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return try ctx.fetch(req).map(map)
    }

    func fetchArchivedRaces() throws -> [Race] {
        let req = RaceEntity.fetchRequest()
        req.predicate = NSPredicate(format: "isArchived == YES")
        req.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        return try ctx.fetch(req).map(map)
    }

    // MARK: – Private fetch helpers

    private func fetchAthleteEntity(id: UUID) throws -> AthleteEntity? {
        let req = AthleteEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try ctx.fetch(req).first
    }

    private func fetchMeetEntity(id: UUID) throws -> MeetEntity? {
        let req = MeetEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try ctx.fetch(req).first
    }

    private func fetchRaceEntity(id: UUID) throws -> RaceEntity? {
        let req = RaceEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try ctx.fetch(req).first
    }

    private func fetchSplitEntity(id: UUID) throws -> SplitEntity? {
        let req = SplitEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try ctx.fetch(req).first
    }

    private func fetchSavedRelayTeamEntity(id: UUID) throws -> SavedRelayTeamEntity? {
        let req = SavedRelayTeamEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try ctx.fetch(req).first
    }

    // MARK: – Mapping: entity → domain struct

    private func map(_ entity: AthleteEntity) -> Athlete {
        Athlete(
            id: entity.id!,
            name: entity.name!,
            teamName: entity.teamName,
            colorHex: entity.colorHex!,
            notes: entity.notes,
            gender: entity.gender.flatMap { Gender(rawValue: $0) } ?? .male,
            isArchived: entity.isArchived
        )
    }

    private func map(_ entity: MeetEntity) -> Meet {
        Meet(
            id: entity.id!,
            name: entity.name!,
            date: entity.date!,
            location: entity.location,
            isArchived: entity.isArchived
        )
    }

    private func map(_ entity: RaceEntity) -> Race {
        let athleteIds: [UUID]
        if let data = entity.athleteIdsData,
           let decoded = try? JSONDecoder().decode([UUID].self, from: data) {
            athleteIds = decoded
        } else {
            athleteIds = []
        }
        return Race(
            id: entity.id!,
            meetId: entity.meetId,
            configId: entity.configId,
            name: entity.name!,
            eventType: EventType(rawValue: entity.eventType) ?? .custom,
            distanceMeters: Int(entity.distanceMeters),
            trackLengthMeters: Int(entity.trackLengthMeters),
            splitsPerLap: Int(entity.splitsPerLap),
            isUnlimitedSplits: entity.isUnlimitedSplits,
            athleteIds: athleteIds,
            startedAt: entity.startedAt,
            endedAt: entity.endedAt,
            status: RaceStatus(rawValue: entity.status) ?? .notStarted,
            isArchived: entity.isArchived,
            isMerged: entity.isMerged,
            sortOrder: Int(entity.sortOrder)
        )
    }

    private func map(_ entity: SplitEntity) -> Split {
        Split(
            id: entity.id!,
            raceId: entity.raceId!,
            athleteId: entity.athleteId!,
            lapIndex: Int(entity.lapIndex),
            elapsedMs: Int(entity.elapsedMs)
        )
    }

    // MARK: – Mapping: domain struct → entity

    private func map(_ athlete: Athlete, into entity: AthleteEntity) {
        entity.id = athlete.id
        entity.name = athlete.name
        entity.teamName = athlete.teamName
        entity.colorHex = athlete.colorHex
        entity.notes = athlete.notes
        entity.gender = athlete.gender.rawValue
        entity.isArchived = athlete.isArchived
    }

    private func map(_ meet: Meet, into entity: MeetEntity) {
        entity.id = meet.id
        entity.name = meet.name
        entity.date = meet.date
        entity.location = meet.location
        entity.isArchived = meet.isArchived
    }

    private func map(_ race: Race, into entity: RaceEntity) {
        entity.id = race.id
        entity.meetId = race.meetId
        entity.configId = race.configId
        entity.name = race.name
        entity.eventType = race.eventType.rawValue
        entity.distanceMeters = Int32(race.distanceMeters)
        entity.trackLengthMeters = Int32(race.trackLengthMeters)
        entity.splitsPerLap = Int16(race.splitsPerLap)
        entity.isUnlimitedSplits = race.isUnlimitedSplits
        entity.athleteIdsData = try? JSONEncoder().encode(race.athleteIds)
        entity.startedAt = race.startedAt
        entity.endedAt = race.endedAt
        entity.status = race.status.rawValue
        entity.isArchived = race.isArchived
        entity.isMerged = race.isMerged
        entity.sortOrder = Int16(race.sortOrder)
    }

    private func map(_ split: Split, into entity: SplitEntity) {
        entity.id = split.id
        entity.raceId = split.raceId
        entity.athleteId = split.athleteId
        entity.lapIndex = Int32(split.lapIndex)
        entity.elapsedMs = Int64(split.elapsedMs)
    }

    private func map(_ entity: SavedRelayTeamEntity) -> SavedRelayTeam {
        let athleteIds: [UUID]
        if let data = entity.athleteIdsData,
           let decoded = try? JSONDecoder().decode([UUID].self, from: data) {
            athleteIds = decoded
        } else {
            athleteIds = []
        }
        return SavedRelayTeam(
            id: entity.id!,
            name: entity.name!,
            eventType: EventType(rawValue: entity.eventType) ?? .relay4x100,
            gender: Gender(rawValue: entity.gender!) ?? .male,
            athleteIds: athleteIds,
            createdAt: entity.createdAt!
        )
    }

    private func map(_ team: SavedRelayTeam, into entity: SavedRelayTeamEntity) {
        entity.id = team.id
        entity.name = team.name
        entity.eventType = team.eventType.rawValue
        entity.gender = team.gender.rawValue
        entity.athleteIdsData = try? JSONEncoder().encode(team.athleteIds)
        entity.createdAt = team.createdAt
    }
}
