//
//  Language.swift
//  boAtLocalizationKit
//
//  Created by Neosoft on 12/06/26.
//

import Foundation

/// Supported languages in the framework.
/// Add a new case here + matching `.lproj` folder to extend support.
public enum Language: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case spanish = "es"
    case french  = "fr"

    public var id: String { rawValue }

    /// Human-readable name shown in the language's own language.
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french:  return "Français"
        }
    }

    /// The fallback language used when a translation is missing.
    public static let fallback: Language = .english
}
