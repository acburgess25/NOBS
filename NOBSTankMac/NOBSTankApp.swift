import SwiftUI

@main
struct NOBSTankApp: App {
    @State private var supervisor = TankSupervisor()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(supervisor: supervisor)
        } label: {
            Image(systemName: supervisor.serverStatus.symbolName)
        }
        .menuBarExtraStyle(.window)
    }
}
