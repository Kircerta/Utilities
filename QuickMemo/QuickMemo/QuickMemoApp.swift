import SwiftUI

@main
struct QuickMemoApp: App {
    var body: some Scene {

        MenuBarExtra {

            ContentView()
        } label: {

            Image(systemName: "note.text")
        }

        .menuBarExtraStyle(.window)
    }
}
