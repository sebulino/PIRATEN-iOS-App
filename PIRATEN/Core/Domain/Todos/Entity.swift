//
//  Entity.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import Foundation

/// Domain model representing an organizational entity (e.g. Kreisverband, Landesverband).
/// Matches the entities table in the meine-piraten.de Rails server.
struct Entity: Identifiable, Equatable {
    let id: Int
    let name: String
    let isLV: Bool
    let isOV: Bool
    let isKV: Bool
    let parentEntityId: Int?
}
