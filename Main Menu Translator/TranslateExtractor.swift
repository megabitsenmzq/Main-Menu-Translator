//
//  TranslateExtractor.swift
//  Main Menu Translator
//
//  Created by Jinyu Meng on 2022/02/21.
//

import Foundation

struct DictionaryEntry: Hashable {
    var source: String
    var target: String
    var keys = [String]()
}

typealias DictionaryForLang = [String : [DictionaryEntry]]

class TranslateExtractor: NSObject {
    
    public class var shared : TranslateExtractor {
        struct Static {
            static let instance = TranslateExtractor()
        }
        return Static.instance
    }
    
    var localDict: DictionaryForLang?
    
    override init() {
        super.init()
        localDict = fetchSystemTranslate()
    }
    
    func fetchSystemTranslate() -> DictionaryForLang {
        
        var newDict = DictionaryForLang()
        
        // Independent Strings.
        
        // Most of strings.
        let swiftUIPath = "/System/Library/Frameworks/SwiftUI.framework"
        if let menuDict = dictFrom(frameworkPath: swiftUIPath, localizedFileName: "MainMenu.strings") {
            newDict = menuDict
        } else {
            print("No result for: \(swiftUIPath) - MainMenu.strings")
        }
        
        // Most of the font menu.
        let appKitPath = "/System/Library/Frameworks/AppKit.framework"
        if let fontDict = dictFrom(frameworkPath: appKitPath, localizedFileName: "FontManager.strings") {
            newDict = mergeDicts(first: newDict, second: fontDict)
        } else {
            print("No result for: \(appKitPath) - FontManager.strings")
        }

        // For "Show Toolbar" and "Show Sidebar".
        if let toolbarDict = dictFrom(frameworkPath: appKitPath, localizedFileName: "Toolbar.strings") {
            newDict = mergeDicts(first: newDict, second: toolbarDict)
        } else {
            print("No result for: \(appKitPath) - Toolbar.strings")
        }

        // For "Paste And Match Style".
        let uiKitServicePath = "/System/Library/PrivateFrameworks/UIKitServices.framework"
        if let uiKitServiceDict = dictFrom(frameworkPath: uiKitServicePath, localizedFileName: "Localizable.strings") {
            newDict = mergeDicts(first: newDict, second: uiKitServiceDict)
        } else {
            print("No result for: \(uiKitServicePath) - Localizable.strings")
        }

        // For "Ligature" with "es".
        let coreTextPath = "/System/Library/Frameworks/CoreText.framework"
        if let coreTextDict = dictFrom(frameworkPath: coreTextPath, localizedFileName: "FeatureTypeNames.strings") {
            newDict = mergeDicts(first: newDict, second: coreTextDict)
        } else {
            print("No result for: \(coreTextPath) - FeatureTypeNames.strings")
        }

        // For "Bigger".
        let uiKitMacHelperPath = "/System/Library/PrivateFrameworks/UIKitMacHelper.framework"
        let uiKitMacHelperNibPath = uiKitMacHelperPath + "/Resources/Base.lproj/MainMenu.nib"
        if let dict = dictFrom(frameworkPath: uiKitMacHelperPath, localizedFileName: "MainMenu.strings"),
           let keysFromtrNib = keysFromNib(path: uiKitMacHelperNibPath)?.filter({$0.source == "Bigger"}) {
            let mappedDict = mapSourceFrom(keys: keysFromtrNib, to: dict)
            newDict = mergeDicts(first: newDict, second: mappedDict)
        } else {
            print("No result for: \(uiKitMacHelperPath) - MainMenu.strings")
        }
        
        // Stings with NIB.

        // For "Print" and "Page Setup".
        let scriptEditerPath = "/System/Applications/Utilities/Script Editor.app"
        let scriptEditerNibPath = scriptEditerPath + "/Contents/Resources/Base.lproj/SEMainMenu.nib"
        if let dict = dictFrom(frameworkPath: scriptEditerPath, localizedFileName: "SEMainMenu.strings"),
           let keysFromtrNib = keysFromNib(path: scriptEditerNibPath)?.filter({$0.source == "Print…" || $0.source == "Page Setup…"}) {
            let mappedDict = mapSourceFrom(keys: keysFromtrNib, to: dict)
            newDict = mergeDicts(first: newDict, second: mappedDict)
        } else {
            print("No result for: \(scriptEditerPath) - SEMainMenu.strings")
        }
        
        // For "Revert to Saved".
        let terminalPath = "/System/Applications/Utilities/Terminal.app"
        let terminalNibPath = terminalPath + "/Contents/Resources/Base.lproj/MainMenu.nib"
        if let dict = dictFrom(frameworkPath: terminalPath, localizedFileName: "MainMenu.strings"),
           let keysFromtrNib = keysFromNib(path: terminalNibPath)?.filter({$0.source == "Revert to Saved"}) {
            let mappedDict = mapSourceFrom(keys: keysFromtrNib, to: dict)
            newDict = mergeDicts(first: newDict, second: mappedDict)
        } else {
            print("No result for: \(terminalPath) - MainMenu.strings")
        }
        
        return newDict
    }
    
    func mergeDicts(first: DictionaryForLang, second: DictionaryForLang) -> DictionaryForLang {
        var newDict = first
        for key in first.keys {
            if let newEntries = second[key] {
                let combinedEntries = Array(Set(newDict[key]! + newEntries))
                newDict[key]! = combinedEntries
            }
        }
        return newDict
    }
    
    func dictFrom(frameworkPath: String, localizedFileName: String) -> DictionaryForLang? {
        guard let bundle = Bundle(path: frameworkPath) else { return nil }
        guard !bundle.localizations.isEmpty else { return nil }
        
        var dicts = DictionaryForLang()
        
        for langCode in bundle.localizations {
            let mainPath = "\(bundle.bundlePath)/Resources/\(langCode).lproj" // For framework.
            let subPath = "\(bundle.bundlePath)/Contents/Resources/\(langCode).lproj" // For Application.
            guard let localizedFiles = (try? FileManager.default.contentsOfDirectory(atPath: mainPath)) ?? (try? FileManager.default.contentsOfDirectory(atPath: subPath)) else { return nil }
            
            let dictForOneLanguage = localizedFiles.compactMap({ localizedFile -> [DictionaryEntry]? in
                
                guard localizedFile == localizedFileName else { return nil }
                let fileUrl = bundle.url(forResource: localizedFile, withExtension: nil, subdirectory: nil, localization: langCode)
                guard let fileUrl = fileUrl, let data = try? Data(contentsOf: fileUrl) else { return nil }
                
                let decoder = PropertyListDecoder()
                guard let plist = try? decoder.decode(Dictionary<String, String>.self, from: data) else { return nil }
                
                // SwiftUI has some '$_' in the souce text
                return plist.map({ DictionaryEntry(source: $0.key.components(separatedBy: "$").first!, target: $0.value) })
                
            }).first // Find file from bundle.
            
            dicts[langCode] = dictForOneLanguage
        }
        
        if dicts.isEmpty { return nil }
        
        return dicts
    }
    
    func mapKeysToLocalDictionary(keys: [XibKey], appName: String) -> DictionaryForLang? {
        guard let localDict = localDict else { return nil }
        
        let newDicts = localDict.mapValues({ entries -> [DictionaryEntry] in
            let newEntrys = entries.compactMap({ entry -> DictionaryEntry? in
                if entry.source.components(separatedBy: "%@").count > 2 { return nil }
                // Some items might include the app name.
                let matchedKeys = keys.filter({$0.source == String(format: entry.source, appName)})
                var newEntry = entry
                newEntry.keys = matchedKeys.map({$0.key})
                return newEntry
            })
            return newEntrys.filter({!$0.keys.isEmpty})
        })
        
        if newDicts.isEmpty { return nil }
        
        return newDicts
    }
    
    // MARK: - Deal with nib.
    
    func keysFromNib(path: String) -> [XibKey]? {
        
        func XibKeysFrom(stringArray: [String]) -> [XibKey]? {
            var keyArray = [String : String]()
            var count = stringArray.count
            while count > 1 {
                let item = stringArray[stringArray.count - count]
                if item.hasSuffix(".title") {
                    let source = stringArray[stringArray.count - count + 1]
                    if !source.hasSuffix(".title") {
                        count -= 1
                        keyArray[item] = source
                    }
                }
                count -= 1
            }
            if keyArray.isEmpty { return nil }
            return keyArray.map({XibKey(key: $0.key, source: $0.value)})
        }
        
        // Can parse as a plist.
        // https://stackoverflow.com/questions/3726400/
        if let dict = NSDictionary(contentsOfFile: path) {
            let array = dict["$objects"] as! Array<Any>
            let filtered = array.filter({$0 as? String != nil}) as! [String] // Remove non-text stuff.
            return XibKeysFrom(stringArray: filtered)
        }
        
        // Fallback.
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let ascii = data.printableAscii
        let words = ascii.components(separatedBy: "/").filter({$0.count > 1})
        return XibKeysFrom(stringArray: words)
    }
    
    func mapSourceFrom(keys: [XibKey], to dict: DictionaryForLang) -> DictionaryForLang {
        let newDict = dict.mapValues({ dictItem -> [DictionaryEntry] in
            return dictItem.compactMap({ entryItem -> DictionaryEntry? in
                guard let realSource = keys.first(where: {$0.key == entryItem.source})?.source else { return nil }
                return DictionaryEntry(source: realSource, target: entryItem.target, keys: entryItem.keys)
            })
        })
        return newDict
    }
}

//https://stackoverflow.com/questions/48306895/
extension UInt8 {
    var printableAscii : String {
        switch self {
        case 32..<128:  return String(bytes: [self], encoding:.ascii)!
        default:
            if String(bytes: [(self & 127)], encoding:.ascii)! == "b" {
                return "…"
            } else {
                return "/"
            }
        }
    }
}

extension Collection where Element == UInt8 {
    var printableAscii : String {
        return self.map { $0.printableAscii } .joined()
    }
}
