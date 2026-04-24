//
//  TaskService.swift
//  Alarm
//
//  Created by Oleksii on 17.04.2026.
//

import Foundation

/// A single Photo-mission object. The model carries everything needed to:
///   - show the object in the picker (emoji + name + category),
///   - instruct the user at alarm time (name → "Photograph a {name}"),
///   - verify the photo server-side (instruction is the human phrase we
///     forward to the vision model in `NetworkingService`).
struct AlarmTask: Identifiable, Sendable, Hashable {
    /// Stable slug used for persistence (e.g. `"laptop"`, `"coffee-mug"`).
    let id: String
    /// User-facing short label shown in the picker tile.
    let name: String
    /// Visual glyph for the picker.
    let emoji: String
    /// Category bucket for the picker tabs.
    let category: PhotoTaskCategory

    /// Phrase sent to the user + backend at alarm time.
    var instruction: String { "Photograph a \(name.lowercased())" }
}

enum PhotoTaskCategory: String, CaseIterable, Sendable {
    case livingRoom = "Living room"
    case bedroom    = "My room"
    case kitchen    = "Kitchen"
    case bathroom   = "Bathroom"
    case plants     = "Plants"
    case myStuff    = "My stuff"
    case entrance   = "Entrance"
    case outdoors   = "Outdoors"
    case people     = "People"
    case animals    = "Animals"
}

// MARK: - Catalog

/// Master catalog of all photo-mission objects. This is the source of truth —
/// `TaskService` draws runtime tasks from here filtered by the user's per-alarm
/// selection.
enum TaskCatalog {
    static let all: [AlarmTask] = [
        // MARK: Bathroom
        .init(id: "sink",               name: "Sink",               emoji: "🚰", category: .bathroom),
        .init(id: "toilet",             name: "Toilet",             emoji: "🚽", category: .bathroom),
        .init(id: "tiles",              name: "Tiles",              emoji: "🧱", category: .bathroom),
        .init(id: "mirror",             name: "Mirror",             emoji: "🪞", category: .bathroom),
        .init(id: "towel",              name: "Towel",              emoji: "🧴", category: .bathroom),

        // MARK: Living room
        .init(id: "couch",              name: "Couch",              emoji: "🛋️", category: .livingRoom),
        .init(id: "cushion",            name: "Cushion",            emoji: "🟨", category: .livingRoom),
        .init(id: "wall",               name: "Wall",               emoji: "🧱", category: .livingRoom),
        .init(id: "clock",              name: "Clock",              emoji: "⏰", category: .livingRoom),
        .init(id: "piano",              name: "Piano",              emoji: "🎹", category: .livingRoom),
        .init(id: "musical-instrument", name: "Musical instrument", emoji: "🎸", category: .livingRoom),
        .init(id: "fire",               name: "Fire",               emoji: "🔥", category: .livingRoom),
        .init(id: "tv",                 name: "TV",                 emoji: "📺", category: .livingRoom),
        .init(id: "lamp",               name: "Lamp",               emoji: "💡", category: .livingRoom),

        // MARK: My room (bedroom / personal space)
        .init(id: "drawer",             name: "Drawer",             emoji: "🗄️", category: .bedroom),
        .init(id: "curtain",            name: "Curtain",            emoji: "🪟", category: .bedroom),
        .init(id: "desk",               name: "Desk",               emoji: "🪑", category: .bedroom),
        .init(id: "pillow",             name: "Pillow",             emoji: "🛏️", category: .bedroom),
        .init(id: "chair",              name: "Chair",              emoji: "🪑", category: .bedroom),
        .init(id: "book",               name: "Book",               emoji: "📖", category: .bedroom),
        .init(id: "stuffed-toy",        name: "Stuffed toy",        emoji: "🧸", category: .bedroom),
        .init(id: "cabinetry",          name: "Cabinetry",          emoji: "🗄️", category: .bedroom),
        .init(id: "bedroom",            name: "Bedroom",            emoji: "🛏️", category: .bedroom),
        .init(id: "shelf",              name: "Shelf",              emoji: "📚", category: .bedroom),
        .init(id: "jeans",              name: "Jeans",              emoji: "👖", category: .bedroom),
        .init(id: "denim",              name: "Denim",              emoji: "🟦", category: .bedroom),
        .init(id: "laptop",             name: "Laptop",             emoji: "💻", category: .bedroom),
        .init(id: "keyboard",           name: "Keyboard",           emoji: "⌨️", category: .bedroom),

        // MARK: Kitchen / Food
        .init(id: "cup",                name: "Cup",                emoji: "☕️", category: .kitchen),
        .init(id: "kitchen",            name: "Kitchen",            emoji: "🍳", category: .kitchen),
        .init(id: "cutlery",            name: "Cutlery",            emoji: "🍴", category: .kitchen),
        .init(id: "countertop",         name: "Countertop",         emoji: "🪵", category: .kitchen),
        .init(id: "food",               name: "Food",               emoji: "🍲", category: .kitchen),
        .init(id: "bread",              name: "Bread",              emoji: "🍞", category: .kitchen),
        .init(id: "vegetable",          name: "Vegetable",          emoji: "🥦", category: .kitchen),
        .init(id: "juice",              name: "Juice",              emoji: "🧃", category: .kitchen),
        .init(id: "soda",               name: "Soda",               emoji: "🥤", category: .kitchen),
        .init(id: "coffee",             name: "Coffee",             emoji: "☕️", category: .kitchen),
        .init(id: "meal",               name: "Meal",               emoji: "🍽️", category: .kitchen),
        .init(id: "fridge",             name: "Fridge",             emoji: "🧊", category: .kitchen),
        .init(id: "toaster",            name: "Toaster",            emoji: "🍞", category: .kitchen),

        // MARK: Plants
        .init(id: "flowerpot",          name: "Flowerpot",          emoji: "🪴", category: .plants),
        .init(id: "plant",              name: "Plant",              emoji: "🌱", category: .plants),
        .init(id: "flower",             name: "Flower",             emoji: "🌷", category: .plants),
        .init(id: "tree",               name: "Tree",               emoji: "🌳", category: .plants),

        // MARK: My stuff
        .init(id: "glasses",            name: "Glasses",            emoji: "👓", category: .myStuff),
        .init(id: "bag",                name: "Bag",                emoji: "🎒", category: .myStuff),
        .init(id: "hat",                name: "Hat",                emoji: "🧢", category: .myStuff),
        .init(id: "lipstick",           name: "Lipstick",           emoji: "💄", category: .myStuff),
        .init(id: "phone",              name: "Phone",              emoji: "📱", category: .myStuff),
        .init(id: "handbag",            name: "Handbag",            emoji: "👜", category: .myStuff),
        .init(id: "sunglasses",         name: "Sunglasses",         emoji: "🕶️", category: .myStuff),
        .init(id: "watch",              name: "Watch",              emoji: "⌚️", category: .myStuff),
        .init(id: "wallet",             name: "Wallet",             emoji: "👛", category: .myStuff),
        .init(id: "headphones",         name: "Headphones",         emoji: "🎧", category: .myStuff),

        // MARK: Entrance
        .init(id: "shoe",               name: "Shoe",               emoji: "👟", category: .entrance),
        .init(id: "stairs",             name: "Stairs",             emoji: "🪜", category: .entrance),
        .init(id: "umbrella",           name: "Umbrella",           emoji: "☂️", category: .entrance),
        .init(id: "bicycle",            name: "Bicycle",            emoji: "🚲", category: .entrance),
        .init(id: "door",               name: "Door",               emoji: "🚪", category: .entrance),
        .init(id: "keys",               name: "Keys",               emoji: "🔑", category: .entrance),

        // MARK: Outdoors
        .init(id: "sky",                name: "Sky",                emoji: "☁️", category: .outdoors),
        .init(id: "car",                name: "Car",                emoji: "🚗", category: .outdoors),
        .init(id: "bus",                name: "Bus",                emoji: "🚌", category: .outdoors),
        .init(id: "building",           name: "Building",           emoji: "🏢", category: .outdoors),
        .init(id: "grass",              name: "Grass",              emoji: "🌿", category: .outdoors),

        // MARK: People
        .init(id: "eye",                name: "Eye",                emoji: "👁️", category: .people),
        .init(id: "nail",               name: "Nail",               emoji: "💅", category: .people),
        .init(id: "smile",              name: "Smile",              emoji: "😀", category: .people),
        .init(id: "hair",               name: "Hair",               emoji: "💇", category: .people),
        .init(id: "ear",                name: "Ear",                emoji: "👂", category: .people),
        .init(id: "mouth",              name: "Mouth",              emoji: "👄", category: .people),
        .init(id: "toes",               name: "Toes",               emoji: "🦶", category: .people),
        .init(id: "feet",               name: "Feet",               emoji: "🦶", category: .people),
        .init(id: "hand",               name: "Hand",               emoji: "✋", category: .people),
        .init(id: "standing-person",    name: "Standing person",    emoji: "🧍", category: .people),
        .init(id: "dance",              name: "Dance",              emoji: "💃", category: .people),
        .init(id: "muscle",             name: "Muscle",             emoji: "💪", category: .people),
        .init(id: "bangs",              name: "Bangs",              emoji: "💇‍♀️", category: .people),
        .init(id: "tattoo",             name: "Tattoo",             emoji: "🖐️", category: .people),
        .init(id: "beard",              name: "Beard",              emoji: "🧔", category: .people),
        .init(id: "baby",               name: "Baby",               emoji: "👶", category: .people),

        // MARK: Animals
        .init(id: "dog",                name: "Dog",                emoji: "🐶", category: .animals),
        .init(id: "cat",                name: "Cat",                emoji: "🐱", category: .animals),
        .init(id: "pet",                name: "Pet",                emoji: "🐾", category: .animals),
        .init(id: "bird",               name: "Bird",               emoji: "🐦", category: .animals),
        .init(id: "fish",               name: "Fish",               emoji: "🐟", category: .animals),
    ]

    /// Preserve insertion order per category.
    static var byCategory: [(category: PhotoTaskCategory, tasks: [AlarmTask])] {
        PhotoTaskCategory.allCases.map { cat in
            (cat, all.filter { $0.category == cat })
        }
    }

    static func task(id: String) -> AlarmTask? {
        all.first { $0.id == id }
    }

    static func tasks(ids: [String]?) -> [AlarmTask] {
        guard let ids, !ids.isEmpty else { return all }
        let set = Set(ids)
        return all.filter { set.contains($0.id) }
    }

    static var totalCount: Int { all.count }

    /// Default starter pack: 10 objects present in virtually any household
    /// anywhere in the world. Used as the initial selection the first time a
    /// user adds the Photo mission to an alarm.
    static let defaultIDs: [String] = [
        "couch",
        "wall",
        "pillow",
        "sink",
        "cup",
        "food",
        "mirror",
        "door",
        "chair",
        "shoe",
    ]
}

// MARK: - Runtime rotation

/// Session-scoped rotation over a (filtered) slice of the catalog. Used by
/// `CameraView` to hand the user a task at alarm time.
final class TaskService {
    static let shared = TaskService()
    private init() {}

    /// Currently active pool (filtered by per-alarm selection). Defaults to
    /// the full catalog.
    private(set) var pool: [AlarmTask] = TaskCatalog.all
    private var currentIndex: Int = 0

    var current: AlarmTask { pool[safe: currentIndex] ?? pool.first ?? TaskCatalog.all[0] }

    /// Scope the runtime rotation to `ids`. Pass `nil` for "all".
    func setAllowed(ids: [String]?) {
        let next = TaskCatalog.tasks(ids: ids)
        pool = next.isEmpty ? TaskCatalog.all : next
        currentIndex = 0
    }

    /// Advances to a random task different from the current one (when possible).
    func randomNext() {
        guard pool.count > 1 else { return }
        var next = currentIndex
        while next == currentIndex {
            next = Int.random(in: 0..<pool.count)
        }
        currentIndex = next
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
