//
//  TaskService.swift
//  Alarm
//
//  Created by Oleksii on 17.04.2026.
//

import Foundation

struct AlarmTask: Identifiable, Sendable {
    let id = UUID()
    let instruction: String
    /// ImageNet label substrings to match (lowercased, partial match)
    let keywords: [String]
}

final class TaskService {
    static let shared = TaskService()

    let tasks: [AlarmTask] = [
        .init(instruction: "Photograph a laptop",          keywords: ["laptop"]),
        .init(instruction: "Photograph a keyboard",        keywords: ["computer keyboard", "keypad"]),
        .init(instruction: "Photograph a computer mouse",  keywords: ["computer mouse"]),
        .init(instruction: "Photograph a TV or monitor",   keywords: ["television", "monitor", "screen, crt"]),
        .init(instruction: "Photograph a water bottle",    keywords: ["water bottle"]),
        .init(instruction: "Photograph a coffee mug",      keywords: ["coffee mug"]),
        .init(instruction: "Photograph a backpack",        keywords: ["backpack"]),
        .init(instruction: "Photograph an umbrella",       keywords: ["umbrella"]),
        .init(instruction: "Photograph a vase",            keywords: ["vase"]),
        .init(instruction: "Photograph a mobile phone",    keywords: ["cellular telephone", "mobile phone"]),
        .init(instruction: "Photograph a pillow",          keywords: ["pillow"]),
//        .init(instruction: "Photograph a clock",           keywords: ["analog clock", "wall clock", "digital clock", "stopwatch"]),
//        .init(instruction: "Photograph a refrigerator",    keywords: ["refrigerator"]),
        .init(instruction: "Photograph a remote control",  keywords: ["remote control"]),
        .init(instruction: "Photograph a toaster",         keywords: ["toaster"]),
    ]

    private var currentIndex: Int = 0

    var current: AlarmTask { tasks[currentIndex] }

    /// Advances to a random task different from the current one.
    func randomNext() {
        guard tasks.count > 1 else { return }
        var next = currentIndex
        while next == currentIndex {
            next = Int.random(in: 0..<tasks.count)
        }
        currentIndex = next
    }

    private init() {}
}
