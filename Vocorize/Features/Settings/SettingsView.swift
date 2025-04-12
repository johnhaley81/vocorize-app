import ComposableArchitecture
import Inject
import SwiftUI

struct SettingsView: View {
	@ObserveInjection var inject
	@Bindable var store: StoreOf<SettingsFeature>

	var body: some View {
		Form {
			// --- Permissions Section ---
			Section {
				// Microphone
				HStack {
					Label("Microphone", systemImage: "mic.fill")
					Spacer()
					switch store.microphonePermission {
					case .granted:
						Label("Granted", systemImage: "checkmark.circle.fill")
							.foregroundColor(.green)
							.labelStyle(.iconOnly)
					case .denied:
						Button("Request Permission") {
							store.send(.requestMicrophonePermission)
						}
						.buttonStyle(.borderedProminent)
						.tint(.blue)
					case .notDetermined:
						Button("Request Permission") {
							store.send(.requestMicrophonePermission)
						}
						.buttonStyle(.bordered)
					}
				}

				// Accessibility
				HStack {
					Label("Accessibility", systemImage: "accessibility")
					Spacer()
					switch store.accessibilityPermission {
					case .granted:
						Label("Granted", systemImage: "checkmark.circle.fill")
							.foregroundColor(.green)
							.labelStyle(.iconOnly)
					case .denied:
						Button("Request Permission") {
							store.send(.requestAccessibilityPermission)
						}
						.buttonStyle(.borderedProminent)
						.tint(.blue)
					case .notDetermined:
						Button("Request Permission") {
							store.send(.requestAccessibilityPermission)
						}
						.buttonStyle(.bordered)
					}
				}

			} header: {
				Text("Permissions")
			} footer: {
				Text("Ensure Vocorize can access your microphone and system accessibility features.")
					.font(.footnote)
					.foregroundColor(.secondary)
			}

			// --- Input Device Selection Section ---
			if store.microphonePermission == .granted && !store.availableInputDevices.isEmpty {
				Section {
					// Input device picker
					HStack {
						Label {
							Picker("Input Device", selection: $store.vocorizeSettings.selectedMicrophoneID) {
								Text("System Default").tag(nil as String?)
								ForEach(store.availableInputDevices) { device in
									Text(device.name).tag(device.id as String?)
								}
							}
							.pickerStyle(.menu)
							.id(UUID()) // Force refresh when devices change
						} icon: {
							Image(systemName: "mic.circle")
						}

						Button(action: {
							store.send(.loadAvailableInputDevices)
						}) {
							Image(systemName: "arrow.clockwise")
						}
						.buttonStyle(.borderless)
						.help("Refresh available input devices")
					}

					// Show fallback note for selected device not connected
					if let selectedID = store.vocorizeSettings.selectedMicrophoneID,
					   !store.availableInputDevices.contains(where: { $0.id == selectedID })
					{
						Text("Selected device not connected. System default will be used.")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				} header: {
					Text("Microphone Selection")
				} footer: {
					Text("Override the system default microphone with a specific input device. This setting will persist across sessions.")
						.font(.footnote)
						.foregroundColor(.secondary)
				}
			}

			// --- Transcription Model Section ---
			Section("Transcription Model") {
				ModelDownloadView(store: store.scope(state: \.modelDownload, action: \.modelDownload)
				)
			}

			Label {
				Picker("Output Language", selection: $store.vocorizeSettings.outputLanguage) {
					ForEach(store.languages, id: \.id) { language in
						Text(language.name).tag(language.code)
					}
				}
				.pickerStyle(.menu)
			} icon: {
				Image(systemName: "globe")
			}

			// --- Hot Key Section ---
			Section("Hot Key") {
				let hotKey = store.vocorizeSettings.hotkey
				let key = store.isSettingHotKey ? nil : hotKey.key
				let modifiers = store.isSettingHotKey ? store.currentModifiers : hotKey.modifiers

				VStack(spacing: 12) {
					// Info text for full keyboard shortcut support
					if hotKey.key != nil {
						Text("You're using a full keyboard shortcut. Double-tap is recommended.")
							.font(.caption)
							.foregroundColor(.secondary)
							.frame(maxWidth: .infinity, alignment: .center)
					}

					// Hot key view
					HStack {
						Spacer()
						HotKeyView(modifiers: modifiers, key: key, isActive: store.isSettingHotKey)
							.animation(.spring(), value: key)
							.animation(.spring(), value: modifiers)
						Spacer()
					}
					.contentShape(Rectangle())
					.onTapGesture {
						store.send(.startSettingHotKey)
					}
				}

				// Double-tap toggle (for key+modifier combinations)
				if hotKey.key != nil {
					Label {
						Toggle("Use double-tap only", isOn: $store.vocorizeSettings.useDoubleTapOnly)
						Text("Recommended for custom hotkeys to avoid interfering with normal usage")
							.font(.caption)
							.foregroundColor(.secondary)
					} icon: {
						Image(systemName: "hand.tap")
					}
				}

				// Minimum key time (for modifier-only shortcuts)
				if store.vocorizeSettings.hotkey.key == nil {
					Label {
						Slider(value: $store.vocorizeSettings.minimumKeyTime, in: 0.0 ... 2.0, step: 0.1) {
							Text("Ignore below \(store.vocorizeSettings.minimumKeyTime, specifier: "%.1f")s")
						}
					} icon: {
						Image(systemName: "clock")
					}
				}
			}

			// --- Sound Section ---
			Section {
				Label {
					Toggle("Sound Effects", isOn: $store.vocorizeSettings.soundEffectsEnabled)
				} icon: {
					Image(systemName: "speaker.wave.2.fill")
				}
			} header: {
				Text("Sound")
			}

			// --- General Section ---
			Section {
				Label {
					Toggle("Open on Login",
					       isOn: Binding(
					       	get: { store.vocorizeSettings.openOnLogin },
					       	set: { store.send(.toggleOpenOnLogin($0)) }
					       ))
				} icon: {
					Image(systemName: "arrow.right.circle")
				}

				Label {
					Toggle("Show Dock Icon", isOn: $store.vocorizeSettings.showDockIcon)
				} icon: {
					Image(systemName: "dock.rectangle")
				}

				Label {
					Toggle("Use clipboard to insert", isOn: $store.vocorizeSettings.useClipboardPaste)
					Text("Use clipboard to insert text. Fast but may not restore all clipboard content.\nTurn off to use simulated keypresses. Slower, but doesn't need to restore clipboard")
				} icon: {
					Image(systemName: "doc.on.doc.fill")
				}

				Label {
					Toggle("Copy to clipboard", isOn: $store.vocorizeSettings.copyToClipboard)
					Text("Copy transcription text to clipboard in addition to pasting it")
				} icon: {
					Image(systemName: "doc.on.clipboard")
				}

				Label {
					Toggle(
						"Prevent System Sleep while Recording",
						isOn: Binding(
							get: { store.vocorizeSettings.preventSystemSleep },
							set: { store.send(.togglePreventSystemSleep($0)) }
						)
					)
				} icon: {
					Image(systemName: "zzz")
				}

				Label {
					Toggle(
						"Pause Media while Recording",
						isOn: Binding(
							get: { store.vocorizeSettings.pauseMediaOnRecord },
							set: { store.send(.togglePauseMediaOnRecord($0)) }
						)
					)
				} icon: {
					Image(systemName: "pause")
				}
			} header: {
				Text("General")
			}

			// --- History Section ---
			Section {
				Label {
					Toggle("Save Transcription History", isOn: Binding(
						get: { store.vocorizeSettings.saveTranscriptionHistory },
						set: { store.send(.toggleSaveTranscriptionHistory($0)) }
					))
					Text("Save transcriptions and audio recordings for later access")
						.font(.caption)
						.foregroundColor(.secondary)
				} icon: {
					Image(systemName: "clock.arrow.circlepath")
				}

				if store.vocorizeSettings.saveTranscriptionHistory {
					Label {
						HStack {
							Text("Maximum History Entries")
							Spacer()
							Picker("", selection: Binding(
								get: { store.vocorizeSettings.maxHistoryEntries ?? 0 },
								set: { newValue in
									store.vocorizeSettings.maxHistoryEntries = newValue == 0 ? nil : newValue
								}
							)) {
								Text("Unlimited").tag(0)
								Text("50").tag(50)
								Text("100").tag(100)
								Text("200").tag(200)
								Text("500").tag(500)
								Text("1000").tag(1000)
							}
							.pickerStyle(.menu)
							.frame(width: 120)
						}
					} icon: {
						Image(systemName: "number.square")
					}

					if store.vocorizeSettings.maxHistoryEntries != nil {
						Text("Oldest entries will be automatically deleted when limit is reached")
							.font(.caption)
							.foregroundColor(.secondary)
							.padding(.leading, 28)
					}
				}
			} header: {
				Text("History")
			} footer: {
				if !store.vocorizeSettings.saveTranscriptionHistory {
					Text("When disabled, transcriptions will not be saved and audio files will be deleted immediately after transcription.")
						.font(.footnote)
						.foregroundColor(.secondary)
				}
			}
		}
		.formStyle(.grouped)
		.task {
			await store.send(.task).finish()
		}
		.enableInjection()
	}
}
