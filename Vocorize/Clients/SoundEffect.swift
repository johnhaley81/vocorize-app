//
//  SoundEffect.swift
//  Vocorize
//
//  Created by Kit Langton on 1/26/25.
//

import AVFoundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation
import SwiftUI

// Thank you. Never mind then.What a beautiful idea.
public enum SoundEffect: String, CaseIterable {
  case pasteTranscript
  case startRecording
  case stopRecording
  case cancel

  public var fileName: String {
    self.rawValue
  }
}

@DependencyClient
public struct SoundEffectsClient {
  public var play: @Sendable (SoundEffect) async -> Void
  public var stop: @Sendable (SoundEffect) async -> Void
  public var stopAll: @Sendable () async -> Void
  public var preloadSounds: @Sendable () async -> Void
}

extension SoundEffectsClient: DependencyKey {
  public static var liveValue: SoundEffectsClient {
    let live = SoundEffectsClientLive()
    return SoundEffectsClient(
      play: { soundEffect in
        await live.play(soundEffect)
      },
      stop: { soundEffect in
        await live.stop(soundEffect)
      },
      stopAll: {
        await live.stopAll()
      },
      preloadSounds: {
        await live.preloadSounds()
      }
    )
  }
}

public extension DependencyValues {
  var soundEffects: SoundEffectsClient {
    get { self[SoundEffectsClient.self] }
    set { self[SoundEffectsClient.self] = newValue }
  }
}

actor SoundEffectsClientLive {
  
  @Shared(.vocorizeSettings) var vocorizeSettings: VocorizeSettings

  func play(_ soundEffect: SoundEffect) {
    guard vocorizeSettings.soundEffectsEnabled else { return }
    guard let player = audioPlayers[soundEffect] else {
      print("Sound not found: \(soundEffect)")
      return
    }
    player.volume = 0.2
    player.currentTime = 0
    player.play()
  }

  func stop(_ soundEffect: SoundEffect) {
    audioPlayers[soundEffect]?.stop()
  }

  func stopAll() {
    audioPlayers.values.forEach { $0.stop() }
  }

  func preloadSounds() async {
    guard !isSetup else { return }

    for soundEffect in SoundEffect.allCases {
      loadSound(soundEffect)
    }

    isSetup = true
  }

  private var audioPlayers: [SoundEffect: AVAudioPlayer] = [:]
  private var isSetup = false

  private func loadSound(_ soundEffect: SoundEffect) {
    guard let url = Bundle.main.url(
      forResource: soundEffect.fileName,
      withExtension: "mp3"
    ) else {
      print("Failed to find sound file: \(soundEffect.fileName).mp3")
      return
    }

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.prepareToPlay()
      audioPlayers[soundEffect] = player
    } catch {
      print("Failed to load sound \(soundEffect): \(error.localizedDescription)")
    }
  }
}
