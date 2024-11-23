//
//  ScheduleManager.swift
//  awesome_notifications
//
//  Created by Rafael Setragni on 23/09/20.
//

import Foundation

public class ScheduleManager: EventManager {

    private let storage: SharedManager
    private let pendingShared: SharedManager
    private var pendingSchedules: [String: String]
    private let serialQueue: DispatchQueue

    // **************************** SINGLETON PATTERN *************************************

    static var instance: ScheduleManager?
    public static var shared: ScheduleManager {
        ScheduleManager.instance = ScheduleManager.instance ?? ScheduleManager()
        return ScheduleManager.instance!
    }

    private override init() {
        self.storage = SharedManager(tag: "NotificationSchedule")
        self.pendingShared = SharedManager(tag: "PendingSchedules")
        self.serialQueue = DispatchQueue(label: "aw.scheduleManager")
        self.pendingSchedules = pendingShared
            .get(referenceKey: "pending") as? [String: String] ?? [:]
        super.init()
    }

    public func removeSchedule(id: Int) -> Bool {
        return serialQueue.sync {
            let referenceKey = String(id)
            for (epoch, scheduledId) in pendingSchedules where scheduledId == referenceKey {
                pendingSchedules.removeValue(forKey: epoch)
            }
            updatePendingList()
            return storage.remove(referenceKey: referenceKey)
        }
    }

    public func listSchedules() -> [NotificationModel] {
        return serialQueue.sync {
            var returnedList: [NotificationModel] = []
            let dataList = storage.getAllObjects()

            for data in dataList {
                guard let schedule = NotificationModel(fromMap: data) else {
                    continue
                }
                returnedList.append(schedule)
            }

            return returnedList
        }
    }

    public func saveSchedule(notification: NotificationModel, nextDate: Date) {
        serialQueue.sync {
            let referenceKey = String(notification.content?.id ?? 0)
            let epoch = nextDate.timeIntervalSince1970.description

            pendingSchedules[epoch] = referenceKey
            storage.set(notification.toMap(), referenceKey: referenceKey)
            updatePendingList()
        }
    }

    private func updatePendingList() {
        serialQueue.sync {
            pendingShared.set(pendingSchedules, referenceKey: "pending")
        }
    }

    public func syncAllPendingSchedules(
        whenGotResults completionHandler: @escaping (
            [NotificationModel]
        ) throws -> Void
    ) {
        let center = UNUserNotificationCenter.current()

        // Create a dispatch group to ensure proper synchronization
        let group = DispatchGroup()
        group.enter()

        center.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else {
                group.leave()
                return
            }

            self.serialQueue.async {
                do {
                    let schedules = self.listSchedules()
                    var activeSchedules: [NotificationModel] = []

                    if requests.isEmpty {
                        // If no active requests, cancel all schedules
                        _ = CancellationManager.shared.cancelAllSchedules()
                    } else if !schedules.isEmpty {
                        // Create a set of active request IDs for faster lookup
                        let activeRequestIds = Set(
                            requests.map { $0.identifier
                            })

                        for notificationModel in schedules {
                            guard let id = notificationModel.content?.id else {
                                continue
                            }
                            let identifier = String(id)

                            if activeRequestIds.contains(identifier) {
                                activeSchedules.append(notificationModel)
                            } else {
                                // Schedule not found in active requests, cancel it
                                _ = CancellationManager.shared
                                    .cancelSchedule(byId: id)
                            }
                        }
                    }

                    DispatchQueue.main.async {
                        do {
                            try completionHandler(activeSchedules)
                        } catch {
                            Logger.shared.e(
                                "ScheduleManager", "Error in completion handler: \(error.localizedDescription)")
                        }
                        group.leave()
                    }
                } catch {
                    DispatchQueue.main.async {
                        Logger.shared.e(
                            "ScheduleManager", "Error syncing schedules: \(error.localizedDescription)")
                        do {
                            try completionHandler([])
                        } catch {
                            Logger.shared.e(
                                "ScheduleManager", "Error in completion handler: \(error.localizedDescription)")
                        }
                        group.leave()
                    }
                }
            }
        }

        // Wait for completion with a reasonable timeout
        _ = group.wait(timeout: .now() + 30)
    }

    public func getScheduleByKey(id: Int) -> NotificationModel? {
        return serialQueue.sync {
            return NotificationModel(
                fromMap: storage.get(referenceKey: String(id))
            )
        }
    }

    public func cancelScheduled(id: Int) -> Bool {
        return serialQueue.sync {
            return storage.remove(referenceKey: String(id))
        }
    }

    public func cancelAllSchedules() -> Bool {
        return serialQueue.sync {
            storage.removeAll()
            pendingShared.removeAll()
            pendingSchedules.removeAll()
            return true
        }
    }

    public func listPendingSchedules(referenceDate: Date) -> [NotificationModel] {
        return serialQueue.sync {
            var returnedList: [NotificationModel] = []
            let referenceEpoch = referenceDate.timeIntervalSince1970.description

            for (epoch, id) in pendingSchedules {
                if epoch <= referenceEpoch {
                    if let notificationModel = getScheduleByKey(
                        id: Int(id) ?? 0
                    ) {
                        returnedList.append(notificationModel)
                    }
                }
            }

            return returnedList
        }
    }
}
