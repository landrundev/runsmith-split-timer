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

    // MARK: – Athletes

    func fetchAthletes() throws -> [Athlete] {
        let req = AthleteEntity.fetchRequest()
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

    func delete(athleteId: UUID) throws {
        guard let entity = try fetchAthleteEntity(id: athleteId) else { return }
        ctx.delete(entity)
        try ctx.save()
    }

    // MARK: – Meets

    func fetchMeets() throws -> [Meet] {
        let req = MeetEntity.fetchRequest()
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
        if let meetId {
            req.predicate = NSPredicate(format: "meetId == %@", meetId as CVarArg)
        } else {
            req.predicate = NSPredicate(format: "meetId == nil")
        }
        req.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
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
    }

    func delete(raceId: UUID) throws {
        let req = SplitEntity.fetchRequest()
        req.predicate = NSPredicate(format: "raceId == %@", raceId as CVarArg)
        let splits = try ctx.fetch(req)
        splits.forEach { ctx.delete($0) }
        guard let entity = try fetchRaceEntity(id: raceId) else { return }
        ctx.delete(entity)
        try ctx.save()
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

    // MARK: – Mapping: entity → domain struct

    private func map(_ entity: AthleteEntity) -> Athlete {
        Athlete(
            id: entity.id!,
            name: entity.name!,
            teamName: entity.teamName,
            colorHex: entity.colorHex!,
            notes: entity.notes
        )
    }

    private func map(_ entity: MeetEntity) -> Meet {
        Meet(
            id: entity.id!,
            name: entity.name!,
            date: entity.date!,
            location: entity.location
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
            name: entity.name!,
            eventType: EventType(rawValue: entity.eventType) ?? .custom,
            distanceMeters: Int(entity.distanceMeters),
            trackLengthMeters: Int(entity.trackLengthMeters),
            splitsPerLap: Int(entity.splitsPerLap),
            athleteIds: athleteIds,
            startedAt: entity.startedAt,
            endedAt: entity.endedAt,
            status: RaceStatus(rawValue: entity.status) ?? .notStarted
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
    }

    private func map(_ meet: Meet, into entity: MeetEntity) {
        entity.id = meet.id
        entity.name = meet.name
        entity.date = meet.date
        entity.location = meet.location
    }

    private func map(_ race: Race, into entity: RaceEntity) {
        entity.id = race.id
        entity.meetId = race.meetId
        entity.name = race.name
        entity.eventType = race.eventType.rawValue
        entity.distanceMeters = Int32(race.distanceMeters)
        entity.trackLengthMeters = Int32(race.trackLengthMeters)
        entity.splitsPerLap = Int16(race.splitsPerLap)
        entity.athleteIdsData = try? JSONEncoder().encode(race.athleteIds)
        entity.startedAt = race.startedAt
        entity.endedAt = race.endedAt
        entity.status = race.status.rawValue
    }

    private func map(_ split: Split, into entity: SplitEntity) {
        entity.id = split.id
        entity.raceId = split.raceId
        entity.athleteId = split.athleteId
        entity.lapIndex = Int32(split.lapIndex)
        entity.elapsedMs = Int64(split.elapsedMs)
    }
}
