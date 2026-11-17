import SwiftUI

@main
struct ZhanluQuotaApp: App {
    @StateObject private var store = KeyStore()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
        }
    }
}
