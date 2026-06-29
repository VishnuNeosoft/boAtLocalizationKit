#!/usr/bin/swift
import Foundation

// Locate package root and paths
let scriptFile = URL(fileURLWithPath: #filePath)
let packageRoot = scriptFile.deletingLastPathComponent()
let localizedKeyURL = packageRoot
    .appendingPathComponent("Sources")
    .appendingPathComponent("boAtLocalizationKit")
    .appendingPathComponent("LocalizedKey.swift")
let resourcesDir = packageRoot
    .appendingPathComponent("Sources")
    .appendingPathComponent("boAtLocalizationKit")
    .appendingPathComponent("Resources")

// Helpers

func humanizeKey(_ key: String) -> String {
    var result = key.replacingOccurrences(of: "_", with: " ")
    let regex = try? NSRegularExpression(pattern: "([a-z])([A-Z])", options: [])
    result = regex?.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count), withTemplate: "$1 $2") ?? result
    return result.capitalized
}

func translate(text: String, from sourceLang: String, to targetLang: String) -> String? {
    // Map non-standard language codes
    let mappedTargetLang: String
    switch targetLang {
    case "gj": mappedTargetLang = "gu" // Gujarati
    default: mappedTargetLang = targetLang
    }
    
    var components = URLComponents(string: "https://api.mymemory.translated.net/get")
    components?.queryItems = [
        URLQueryItem(name: "q", value: text),
        URLQueryItem(name: "langpair", value: "\(sourceLang)|\(mappedTargetLang)")
    ]
    
    guard let url = components?.url else { return nil }
    
    var result: String?
    let semaphore = DispatchSemaphore(value: 0)
    
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        defer { semaphore.signal() }
        guard let data = data, error == nil else { return }
        
        struct ResponseDetails: Codable {
            let translatedText: String
        }
        struct ResponseData: Codable {
            let responseData: ResponseDetails
            let responseStatus: Int
        }
        
        if let decoded = try? JSONDecoder().decode(ResponseData.self, from: data) {
            if decoded.responseStatus == 200 {
                result = decoded.responseData.translatedText
            }
        }
    }
    task.resume()
    _ = semaphore.wait(timeout: .now() + 5.0)
    return result
}

// 1. Parse keys from LocalizedKey.swift
guard FileManager.default.fileExists(atPath: localizedKeyURL.path) else {
    print("Error: LocalizedKey.swift not found at \(localizedKeyURL.path)")
    exit(1)
}

let localizedKeyContent = try String(contentsOf: localizedKeyURL, encoding: .utf8)
let caseRegex = try NSRegularExpression(pattern: #"case\s+([a-zA-Z0-9_]+)(?:\s*=\s*"([^"]+)")?"#, options: [])
var targetKeys: [String] = []

localizedKeyContent.enumerateLines { line, _ in
    let nsLine = line as NSString
    let range = NSRange(location: 0, length: nsLine.length)
    if let match = caseRegex.firstMatch(in: line, options: [], range: range) {
        if match.numberOfRanges > 1 {
            let caseName = nsLine.substring(with: match.range(at: 1))
            var rawValue = caseName
            if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound {
                rawValue = nsLine.substring(with: match.range(at: 2))
            }
            targetKeys.append(rawValue)
        }
    }
}

print("Found \(targetKeys.count) keys in LocalizedKey.swift: \(targetKeys)")

// 2. Find all Localizable.strings files
guard let enumerator = FileManager.default.enumerator(at: resourcesDir, includingPropertiesForKeys: nil) else {
    print("Error: Resources directory not found at \(resourcesDir.path)")
    exit(1)
}

var stringsFileURLs: [URL] = []
for case let url as URL in enumerator {
    if url.lastPathComponent == "Localizable.strings" {
        stringsFileURLs.append(url)
    }
}

if stringsFileURLs.isEmpty {
    print("No Localizable.strings files found.")
    exit(0)
}

let stringKeyRegex = try NSRegularExpression(pattern: #"^\s*"((?:[^"\\]|\\.)+)"\s*=\s*"#, options: [])

// 3. Update each strings file
for fileURL in stringsFileURLs {
    let relativePath = fileURL.path.replacingOccurrences(of: resourcesDir.path + "/", with: "")
    let languageCode = fileURL.deletingLastPathComponent().lastPathComponent.replacingOccurrences(of: ".lproj", with: "")
    print("Syncing \(relativePath) (Language: \(languageCode))...")
    
    // Parse existing keys and values
    var existingDict: [String: String] = [:]
    var existingKeysInOrder: [String] = []
    
    if FileManager.default.fileExists(atPath: fileURL.path) {
        let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
        fileContent.enumerateLines { line, _ in
            let nsLine = line as NSString
            if let match = stringKeyRegex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsLine.length)) {
                let key = nsLine.substring(with: match.range(at: 1))
                existingKeysInOrder.append(key)
            }
        }
        
        let data = try Data(contentsOf: fileURL)
        if !data.isEmpty {
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            if let dict = plist as? [String: String] {
                existingDict = dict
            }
        }
    }
    
    // Detect renamed keys (if the count of added keys equals the count of deleted keys, map them)
    let deletedKeys = existingKeysInOrder.filter { !targetKeys.contains($0) }
    let addedKeys = targetKeys.filter { !existingDict.keys.contains($0) }
    
    var finalDict = existingDict
    if deletedKeys.count == addedKeys.count && !deletedKeys.isEmpty {
        for i in 0..<deletedKeys.count {
            let oldKey = deletedKeys[i]
            let newKey = addedKeys[i]
            if let oldValue = existingDict[oldKey] {
                print("  Detecting rename: '\(oldKey)' -> '\(newKey)' (preserving translation value)")
                finalDict[newKey] = oldValue
                finalDict.removeValue(forKey: oldKey)
            }
        }
    }
    
    // Build new strings content, translating any new keys
    var newContent = ""
    for key in targetKeys {
        var value = finalDict[key]
        
        if value == nil {
            // New key added! Humanize and translate it
            let humanizedEnglish = humanizeKey(key)
            if languageCode == "en" {
                value = humanizedEnglish
                print("  Added new key: '\(key)' -> '\(humanizedEnglish)'")
            } else {
                print("  Translating '\(humanizedEnglish)' to \(languageCode)...")
                if let translated = translate(text: humanizedEnglish, from: "en", to: languageCode) {
                    value = translated
                    print("    Result: '\(translated)'")
                } else {
                    value = humanizedEnglish // Fallback
                    print("    Warning: Translation failed. Using fallback: '\(humanizedEnglish)'")
                }
            }
        }
        
        if let actualValue = value {
            newContent += "\"\(key)\" = \"\(actualValue)\";\n"
        }
    }
    
    try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
}

print("Localization files synchronized successfully!")
