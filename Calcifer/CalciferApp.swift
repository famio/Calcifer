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
        store = Store(initialState: AppState(),
                      reducer: appReducer,
                      environment: AppEnvironment(fileManagerEffect: .live,
                                                  photogrammetryEffect: .live)
        )
    }
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let store: Store<AppState, AppAction>
    
    var body: some Scene {
        WithViewStore(store) { viewStore in
            WindowGroup {
                MainView(
                    store: store.scope(state: { $0 }, action: { $0 })
                )
            }
            .commands {
                CommandGroup(replacing: .newItem) {
                    OpenFolderCommand(viewStore: viewStore)
                }
            }
        }
    }
    
    private func OpenFolderCommand(viewStore: ViewStore<AppState, AppAction>) -> some View {
        return Button("Open Folder") {
            viewStore.send(.openFolderMenuTapped)
        }
        .keyboardShortcut("o", modifiers: [.command])
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}
