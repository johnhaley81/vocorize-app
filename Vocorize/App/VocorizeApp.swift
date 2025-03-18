import ComposableArchitecture
import Inject
import Sparkle
import SwiftUI

@main
struct VocorizeApp: App {
	static let appStore = Store(initialState: AppFeature.State()) {
		AppFeature()
	}

	@NSApplicationDelegateAdaptor(VocorizeAppDelegate.self) var appDelegate
  
	var body: some Scene {
		MenuBarExtra {
			CheckForUpdatesView()

			Button("Settings...") {
				appDelegate.presentSettingsView()
			}.keyboardShortcut(",")
			
			Divider()
			
			Button("Quit") {
				NSApplication.shared.terminate(nil)
			}.keyboardShortcut("q")
		} label: {
			let image: NSImage = {
				let ratio = $0.size.height / $0.size.width
				$0.size.height = 18
				$0.size.width = 18 / ratio
				return $0
			}(NSImage(named: "VocorizeIcon")!)
			Image(nsImage: image)
		}


		WindowGroup {}.defaultLaunchBehavior(.suppressed)
			.commands {
				CommandGroup(after: .appInfo) {
					CheckForUpdatesView()

					Button("Settings...") {
						appDelegate.presentSettingsView()
					}.keyboardShortcut(",")
				}
			}
	}
}
