import SwiftUI

@main
struct TempoApp: App {
    @State private var history = LocalHistory()
    var body: some Scene { WindowGroup { RootView().environment(history).preferredColorScheme(.dark) } }
}
