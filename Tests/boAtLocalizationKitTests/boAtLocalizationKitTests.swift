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
        XCTAssertEqual(sut.localized(.welcome), "Bienvenue")
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
}
