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
    
    // O3 최적화: 캐시된 결과 배열 재사용
    private var cachedResult = [T]()

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

    /// 버퍼의 모든 아이템을 순서대로 반환 (O3 최적화: 캐시된 배열 재사용)
    mutating func allItems() -> [T] {
        cachedResult.removeAll(keepingCapacity: true)  // 용량 유지하며 클리어
        cachedResult.reserveCapacity(count)
        
        for index in 0..<count {
            let bufferIndex = (head + index) % capacity
            if let element = array[bufferIndex] {
                cachedResult.append(element)
            }
        }
        return cachedResult
    }

    /// 버퍼를 비움 (O3 최적화: 기존 배열 재사용)
    mutating func clear() {
        for i in 0..<capacity {
            array[i] = nil
        }
        head = 0
        count = 0
    }
}
