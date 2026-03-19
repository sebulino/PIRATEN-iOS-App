//
//  Entity.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import Foundation

/// The organizational level of an entity within the party hierarchy.
enum EntityLevel: String, CaseIterable, Equatable {
    case lv = "LV"
    case bzv = "BZV"
    case kv = "KV"

    /// German display name
    var displayName: String {
        switch self {
        case .lv: return "Landesverband"
        case .bzv: return "Bezirksverband"
        case .kv: return "Kreisverband"
        }
    }
}

/// Domain model representing an organizational entity (e.g. Kreisverband, Landesverband).
/// Matches the entities table in the meine-piraten.de Rails server.
struct Entity: Identifiable, Equatable {
    let id: Int
    let name: String
    let entityLevel: EntityLevel
    let parentEntityId: Int?
}
