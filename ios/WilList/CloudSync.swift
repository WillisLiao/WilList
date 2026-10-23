import CloudKit
import Observation
import UIKit
import WilListCore

/// Keeps one plan on all of a student's devices, through their private iCloud database. The plan
/// is one record, saved whole (`willist.v1`, compressed). When both devices changed it, the two
/// are merged against the copy both last agreed on (`PlanMerge`), so a tick on the phone and a new
/// to-do on the iPad both survive. CloudKit's sync engine decides when to send and fetch, and
/// fetches when iCloud says another device changed something, in the background too.
/// ponytail: one record per plan; records per item if plans ever near CloudKit's 1 MB.
@Observable
final class CloudSync {
    static let shared = CloudSync()

    /// Whether the plan can sync: false without an iCloud account, or with iCloud off for WilList.
    private(set) var available = false

    @ObservationIgnored private var engine: CKSyncEngine?
    private let container = CKContainer(identifier: "iCloud.com.lull.willist")
    private let zone = CKRecordZone.ID(zoneName: "WilList")
    private var planID: CKRecord.ID { CKRecord.ID(recordName: "plan", zoneID: zone) }
    private var store: Store { Store.shared }

    // What the sync keeps between launches, beside the app's own files: the engine's place in the
    // stream of changes, the plan as iCloud last had it, and that record's version.
    private let folder = URL.applicationSupportDirectory.appending(path: "iCloud")
    private var stateFile: URL { folder.appending(path: "engine.json") }
    private var baseFile: URL { folder.appending(path: "plan.json") }
    private var recordFile: URL { folder.appending(path: "record.data") }

    func start() {
        #if DEBUG
        // UI tests work on plans of their own, never the one in iCloud.
        guard UserDefaults.standard.string(forKey: "plan") == nil else { return }
        #endif
        guard engine == nil else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let saved = (try? Data(contentsOf: stateFile)).flatMap { try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0) }
        engine = CKSyncEngine(CKSyncEngine.Configuration(database: container.privateCloudDatabase, stateSerialization: saved, delegate: self))
        if saved == nil { engine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zone))]) }
        // Changes made while the sync wasn't running, on a widget or before this version.
        planChanged()
        Task { await checkAccount() }
    }

    /// The plan changed on this device: send it when the engine next sends.
    func planChanged() {
        engine?.state.add(pendingRecordZoneChanges: [.saveRecord(planID)])
    }

    private func checkAccount() async {
        available = (try? await container.accountStatus()) == .available
    }

    // MARK: the plan as a record

    private func encoded(_ state: AppState) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(state)
    }

    private func plan(in record: CKRecord) -> Data? {
        (record["plan"] as? Data).flatMap { try? ($0 as NSData).decompressed(using: .lzfse) as Data }
    }

    /// The last record iCloud confirmed, carrying the version a save must name.
    private var lastRecord: CKRecord? {
        guard let data = try? Data(contentsOf: recordFile), let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        defer { coder.finishDecoding() }
        return CKRecord(coder: coder)
    }

    /// iCloud has `record`: keep its version, and its plan as the copy both sides agree on.
    private func agreed(on record: CKRecord) {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        try? coder.encodedData.write(to: recordFile, options: .atomic)
        if let plan = plan(in: record) { try? plan.write(to: baseFile, options: .atomic) }
    }

    private func forget() {
        try? FileManager.default.removeItem(at: baseFile)
        try? FileManager.default.removeItem(at: recordFile)
    }

    /// The plan as another device left it: merge it into this one, and send the result back if
    /// it has anything iCloud doesn't.
    private func take(_ record: CKRecord) {
        guard let remote = plan(in: record), let local = encoded(store.state) else { return }
        let base = try? Data(contentsOf: baseFile)
        guard let merged = try? PlanMerge.merge(base: base, local: local, remote: remote),
              let state = try? JSONDecoder().decode(AppState.self, from: merged) else { return }
        agreed(on: record)
        store.takeSynced(state)
        if (try? JSONDecoder().decode(AppState.self, from: remote)) != store.state { planChanged() }
    }
}

extension CloudSync: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            if let data = try? JSONEncoder().encode(update.stateSerialization) { try? data.write(to: stateFile, options: .atomic) }
        case .accountChange(let change):
            switch change.changeType {
            case .signIn:
                syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zone))])
                planChanged()
            case .signOut, .switchAccounts:
                // The plan stays on the device; what was agreed with the old account doesn't.
                forget()
            @unknown default:
                break
            }
            await checkAccount()
        case .fetchedDatabaseChanges(let changes):
            // WilList's iCloud data was deleted (in Settings): start again from this device's plan.
            if changes.deletions.contains(where: { $0.zoneID == zone }) {
                forget()
                syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zone))])
                planChanged()
            }
        case .fetchedRecordZoneChanges(let changes):
            for modification in changes.modifications where modification.record.recordID == planID {
                take(modification.record)
            }
            if changes.deletions.contains(where: { $0.recordID == planID }) {
                forget()
                planChanged()
            }
        case .sentRecordZoneChanges(let sent):
            for record in sent.savedRecords where record.recordID == planID { agreed(on: record) }
            for failure in sent.failedRecordSaves where failure.record.recordID == planID {
                switch failure.error.code {
                case .serverRecordChanged:
                    // Another device got there first: merge with what it sent, then send again.
                    if let server = failure.error.serverRecord { take(server) }
                    planChanged()
                case .zoneNotFound:
                    syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zone))])
                    planChanged()
                case .unknownItem:
                    forget()
                    planChanged()
                default:
                    break // the engine tries again by itself
                }
            }
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        guard !pending.isEmpty else { return nil }
        // Nothing iCloud doesn't have already.
        if lastRecord != nil, let base = try? Data(contentsOf: baseFile),
           (try? JSONDecoder().decode(AppState.self, from: base)) == store.state {
            syncEngine.state.remove(pendingRecordZoneChanges: pending)
            return nil
        }
        guard let plan = encoded(store.state), let packed = try? (plan as NSData).compressed(using: .lzfse) as Data else { return nil }
        let record = lastRecord ?? CKRecord(recordType: "Plan", recordID: planID)
        record["plan"] = packed
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { $0 == record.recordID ? record : nil }
    }
}
