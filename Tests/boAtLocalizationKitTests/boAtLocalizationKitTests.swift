import XCTest
@testable import boAtLocalizationKit

@MainActor
final class LocalizationManagerTests: XCTestCase {

    private func makeSUT() -> LocalizationManager {
        let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        return LocalizationManager(defaults: suite)
    }

    func test_defaultLanguageResolves() {
        let sut = makeSUT()
        sut.setLanguage(.english)
        XCTAssertEqual(sut.localized(.hello), "Hello")
    }

    func test_spanishTranslation() {
        let sut = makeSUT()
        sut.setLanguage(.spanish)
        XCTAssertEqual(sut.localized(.hello), "Hola")
        XCTAssertEqual(sut.localized(.changeLanguage), "Cambiar idioma")
    }

    func test_frenchTranslation() {
        let sut = makeSUT()
        sut.setLanguage(.french)
        XCTAssertEqual(sut.localized(.welcome2), "Bienvenue")
    }

    func test_fallbackToEnglishForMissingKey() {
        let sut = makeSUT()
        sut.setLanguage(.french)
        // A key that doesn't exist returns the key, not a crash.
        XCTAssertEqual(sut.localized("nonexistent_key"), "nonexistent_key")
    }

    func test_persistenceAcrossInstances() {
        let suite = UserDefaults(suiteName: "test.persist")!
        suite.removePersistentDomain(forName: "test.persist")

        let first = LocalizationManager(defaults: suite)
        first.setLanguage(.french)

        let second = LocalizationManager(defaults: suite)
        XCTAssertEqual(second.currentLanguage, .french)
    }

    func test_localizableStringsFilesAreInSyncAndMatchLocalizedKey() throws {
        let stringsFileURLs = getLocalizableStringsFileURLs()
        XCTAssertFalse(stringsFileURLs.isEmpty, "No Localizable.strings files found.")

        let enumKeys = Set(LocalizedKey.allCases.map { $0.rawValue })
        var mismatchFound = false
        var mismatchDetails = ""

        for fileURL in stringsFileURLs {
            let data = try Data(contentsOf: fileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: String] else {
                XCTFail("Failed to parse \(fileURL.lastPathComponent) as a [String: String] dictionary.")
                continue
            }
            
            let fileKeys = Set(dict.keys)
            let missingKeys = enumKeys.subtracting(fileKeys)
            let extraKeys = fileKeys.subtracting(enumKeys)
            
            let path = fileURL.path.replacingOccurrences(of: getResourcesDirectory().path + "/", with: "")
            if !missingKeys.isEmpty {
                mismatchFound = true
                mismatchDetails += "\n- \(path) is missing keys: \(missingKeys.sorted())"
            }
            if !extraKeys.isEmpty {
                mismatchFound = true
                mismatchDetails += "\n- \(path) has obsolete/extra keys: \(extraKeys.sorted())"
            }
        }

        XCTAssertFalse(mismatchFound, "Localizable.strings files are not in sync with LocalizedKey.\nRun: 'swift sync_localization.swift' to automatically synchronize them.\n\(mismatchDetails)")
    }

    // MARK: - Path Helpers

    private func getResourcesDirectory() -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent() // boAtLocalizationKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // package root
        return packageRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("boAtLocalizationKit")
            .appendingPathComponent("Resources")
    }

    private func getLocalizableStringsFileURLs() -> [URL] {
        let resourcesDir = getResourcesDirectory()
        guard let enumerator = FileManager.default.enumerator(at: resourcesDir, includingPropertiesForKeys: nil) else {
            return []
        }
        var urls: [URL] = []
        for case let url as URL in enumerator {
            if url.lastPathComponent == "Localizable.strings" {
                urls.append(url)
            }
        }
        return urls
    }
}

