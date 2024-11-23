//
//  SharedManager.swift
//  awesome_notifications
//
//  Created by Rafael Setragni on 11/09/20.
//

import Foundation

public class SharedManager {

  // Use a concurrent queue for read-write operations
  private let queue = DispatchQueue(label: "aw.sharedmanager", attributes: .concurrent)
  private let _userDefaults = UserDefaults(suiteName: Definitions.USER_DEFAULT_TAG)

  let tag: String
  private var objectList: [String: Any?]

  public init(tag: String) {
    self.tag = tag
    self.objectList = _userDefaults?.dictionary(forKey: tag) ?? [:]
  }

  private func loadObjectList() -> [String: Any?] {
    return _userDefaults?.dictionary(forKey: tag) ?? [:]
  }

  private func saveObjectList(_ list: [String: Any?]) {
    _userDefaults?.removeObject(forKey: tag)
    _userDefaults?.setValue(list, forKey: tag)
  }

  public func get(referenceKey: String) -> [String: Any?]? {
    var result: [String: Any?]?
    queue.sync {
      result = loadObjectList()[referenceKey] as? [String: Any?]
    }
    return result
  }

  public func set(_ data: [String: Any?]?, referenceKey: String) {
    guard !StringUtils.shared.isNullOrEmpty(referenceKey), let data = data else { return }

    queue.async(flags: .barrier) {
      var currentList = self.loadObjectList()
      currentList[referenceKey] = data
      self.saveObjectList(currentList)
    }
  }

  public func remove(referenceKey: String) -> Bool {
    guard !StringUtils.shared.isNullOrEmpty(referenceKey) else { return false }

    var success = false
    queue.async(flags: .barrier) {
      var currentList = self.loadObjectList()
      if currentList.removeValue(forKey: referenceKey) != nil {
        self.saveObjectList(currentList)
        success = true
      }
    }
    return success
  }

  public func removeAll() {
    queue.async(flags: .barrier) {
      self.saveObjectList([:])
    }
  }

  public func getAllObjectsStarting(with keyFragment: String) -> [[String: Any?]] {
    var result: [[String: Any?]] = []
    queue.sync {
      let currentList = self.loadObjectList()
      result = currentList.compactMap { key, value in
        if key.starts(with: keyFragment),
          let dictionary = value as? [String: Any?]
        {
          return dictionary
        }
        return nil
      }
    }
    return result
  }

  public func getAllObjects() -> [[String: Any?]] {
    var result: [[String: Any?]] = []
    queue.sync {
      let currentList = self.loadObjectList()
      result = currentList.compactMap { _, value in
        value as? [String: Any?]
      }
    }
    return result
  }
}
