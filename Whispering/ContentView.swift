//
//  ContentView.swift
//  Whispering
//
//  Created by Rudrank Riyam on 11/10/24.
//

import SwiftUI
import WhisperKit
import AVFoundation

struct ContentView: View {
  @StateObject private var transcriptionService = TranscriptionService()
  @State private var transcriptionResult = ""
  @State private var isTranscribing = false
  @State private var isRecording = false
  
  var body: some View {
    VStack {
      // Scrollable transcription results
      ScrollView {
        Text(transcriptionResult)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
          .accessibilityLabel("Transcription results")
      }
      
      if isTranscribing {
        ProgressView("Transcribing...")
          .accessibilityLabel("Transcribing audio")
      }
      
      // Recording controls
      HStack(spacing: 20) {
        Button(action: {
          if isRecording {
            stopRecording()
          } else {
            startRecording()
          }
        }) {
          Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
            .resizable()
            .frame(width: 44, height: 44)
            .foregroundColor(isRecording ? .red : .blue)
        }
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
        .disabled(isTranscribing)
        
        if isRecording {
          // Visual recording indicator
          HStack {
            Image(systemName: "waveform")
              .imageScale(.large)
              .foregroundStyle(.red)
            Text("Recording...")
              .foregroundColor(.red)
          }
        }
      }
      .padding()
    }
    .padding()
    .task {
      await transcriptionService.setup()
    }
  }
  
  private func startRecording() {
    isRecording = true
    Task {
      await transcriptionService.startRecording()
    }
  }
  
  private func stopRecording() {
    isRecording = false
    isTranscribing = true
    
    Task {
      if let recordingURL = await transcriptionService.stopRecording() {
        transcriptionResult = await transcriptionService.transcribe(audio: recordingURL)
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
  private var audioRecorder: AVAudioRecorder?
  private var recordingSession: AVAudioSession?
  private var recordingURL: URL?
  
  init() {
    setupAudioSession()
  }
  
  private func setupAudioSession() {
    recordingSession = AVAudioSession.sharedInstance()
    do {
      try recordingSession?.setCategory(.playAndRecord, mode: .default)
      try recordingSession?.setActive(true)
    } catch {
      print("Failed to set up recording session: \(error)")
    }
  }
  
  func setup() async {
    do {
      let config = WhisperKitConfig(model: "base")
      whisperKit = try await WhisperKit(config)
    } catch {
      print("Error setting up WhisperKit: \(error)")
    }
  }
  
  func startRecording() async {
    let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.wav")
    recordingURL = audioFilename
    
    let settings = [
      AVFormatIDKey: Int(kAudioFormatLinearPCM),
      AVSampleRateKey: 16000,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    do {
      audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
      audioRecorder?.record()
    } catch {
      print("Could not start recording: \(error)")
    }
  }
  
  func stopRecording() async -> URL? {
    audioRecorder?.stop()
    return recordingURL
  }
  
  func transcribe(audio: URL) async -> String {
    do {
      guard FileManager.default.fileExists(atPath: audio.path) else {
        return "Error: Audio file not found at path"
      }
      
      print("Attempting to transcribe file at: \(audio.path)")
      
      if let results = try await whisperKit?.transcribe(audioPath: audio.path) {
        return results.map { $0.text }.joined(separator: " ")
      }
      return "No transcription results"
    } catch {
      print("Error transcribing audio: \(error)")
      return "Error: \(error.localizedDescription)"
    }
  }
  
  private func getDocumentsDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }
}
