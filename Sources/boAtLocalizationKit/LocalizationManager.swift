//
//  LocalizationManager.swift
//  boAtLocalizationKit
//
//  Created by Neosoft on 12/06/26.
//

import Foundation
import Combine

/// Central singleton that manages the app's current language,
/// persists the selection, and resolves localized strings with fallback.
@MainActor
public final class LocalizationManager: ObservableObject {

    // MARK: - Singleton
    public static let shared = LocalizationManager()

    // MARK: - Persistence
    private let defaults: UserDefaults
    private static let storageKey = "LocalizationKit.selectedLanguage"

    // MARK: - State
    /// The currently active language. Publishing changes lets SwiftUI re-render.
    @Published public private(set) var currentLanguage: Language

    /// Cached bundles per language so we don't reload from disk repeatedly.
    private var bundleCache: [Language: Bundle] = [:]

    // MARK: - Init
    /// `internal` init exposed for testing with a custom UserDefaults suite.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Restore persisted language, else fall back to device/preferred, else English.
        if let raw = defaults.string(forKey: Self.storageKey),
           let saved = Language(rawValue: raw) {
            self.currentLanguage = saved
        } else if let preferred = Self.devicePreferredLanguage() {
            self.currentLanguage = preferred
        } else {
            self.currentLanguage = .fallback
        }
    }

    // MARK: - Public API

    /// Switch the active language at runtime and persist the choice.
    public func setLanguage(_ language: Language) {
        guard language != currentLanguage else { return }
        currentLanguage = language
        defaults.set(language.rawValue, forKey: Self.storageKey)
    }

    /// Resolve a localized string for a type-safe key.
    public func localized(_ key: LocalizedKey) -> String {
        localized(key.rawValue)
    }

    /// Resolve a localized string for a raw key, with English fallback.
    public func localized(_ key: String) -> String {
        let value = string(for: key, in: currentLanguage)

        // If the value equals the key, the translation was missing —
        // fall back to English before giving up.
        if value == key && currentLanguage != .fallback {
            let fallbackValue = string(for: key, in: .fallback)
            return fallbackValue
        }
        return value
    }

    // MARK: - Private Helpers

    /// Look up a string in a specific language's bundle.
    private func string(for key: String, in language: Language) -> String {
        guard let bundle = bundle(for: language) else { return key }
        // Use the key itself as the "not found" sentinel.
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Resolve and cache the `.lproj` bundle for a given language.
    private func bundle(for language: Language) -> Bundle? {
        if let cached = bundleCache[language] { return cached }

        guard
            let path = Bundle.module.path(forResource: language.rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return nil
        }
        bundleCache[language] = bundle
        return bundle
    }

    /// Match the device's preferred language to a supported `Language`.
    private static func devicePreferredLanguage() -> Language? {
        for identifier in Locale.preferredLanguages {
            let code = String(identifier.prefix(2))
            if let match = Language(rawValue: code) {
                return match
            }
        }
        return nil
    }
}
