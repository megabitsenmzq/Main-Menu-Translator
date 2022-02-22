//
//  xclocReader.swift
//  Main Menu Translator
//
//  Created by Jinyu Meng on 2022/02/20.
//

import Foundation
import AEXML
import AppKit

struct XliffFile {
    var path: String
    var lang: String
}

class XclocReader: NSObject {
    
    func allLanguagesFrom(path: String) -> [XliffFile]? {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: path) else { return nil }
        let xclocFiles = files.filter({ $0.hasSuffix("xcloc") && $0.contains(".") })
        if xclocFiles.isEmpty { return nil }
        return xclocFiles.map({ file in
            let lang = file.components(separatedBy: ".")[0]
            return XliffFile(
                path: "\(path)/\(file)/Localized Contents/\(lang).xliff" ,
                lang: lang
            )
        })
    }
    
    func allMenuKeysFrom(xliffPath: String) -> (keys: [XibKey], appName: String)? {
        let url = URL(fileURLWithPath: xliffPath)
        guard let xmlData = try? Data(contentsOf: url) else { return nil }
        var appName = "AppName"
        
        do {
            var options = AEXMLOptions()
            options.parserSettings.shouldTrimWhitespace = false
            let xml = try AEXMLDocument(xml: xmlData, options: options)
            guard let files = xml.root["file"].all else { return nil }
            
            if let menuFile = files.filter({ item in
                let original = item.attributes["original"]
                return original?.components(separatedBy: "/").last == "MainMenu.xib"
            }).first {
                guard let units = menuFile["body"]["trans-unit"].all else { return nil }
                let keys = units.compactMap({ unit -> XibKey? in
                    guard var key = unit.attributes["id"] else { return nil }
                    let source = unit["source"].string
                    
                    if unit["note"].string.hasPrefix("Class = \"NSWindow\";") { // Mark the app name.
                        appName = source
                    }
                    
                    // Some titles have a tab ahead. So add a mark in keys.
                    if source.hasPrefix("\t") { key = "$t" + key }
                    return XibKey(key: key, source: source.hasPrefix("\t") ? String(source.dropFirst(1)) : source)
                })
                if keys.isEmpty { return nil }
                return (keys: keys, appName: appName)
            }
        } catch {
            print("\(error)")
        }
        return nil
    }

    func translate(xliffPath: String, with dictionary: [DictionaryEntry], appName: String) -> Bool {
        let url = URL(fileURLWithPath: xliffPath)
        guard let xmlData = try? Data(contentsOf: url) else { return false }
        
        do {
            var options = AEXMLOptions()
            options.parserSettings.shouldTrimWhitespace = false
            let xml = try AEXMLDocument(xml: xmlData, options: options)
            guard let files = xml.root["file"].all else { return false }
            
            if let menuFile = files.filter({ item in
                let original = item.attributes["original"]
                return original?.components(separatedBy: "/").last == "MainMenu.xib"
            }).first {
                guard let units = menuFile["body"]["trans-unit"].all else { return false }
                for unit in units {
                    guard let key = unit.attributes["id"] else { continue }
                    // Match keys.
                    if let targetText = dictionary.first(where: {$0.keys.contains(key)}) {
                        unit["target"].removeFromParent()
                        unit.addChild(name: "target", value: String(format:targetText.target, appName))
                    }
                    // Match keys include tab.
                    if let targetText = dictionary.first(where: {$0.keys.contains("$t" + key)}) {
                        unit["target"].removeFromParent()
                        unit.addChild(name: "target", value: "\t" + targetText.target)
                    }
                }
            }
            
            try xml.xml.write(toFile: xliffPath, atomically: true, encoding: .utf8)
        } catch {
            print("\(error)")
            return false
        }
        
        return true
    }
}
