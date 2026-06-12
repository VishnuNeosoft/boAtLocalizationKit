//
//  String+Localization.swift
//  boAtLocalizationKit
//
//  Created by Neosoft on 12/06/26.
//

import Foundation

public extension String {
    /// Convenience: `"welcome".localized` → resolved string.
    @MainActor
    var localized: String {
        LocalizationManager.shared.localized(self)
    }
}

public extension LocalizedKey {
    /// Convenience: `LocalizedKey.hello.localized`.
    @MainActor
    var localized: String {
        LocalizationManager.shared.localized(self)
    }
}
