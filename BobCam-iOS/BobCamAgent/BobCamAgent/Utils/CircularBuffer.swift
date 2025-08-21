//
//  CircularBuffer.swift
//  BobCam
//
//  Created by Gemini-CLI on 2025/07/17.
//

import Foundation

/// 고정된 크기를 가지는 순환 버퍼 (제네릭 자료구조)
struct CircularBuffer<T> {
    private var array: [T?]
    private var head = 0
    private(set) var count = 0

    init(capacity: Int) {
        array = [T?](repeating: nil, count: capacity)
    }

    /// 버퍼의 용량
    var capacity: Int {
        array.count
    }

    /// 버퍼가 비어있는지 여부
    var isEmpty: Bool {
        count == 0
    }

    /// 버퍼가 가득 찼는지 여부
    var isFull: Bool {
        count == capacity
    }
    
    /// 가장 마지막에 추가된 아이템
    var lastItem: T? {
        guard !isEmpty else { return nil }
        let lastIndex = (head + count - 1) % capacity
        return array[lastIndex]
    }

    /// 새로운 아이템을 버퍼에 추가 (가장 오래된 아이템을 덮어씀)
    mutating func write(_ element: T) {
        if isFull {
            array[head] = element
            head = (head + 1) % capacity
        } else {
            let newIndex = (head + count) % capacity
            array[newIndex] = element
            count += 1
        }
    }

    /// 버퍼의 모든 아이템을 순서대로 반환
    func allItems() -> [T] {
        var result = [T]()
        result.reserveCapacity(count)
        for index in 0..<count {
            let bufferIndex = (head + index) % capacity
            if let element = array[bufferIndex] {
                result.append(element)
            }
        }
        return result
    }
    
    /// 버퍼를 비움
    mutating func clear() {
        array = [T?](repeating: nil, count: capacity)
        head = 0
        count = 0
    }
}
