//
//  Secrets.swift
//  SPAJAM2026App
//
//  API キーの読み込み。Secrets.plist は gitignore 済み(Secrets.sample.plist をコピーして作成)。
//

import Foundation

enum Secrets {
    private static let dictionary: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else { return [:] }
        return plist
    }()

    static var googleAIStudioAPIKey: String? {
        value(for: "GoogleAIStudioAPIKey")
    }

    static var googleCloudAPIKey: String? {
        value(for: "GoogleCloudAPIKey")
    }

    static var openAIAPIKey: String? {
        value(for: "OpenAIAPIKey")
    }

    private static func value(for key: String) -> String? {
        guard let v = dictionary[key], !v.isEmpty, v != "PASTE_HERE" else { return nil }
        return v
    }
}
