//
//  OrderedDictionary.swift
//  WhatHabit
//
//  Created by Jon Bash on 2020-05-23.
//  Copyright © 2020 Jon Bash. All rights reserved.
//

import Foundation


public struct OrderedDictionary<Key: Hashable, Value> {
   public typealias KeyValuePair = (key: Key, value: Value)

   public private(set) var keyValuePairs: [Key: Value]
   public private(set) var orderedKeys: [Key]

   public var count: Int { orderedKeys.count }

   // MARK: - Init

   public init() {
      self.orderedKeys = []
      self.keyValuePairs = [:]
   }

   public init(_ dictionary: [Key: Value], where predicate: (Key, Key) throws -> Bool) rethrows {
      self.orderedKeys = try dictionary.keys.sorted(by: predicate)
      self.keyValuePairs = dictionary
   }

   public init(_ orderedPairs: [KeyValuePair]) {
      self.init()
      for (key, value) in orderedPairs {
         self.orderedKeys.append(key)
         self.keyValuePairs[key] = value
      }
   }
}


extension OrderedDictionary: ExpressibleByDictionaryLiteral {
   public init(dictionaryLiteral elements: (Key, Value)...) {
      self.init(elements)
   }
}

extension OrderedDictionary: ExpressibleByArrayLiteral {
   public init(arrayLiteral elements: KeyValuePair...) {
      self.init(elements)
   }
}


extension OrderedDictionary where Key: Comparable {
   public init(_ dictionary: [Key: Value]) {
      self.init(dictionary, where: { $0 < $1 })
   }
}


extension OrderedDictionary {

   // MARK: - Read

   public var orderedValues: [Value] {
      keyValuePairs.map { _, value in value }
   }

   public var orderedPairs: [KeyValuePair] {
      keyValuePairs.map { $0 }
   }

   public func value(forKey key: Key) -> Value? {
      keyValuePairs[key]
   }

   public func value(forIndex index: Int) -> Value? {
      guard index < orderedKeys.count else { return nil }
      let key = orderedKeys[index]
      return keyValuePairs[key]
   }

   public func key(forIndex index: Int) -> Key? {
      guard index < orderedKeys.count else { return nil }
      return orderedKeys[index]
   }

   public func keyValuePair(forIndex index: Int) -> (key: Key, value: Value)? {
      guard let key = key(forIndex: index) else { return nil }
      return (key, keyValuePairs[key]!)
   }

   // MARK: - Add / Insert

   public mutating func addValue(_ value: Value, forKey key: Key) {
      keyValuePairs[key] = value
      if let index = orderedKeys.firstIndex(of: key) {
         orderedKeys.remove(at: index)
      }
      orderedKeys.append(key)
   }

   public func addingValue(_ value: Value, forKey key: Key) -> Self {
      var copy = self
      copy.addValue(value, forKey: key)
      return copy
   }

   public mutating func insert(_ value: Value, forKey key: Key, at index: Int) {
      keyValuePairs[key] = value
      guard !orderedKeys.contains(key) else { return }
      orderedKeys.insert(key, at: index)
   }

   public func inserting(_ value: Value, forKey key: Key, at index: Int) -> Self {
      var copy = self
      copy.insert(value, forKey: key, at: index)
      return copy
   }

   // MARK: - Remove

   @discardableResult
   public mutating func removeValue(forKey key: Key) -> Value? {
      if let index = orderedKeys.firstIndex(of: key) {
         orderedKeys.remove(at: index)
         return keyValuePairs.removeValue(forKey: key)
      } else { return nil }
   }

   @discardableResult
   public mutating func remove(at index: Int) -> KeyValuePair? {
      guard index < count else { return nil }
      let key = orderedKeys.remove(at: index)
      guard let value = keyValuePairs.removeValue(forKey: key) else { return nil }
      return (key: key, value: value)
   }

   public mutating func removeFirst() -> KeyValuePair? {
      remove(at: 0)
   }

   public mutating func removeLast() -> KeyValuePair? {
      remove(at: count - 1)
   }

   public mutating func removeAll() {
      keyValuePairs = [:]
      orderedKeys = []
   }

   // MARK: - Merge/Join

   public mutating func append<D: Sequence>(
      elements: D,
      uniquingKeysWith combine: (Value, Value) throws -> Value = { $1 }
   ) rethrows where D.Element == KeyValuePair {
      for (key, newValue) in elements {
         var finalValue = newValue
         if let oldValue = value(forKey: key) {
            finalValue = try combine(oldValue, newValue)
         }
         self.addValue(finalValue, forKey: key)
      }
   }

   public func joined<D: Sequence>(
      with otherDictionary: D,
      uniquingKeysWith combine: (Value, Value) throws -> Value = { $1 }
   ) rethrows -> Self where D.Element == KeyValuePair {
      var newDict = self
      try newDict.append(elements: otherDictionary, uniquingKeysWith: combine)
      return newDict
   }

}

// MARK: - Sequence

extension OrderedDictionary: Sequence {
   public struct Iterator: IteratorProtocol {
      private var currentIndex: Int = 0
      let orderedDictionary: OrderedDictionary<Key, Value>

      init(_ orderedDictionary: OrderedDictionary<Key, Value>) {
         self.orderedDictionary = orderedDictionary
      }

      public mutating func next() -> (key: Key, value: Value)? {
         guard let pair = orderedDictionary.keyValuePair(forIndex: currentIndex)
            else { return nil }
         currentIndex += 1
         return pair
      }
   }

   public func makeIterator() -> Iterator { Iterator(self) }
}


// MARK: - Collection

extension OrderedDictionary: MutableCollection {
   public var startIndex: Int { orderedKeys.startIndex }
   public var endIndex: Int { orderedKeys.endIndex }

   public subscript(_ key: Key) -> Value? {
      get { keyValuePairs[key] }
      set {
         keyValuePairs[key] = newValue
         if newValue != nil && !keyValuePairs.keys.contains(key) {
            orderedKeys.append(key)
         } else if newValue == nil, let index = orderedKeys.firstIndex(of: key) {
            orderedKeys.remove(at: index)
         }
      }
   }

   public subscript(_ index: Int) -> KeyValuePair? {
      keyValuePair(forIndex: index)
   }

   public subscript(unsafeIndex: Int) -> KeyValuePair {
      get {
         keyValuePair(forIndex: unsafeIndex)!
      }
      set {
         self.keyValuePairs[newValue.key] = newValue.value
         self.orderedKeys[unsafeIndex] = newValue.key
      }
   }

   public func index(after i: Int) -> Int { orderedKeys.index(after: i) }

   public mutating func transform(_ change: (inout KeyValuePair) -> Void) {
      for (key, value) in self.keyValuePairs {
         var copy = (key: key, value: value)
         change(&copy)
         self[copy.key] = copy.value
      }
   }

   public func transformed(
      _ change: (inout KeyValuePair) -> Void
   ) -> OrderedDictionary<Key, Value> {
      var copy = self
      copy.transform(change)
      return copy
   }
}

extension OrderedDictionary: RandomAccessCollection {}
extension OrderedDictionary: RangeReplaceableCollection {}


// MARK: - Codable

extension OrderedDictionary: Encodable where Key: Encodable, Value: Encodable {
   /// __inheritdoc__
   public func encode(to encoder: Encoder) throws {
      var container = encoder.unkeyedContainer()

      try self.forEach { key, value in
         try container.encode(key)
         try container.encode(value)
      }
   }
}

extension OrderedDictionary: Decodable where Key: Decodable, Value: Decodable {
   /// __inheritdoc__
   public init(from decoder: Decoder) throws {
      self.init()

      var container = try decoder.unkeyedContainer()

      while !container.isAtEnd {
         let key = try container.decode(Key.self)
         guard !container.isAtEnd else {
            throw DecodingError.dataCorruptedError(
               in: container,
               debugDescription: "Unkeyed container reached end before value in key-value pair")
         }
         let value = try container.decode(Value.self)

         self[key] = value
      }
   }
}


// MARK: - Description

extension OrderedDictionary: CustomStringConvertible, CustomDebugStringConvertible {
   public var description: String {
      guard !isEmpty else { return "[:]" }
      let keyValueStrings = self.reduce(into: [String]()) { result, pair in
         result.append("\(pair.key): \(pair.value)")
      }
      return keyValueStrings.joined(separator: ",\n")
   }

   public var debugDescription: String { description }
}


// MARK: - Other

extension OrderedDictionary: Equatable where Value: Equatable {}
extension OrderedDictionary: Hashable where Value: Hashable {}
