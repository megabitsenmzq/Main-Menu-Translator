//
//  ContentView.swift
//  Main Menu Translator
//
//  Created by Jinyu Meng on 2022/02/20.
//

import SwiftUI

struct ContentView: View {
    @State var localEntriesCount = 0
    @State var targetCount = 0
    @State var matchesCount = 0
    @State var loadingFiles = false
    @State var okToStartTranslate = false
    @State var translating = false
    @State var finished = false
    
    @State var appName = "AppName"
    @State var xliffFiles = [XliffFile]()
    @State var targetKeys = [XibKey]()
    @State var dictsToUse = DictionaryForLang()
    
    var dictCountView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .opacity(0.05)
                .layoutPriority(-1)
            HStack {
                Spacer()
                Text("📖 Entries in dictionary: \(localEntriesCount)")
                    .fixedSize()
                    .padding(20)
                    .onAppear(perform: {
                        if let dict = TranslateExtractor.shared.localDict, let first = dict.first {
                            localEntriesCount = first.value.count
                        }
                    })
                Spacer()
            }
        }
    }
    
    var openFolderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .opacity(0.05)
                .layoutPriority(-1)
            VStack(alignment: .leading) {
                Text("1⃣️ Export Xcloc files from Xcode. ")
                    .fixedSize()
                    .padding([.top,.leading,.trailing], 20)
                Text("[Product > Export Localizations…]")
                    .foregroundColor(.gray)
                    .fixedSize()
                    .padding([.leading,.trailing], 20)
                    .padding(.top, 10)
                Text("2⃣️ Open folder. ")
                    .fixedSize()
                    .padding([.leading,.trailing], 20)
                    .padding(.top, 10)
                HStack{
                    Button("Open Folder With Xclocs", action: {
                        openFiles()
                    })
                    if loadingFiles {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.leading, 5)
                    }
                    Spacer()
                }
                .padding([.bottom,.leading,.trailing], 20)
                .padding(.top, 10)
            }
        }
    }
    
    var fileInfoView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .opacity(0.05)
                .layoutPriority(-1)
            HStack {
                VStack(alignment: .leading) {
                    HStack(spacing: 2){
                        Text("🛠")
                            .fixedSize()
                        TextField("AppName", text: $appName, onEditingChanged: { begin in
                            if begin {
                                
                            } else {
                                DispatchQueue.main.async {
                                    NSApp.keyWindow?.makeFirstResponder(nil)
                                }
                                if appName == "" {
                                    appName = "AppName"
                                }
                            }
                        })
                            .textFieldStyle(.roundedBorder)
                    }
                        .padding([.top, .leading,.trailing], 20)
                    Text("🎯 Target keys count: \(targetCount)")
                        .fixedSize()
                        .padding([.leading,.trailing], 20)
                        .padding(.top, 10)
                    Text("💎 Matches: \(matchesCount)")
                        .fixedSize()
                        .padding([.bottom,.leading,.trailing], 20)
                        .padding(.top, 10)
                }
                Spacer()
            }
        }
        
    }
    
    var translateView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .opacity(0.05)
                .layoutPriority(-1)
            VStack(alignment: .leading) {
                Text("3⃣️ Translate Now!")
                    .fixedSize()
                    .padding([.top, .leading,.trailing], 20)
                HStack{
                    Button("Translate", action: {
                        finished = false
                        translating = true
                        DispatchQueue(label: "Process").async {
                            translate()
                        }
                    })
                    if translating {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.leading, 5)
                    }
                    Spacer()
                }
                .padding([.bottom,.leading,.trailing], 20)
                .padding(.top, 10)
            }
        }
    }
    
    
    var finishedView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .opacity(0.05)
                .layoutPriority(-1)
            HStack {
                VStack(alignment: .leading) {
                    Text("🎉 Import files back to Xcode.")
                        .fixedSize()
                        .padding([.top,.leading,.trailing], 20)
                    Text("[Product > Import Localizations…]")
                        .foregroundColor(.gray)
                        .fixedSize()
                        .padding([.bottom,.leading,.trailing], 20)
                        .padding(.top, 10)
                }
                Spacer()
            }
        }
    }
    
    var body: some View {
        VStack {
            dictCountView
            .padding(.bottom, 5)
            
            openFolderView
            
            if okToStartTranslate {
                fileInfoView
                translateView
            }
            if finished {
                finishedView
            }
        }
        .padding()
    }
    
    func openFiles() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.begin { (result) in
            if result == NSApplication.ModalResponse.OK {
                guard let url = openPanel.url else { return }
                okToStartTranslate = false
                finished = false
                appName = "AppName"
                xliffFiles = [XliffFile]()
                targetKeys = [XibKey]()
                dictsToUse = DictionaryForLang()
                DispatchQueue(label: "Process").async {
                    loadFrom(url: url)
                }
            }
        }
    }
    
    func loadFrom(url: URL) {
        loadingFiles = true
        guard let items = XclocReader().allLanguagesFrom(path: url.path) else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Xcloc files not found."
                alert.runModal()
                loadingFiles = false
            }
            return
        }
        
        xliffFiles = items
        guard let item = items.first(where: {$0.lang == "en"}) else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "English files not found."
                alert.runModal()
                loadingFiles = false
            }
            return
        }
        let result = XclocReader().allMenuKeysFrom(xliffPath: item.path)
        let keys = result?.keys
        let appName = result?.appName
        if let keys = keys, !keys.isEmpty, let appName = appName {
            self.appName = appName
            targetCount = Array(Set(keys.map({$0.source}))).count
            targetKeys = keys
            
            if let newDict = TranslateExtractor.shared.mapKeysToLocalDictionary(keys: keys, appName: appName) {
                dictsToUse = newDict
                if let firstLang = newDict.first {
                    matchesCount = firstLang.value.count
                }
            }
            
            DispatchQueue.main.async {
                okToStartTranslate = true
                loadingFiles = false
            }
        }
    }
    
    func translate() {
        var result = false
        for item in xliffFiles {
            guard item.lang != "en" else { continue }
            let langToFind = item.lang.replacingOccurrences(of: "-", with: "_", options: .literal, range: nil)
            var subLangToFind: String?
            
            if langToFind == "zh_Hans" { subLangToFind = "zh_CN" }
            if langToFind == "zh_Hant" { subLangToFind = "zh_TW" }
            
            if let dictForLang = dictsToUse.first(where: {$0.key == langToFind}) {
                result = XclocReader().translate(xliffPath: item.path, with: dictForLang.value, appName: appName)
            } else if let dictForLang = dictsToUse.first(where: {$0.key == subLangToFind}) {
                result = XclocReader().translate(xliffPath: item.path, with: dictForLang.value, appName: appName)
            }
        }
        DispatchQueue.main.async {
            translating = false
            if result {
                finished = true
            } else {
                let alert = NSAlert()
                alert.messageText = "Translate error."
                alert.runModal()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
