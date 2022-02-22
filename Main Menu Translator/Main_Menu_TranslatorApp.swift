//
//  Main_Menu_TranslatorApp.swift
//  Main Menu Translator
//
//  Created by Jinyu Meng on 2022/02/20.
//

import SwiftUI

@main
struct Main_Menu_TranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView().frame(minWidth:290, maxWidth: 290)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        
    }
}
