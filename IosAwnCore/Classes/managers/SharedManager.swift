//
//  SharedManager.swift
//  awesome_notifications
//
//  Created by Rafael Setragni on 11/09/20.
//

import Foundation

public class SharedManager {

    private let serialQueue: DispatchQueue
    private let _userDefaults: UserDefaults?
    private let tag: String
    private var objectList: [String: Any?]

    public init(tag: String) {
        self.tag = tag
        self.serialQueue = DispatchQueue(label: "aw.sharedManager.\(tag)")
        self._userDefaults = UserDefaults(
            suiteName: Definitions.USER_DEFAULT_TAG
        )
        self.objectList = [:]

        // Initial load should be done synchronously to ensure data is available
        self.serialQueue.sync {
            self.objectList = self._userDefaults?.dictionary(forKey: tag) ?? [:]
        }
    }

    private func refreshObjects() {
        serialQueue.sync {
            self.objectList = self._userDefaults?.dictionary(forKey: tag) ?? [:]
        }
    }

    private func updateObjects() {
        serialQueue.sync {
            self._userDefaults?.removeObject(forKey: tag)
            self._userDefaults?.setValue(objectList, forKey: tag)
            self._userDefaults?
                .synchronize()  // Ensure changes are written immediately
        }
    }

    public func get(referenceKey: String) -> [String: Any?]? {
        return serialQueue.sync {
            refreshObjects()
            return objectList[referenceKey] as? [String: Any?]
        }
    }

    public func set(_ data: [String: Any?]?, referenceKey: String) {
        guard !StringUtils.shared
            .isNullOrEmpty(referenceKey) && data != nil else { return }

        serialQueue.sync {
            refreshObjects()
            objectList[referenceKey] = data!
            updateObjects()
        }
    }

    public func remove(referenceKey: String) -> Bool {
        guard !StringUtils.shared
            .isNullOrEmpty(referenceKey) else { return false }

        return serialQueue.sync {
            refreshObjects()
            objectList.removeValue(forKey: referenceKey)
            updateObjects()
            return true
        }
    }

    public func removeAll() {
        serialQueue.sync {
            objectList.removeAll()
            updateObjects()
        }
    }

    public func getAllObjectsStarting(with keyFragment: String) -> [[String: Any?]] {
        return serialQueue.sync {
            refreshObjects()
            var returnedList: [[String: Any?]] = []

            for (key, data) in objectList {
                if !key.starts(with: keyFragment) { continue }
                if let dictionary = data as? [String: Any?] {
                    returnedList.append(dictionary)
                }
            }

            return returnedList
        }
    }

    public func getAllObjects() -> [[String: Any?]] {
        return serialQueue.sync {
            refreshObjects()
            var returnedList: [[String: Any?]] = []

            for (_, data) in objectList {
                if let dictionary = data as? [String: Any?] {
                    returnedList.append(dictionary)
                }
            }

            return returnedList
        }
    }
}
