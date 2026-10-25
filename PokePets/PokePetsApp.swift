import SwiftUI

@main
struct PokePetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }      // the real Settings window opens from the menu bar icon (right-click)
    }
}
