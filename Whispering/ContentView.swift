//
//  ContentView.swift
//  Whispering
//
//  Created by Rudrank Riyam on 11/10/24.
//

import SwiftUI
import WhisperKit

struct ContentView: View {
  @StateObject private var transcriptionService = TranscriptionService()
  @State private var transcriptionResult = ""
  @State private var isTranscribing = false

  var body: some View {
    VStack {
      Image(systemName: "waveform")
        .imageScale(.large)
        .foregroundStyle(.tint)
      
      if isTranscribing {
        ProgressView("Transcribing...")
      }
      
      Text(transcriptionResult)
        .padding()
    }
    .padding()
    .task {
      isTranscribing = true
      
      await transcriptionService.setup()
      // Get the file URL and verify it exists
      if let audioURL = Bundle.main.url(forResource: "test", withExtension: "wav") {
        print("Found audio file at: \(audioURL.path)")
        
        // Verify file exists
        if FileManager.default.fileExists(atPath: audioURL.path) {
          transcriptionResult = await transcriptionService.transcribe(audio: audioURL)
        } else {
          transcriptionResult = "Error: Audio file not found in bundle"
        }
      } else {
        transcriptionResult = "Error: Could not create URL for audio file"
      }
      
      isTranscribing = false
    }
  }
}

#Preview {
  ContentView()
}

class TranscriptionService: ObservableObject {
  private var whisperKit: WhisperKit?

  init() {
  }

  func setup() async {
    do {
      let config = WhisperKitConfig(model: "base")
      whisperKit = try await WhisperKit(config)
    } catch {
      print("Error setting up WhisperKit: \(error)")
    }
  }

  func transcribe(audio: URL) async -> String {
    do {
      // Verify file exists and is readable
      guard FileManager.default.fileExists(atPath: audio.path) else {
        return "Error: Audio file not found at path"
      }
      
      // Print file information for debugging
      print("Attempting to transcribe file at: \(audio.path)")
      print("File exists: \(FileManager.default.fileExists(atPath: audio.path))")
      
      // Try to transcribe and get results
       if let results = try await whisperKit?.transcribe(audioPath: audio.path) {
        return results.map { $0.text }.joined(separator: " ")
      }
      return "No transcription results"
    } catch {
      print("Error transcribing audio: \(error)")
      return "Error: \(error.localizedDescription)"
    }
  }
}
