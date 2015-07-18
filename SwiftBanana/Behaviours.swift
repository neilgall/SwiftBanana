//
//  Behaviours.swift
//  ScotTraffic
//
//  Created by Neil Gall on 18/07/2015.
//  Copyright © 2015 Neil Gall. All rights reserved.
//

import Foundation

public protocol Behaviour {
    typealias Time: Comparable
    typealias Value
    
    func at(time: Time) -> Value
}

class Stepper<E where E: Event>: Behaviour {
    typealias Time = E.Time
    typealias Value = E.Value
    
    let event: E
    let initial: E.Value
    
    func at(time: E.Time) -> E.Value {
        if let index = event.occurrences.indexOf({ $0.0 > time }) where index > 0 {
            return event.occurrences[index-1].1
        } else {
            return initial
        }
    }
    
    init(event: E, initial: E.Value) {
        self.event = event
        self.initial = initial
    }
}

class Accumulator<E where E: Event>: Behaviour {
    typealias Time = E.Time
    typealias Value = E.Value
    
    let event: E
    let initial: E.Value
    let combine: (E.Value, E.Value) -> E.Value
    
    func at(time: E.Time) -> E.Value {
        let occurrences = event.occurrences.flatMap { $0.0 <= time ? $0.1 : nil }
        return occurrences.reduce(initial, combine: combine)
    }
    
    init(event: E, initial: E.Value, combine: (E.Value, E.Value) -> E.Value) {
        self.event = event
        self.initial = initial
        self.combine = combine
    }
}
