//
//  LocalizedKey.swift
//  boAtLocalizationKit
//
//  Created by Neosoft on 12/06/26.
//

import Foundation

/// Type-safe localization keys.
/// Using an enum instead of raw strings avoids typos and enables autocomplete.
public enum LocalizedKey: String, CaseIterable, Sendable {
    case hello
    case welcome
    case changeLanguage = "change_language"
    case howAreYou = "how_are_you"
    case logout
}
