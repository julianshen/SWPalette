//
//  PriorityQueue.swift
//  SWPalette
//
//  Copyright (c) 2015 cowbay.wtf. All rights reserved.
//

import Foundation

struct PriorityQueue<T:Comparable> {
    var data: [T] = [T]()
    private var compare: (T, T) -> Bool
    
    var size:Int {
        return data.count
    }
    
    init(_ compare: (T, T) -> Bool) {
        self.compare = compare
    }
    
    init(_ newData:[T], _ compare: (T, T) -> Bool) {
        self.compare = compare
        offerAll(newData)
    }
    
    mutating func offer(elem: T) {
        data.append(elem)
        siftUp(data.count - 1)
    }
    
    mutating func offerAll(elems: [T]) {
        for elem in elems {
            offer(elem)
        }

    }
    
    mutating func poll() -> T? {
        if data.count == 0 {
            return nil
        }
        
        let result = data[0]
        removeAt(0)
        return result
    }
    
    mutating private func removeAt(index:Int) {
        let moved = data.last
        data[index] = moved!
        siftDown(index)
        
        if moved == data[index] {
            siftUp(index)
        }
        data.removeLast()
    }
    
    mutating private func siftUp(var childIndex:Int) {
        let target = data[childIndex]
        var parentIndex: Int
        
        while childIndex > 0 {
            parentIndex = (childIndex - 1) / 2
            let parent = data[parentIndex]
            
            if compare(parent, target) {
                break
            }
            
            data[childIndex] = parent
            childIndex = parentIndex
        }
        data[childIndex] = target
    }
    
    mutating private func siftDown(var rootIndex:Int) {
        let target = data[rootIndex]
        
        var childIndex = rootIndex * 2 + 1
        while childIndex < data.count {
            if childIndex + 1 < data.count && compare(data[childIndex + 1], data[childIndex]) {
                childIndex++
            }
            if compare(target, data[childIndex]) {
                break
            }
            
            data[rootIndex] = data[childIndex]
            rootIndex = childIndex
            childIndex = rootIndex * 2 + 1
        }
        data[rootIndex] = target
    }
}
