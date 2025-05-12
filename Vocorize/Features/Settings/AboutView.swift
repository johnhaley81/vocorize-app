import ComposableArchitecture
import Inject
import SwiftUI
import Sparkle

struct AboutView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<SettingsFeature>
    @State var viewModel = CheckForUpdatesViewModel.shared
    @State private var showingChangelog = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                    Button("Check for Updates") {
                        viewModel.checkForUpdates()
                    }
                    .buttonStyle(.bordered)
                }
                HStack {
                    Label("Changelog", systemImage: "doc.text")
                    Spacer()
                    Button("Show Changelog") {
                        showingChangelog.toggle()
                    }
                    .buttonStyle(.bordered)
                    .sheet(isPresented: $showingChangelog, onDismiss: {
                        showingChangelog = false
                    }) {
                        ChangelogView()
                    }
                }
                				HStack {
					Label("Vocorize is open source", systemImage: "apple.terminal.on.rectangle")
                    Spacer()
                    Link("Visit our GitHub", destination: URL(string: "https://github.com/vocorize/app")!)
                }
                
                HStack {
                    Label("Support the developer", systemImage: "heart")
                    Spacer()
                    Link("Become a Sponsor", destination: URL(string: "https://github.com/sponsors/tnv1r")!)
                }
            }
        }
        .formStyle(.grouped)
        .enableInjection()
    }
}