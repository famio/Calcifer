//
//  CalciferApp.swift
//  Calcifer
//
//  (c) 2021 Fumio Saruki (github.com/famio)

import SwiftUI
import ComposableArchitecture

@main
struct CalciferApp: App {

    init() {
        store = Store(initialState: AppReducer.State()) {
            AppReducer()
        }
    }

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let store: StoreOf<AppReducer>

    var body: some Scene {
        WindowGroup {
            MainView(
                store: store.scope(state: { $0 }, action: { $0 })
            )
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                OpenFolderCommand(appStore: store)
            }
        }
        .windowResizability(.contentSize)
    }

    private func OpenFolderCommand(appStore: StoreOf<AppReducer>) -> some View {
        return Button("Open Folder") {
            appStore.send(.openFolderMenuTapped)
        }
        .keyboardShortcut("o", modifiers: [.command])
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        logger.trace(#function)
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}
