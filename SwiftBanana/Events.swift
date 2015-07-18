//
//  Events.swift
//  ScotTraffic
//
//  Created by Neil Gall on 18/07/2015.
//  Copyright © 2015 Neil Gall. All rights reserved.
//

import Foundation

public protocol Event {
    typealias Time : Comparable
    typealias Value

    var occurrences: [(Time,Value)] { get }
}

public class Never<T, V where T: Comparable>: Event {
    typealias Time = T
    typealias Value = V
    
    public let occurrences: [(Time,Value)] = []
}

public class Source<T, V where T: Comparable>: Event {
    typealias Time = T
    typealias Value = V
    
    public var occurrences: [(T,V)] = []
    
    public func add(value: V, atTime time: T) {
        let index = occurrences.indexOf { $0.0 > time } ?? 0
        occurrences.insert((time, value), atIndex: index)
    }
    
    public func pruneTo(time: Time) {
        occurrences = occurrences.filter { $0.0 >= time }
    }
}

public class RealTimeSource<V>: Source<Int, V> {
    func now() -> Int {
        return Int(CFAbsoluteTimeGetCurrent() * 1e6)
    }
    
    public func add(value: V) {
        occurrences.append((now(), value))
    }
}

class MappedEvent<Source, V where Source: Event>: Event {
    typealias Time = Source.Time
    typealias Value = V
    
    let source: Source
    let transform: (Source.Time, Source.Value) -> (Source.Time, V)
    
    init(source: Source, transform: Source.Value -> V) {
        self.source = source
        self.transform = { ($0.0, transform($0.1)) }
    }

    var occurrences: [(Source.Time,V)] {
        get {
            return source.occurrences.map(transform)
        }
    }
}

class FilteredEvent<Source where Source: Event>: Event {
    typealias Time = Source.Time
    typealias Value = Source.Value
    
    let source: Source
    let filter: (Source.Time, Source.Value) -> (Source.Time, Source.Value)?
    
    init(source: Source, predicate: Source.Value -> Bool) {
        self.source = source
        self.filter = { predicate($0.1) ? $0 : nil }
    }
    
    var occurrences: [(Source.Time, Source.Value)] {
        get {
            return source.occurrences.flatMap(filter)
        }
    }
}

class UnionEvents<Source where Source: Event>: Event {
    typealias Time = Source.Time
    typealias Value = Source.Value
    
    let sources: [Source]

    init(sources: [Source]) {
        self.sources = sources
    }

    var occurrences: [(Source.Time, Source.Value)] {
        get {
            let union : [(Source.Time, Source.Value)] = sources.flatMap { $0.occurrences }
            return union.sort { $0.0 < $1.0 }
        }
    }
}

class CollectEvents<Source where Source: Event, Source.Time: Hashable>: Event {
    typealias Time = Source.Time
    typealias Value = [Source.Value]
    
    let sources: [Source]

    init(sources: [Source]) {
        self.sources = sources
    }
    
    var occurrences: [(Source.Time, [Source.Value])] {
        get {
            var collected = Dictionary<Source.Time, [Source.Value]>()
            for source in sources {
                for occurrence in source.occurrences {
                    var values = collected[occurrence.0] ?? []
                    values.append(occurrence.1)
                    collected[occurrence.0] = values
                }
            }
            
            let times = collected.keys.sort()
            return times.map { ($0, collected[$0]!) }
        }
    }
}

protocol TimeVaryingFunction {
    typealias Src
    typealias Dst
    var transform: Src -> Dst { get }
}

class AppliedEvent<E,B where E: Event,
                             B: Behaviour,
                             B.Time == E.Time,
                             B.Value: TimeVaryingFunction,
                             B.Value.Src == E.Value>: Event {
    typealias Time = E.Time
    typealias Value = B.Value.Dst
    
    let source: E
    let behaviour: B
    
    init(source: E, behaviour: B) {
        self.source = source
        self.behaviour = behaviour
    }
    
    var occurrences: [(E.Time, B.Value.Dst)] {
        get {
            return source.occurrences.map { (time, value) in (time, self.behaviour.at(time).transform(value)) }
        }
    }
}

extension Event {
    func map<Value>(transform: Self.Value -> Value) -> MappedEvent<Self, Value> {
        return MappedEvent(source: self, transform: transform)
    }
    
    func filter(predicate: Self.Value -> Bool) -> FilteredEvent<Self> {
        return FilteredEvent(source: self, predicate: predicate)
    }
    
    func union(source: Self) -> UnionEvents<Self> {
        return UnionEvents(sources: [self, source])
    }

    func apply<B where B.Value: TimeVaryingFunction, B.Value.Src == Value>(behaviour: B) -> AppliedEvent<Self, B> {
        return AppliedEvent(source: self, behaviour: behaviour)
    }

    static func union(sources: [Self]) -> UnionEvents<Self> {
        return UnionEvents(sources: sources)
    }
}

extension Event where Time: Hashable {
    static func collect(sources: [Self]) -> CollectEvents<Self> {
        return CollectEvents(sources: sources)
    }
}