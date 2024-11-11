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
  
  var body: some View {
    VStack {
      if transcriptionService.isTranscribing {
        ProgressView("Transcribing...")
      } else {
        Button(action: {
          // Button is now just for visual feedback
        }) {
          Image(systemName: transcriptionService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
            .font(.system(size: 44))
            .symbolRenderingMode(.multicolor)
        }
        .disabled(transcriptionService.isTranscribing)
      }
      
      if !transcriptionService.transcriptionResult.isEmpty {
        Text(transcriptionService.transcriptionResult)
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      
      #if os(macOS)
      if !transcriptionService.hasAccessibilityPermissions {
        VStack {
          Text("Accessibility Permissions Required")
            .font(.headline)
          Text("Please grant accessibility permissions in System Settings")
            .font(.caption)
          Button("Open System Settings") {
            print("🔐 Opening System Settings for accessibility permissions")
            NSWorkspace.shared.open(
              URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
          }
        }
        .padding()
      }
      #endif
    }
    .padding()
  }
}

#Preview {
  ContentView()
}

class TranscriptionService: ObservableObject {
  @Published var hasAccessibilityPermissions = false
  @Published var isRecording = false
  @Published var isTranscribing = false
  @Published var transcriptionResult = ""
  
  private var whisperKit: WhisperKit?
  private var audioRecorder: AVAudioRecorder?
  private var keyboardMonitor: Any?
  #if os(iOS)
  private var recordingSession: AVAudioSession?
  #endif
  private var recordingURL: URL?
  
  init() {
    print("🚀 TranscriptionService: Initializing...")
    setupAudioSession()
    setupKeyboardMonitor()
  }
  
  private func setupAudioSession() {
    #if os(iOS)
    recordingSession = AVAudioSession.sharedInstance()
    do {
      try recordingSession?.setCategory(.playAndRecord, mode: .default)
      try recordingSession?.setActive(true)
    } catch {
      print("Failed to set up recording session: \(error)")
    }
    #endif
  }
  
  private func setupKeyboardMonitor() {
    #if os(macOS)
    print("⌨️ Setting up keyboard monitor...")
    
    // Check initial permissions state
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    print("🔐 Initial accessibility trust status: \(trusted)")
    
    if trusted {
      hasAccessibilityPermissions = true
      print("✅ Accessibility permissions granted")
      
      // Local monitor setup
      print("🎯 Setting up local keyboard monitor")
      NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        print("⌨️ Local keyboard event detected - keyCode: \(event.keyCode)")
        if event.keyCode == 96 { // F5
          print("🎯 F5 key pressed (local)")
          self?.handleF5Press()
          return nil
        }
        return event
      }
      
      // Global monitor setup
      print("🌍 Setting up global keyboard monitor")
      keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
        print("⌨️ Global keyboard event detected - keyCode: \(event.keyCode)")
        if event.keyCode == 96 { // F5
          print("🎯 F5 key pressed (global)")
          self?.handleF5Press()
        }
      }
      print("✅ Keyboard monitors successfully set up")
      
    } else {
      hasAccessibilityPermissions = false
      print("⚠️ Accessibility permissions not granted")
      print("ℹ️ User needs to enable permissions in System Settings")
    }
    #endif
  }
  
  private func handleF5Press() {
    print("🎙 F5 Press Handler: Processing F5 key press")
    
    Task { @MainActor in
      if audioRecorder?.isRecording == true {
        print("🛑 Stopping recording...")
        isRecording = false
        isTranscribing = true
        
        if let recordingURL = await stopRecording() {
          print("🔤 Starting transcription...")
          do {
            transcriptionResult = await transcribe(audio: recordingURL)
            print("✅ Transcription completed: \(transcriptionResult)")
          } catch {
            print("❌ Transcription failed: \(error)")
            transcriptionResult = "Transcription failed: \(error.localizedDescription)"
          }
        }
        isTranscribing = false
      } else {
        print("▶️ Starting recording...")
        isRecording = true
        transcriptionResult = ""
        await startRecording()
      }
    }
  }
  
  deinit {
    print("♻️ TranscriptionService: Cleaning up resources")
    #if os(macOS)
    if let monitor = keyboardMonitor {
      NSEvent.removeMonitor(monitor)
      print("🧹 Removed keyboard monitor")
    }
    #endif
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
    print("🎙 Starting recording process...")
    let settings = [
      AVFormatIDKey: Int(kAudioFormatLinearPCM),
      AVSampleRateKey: 16000,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    do {
      let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      recordingURL = documentsPath.appendingPathComponent("recording.wav")
      
      if let url = recordingURL {
        print("📝 Recording to URL: \(url.path)")
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        print("✅ Recording started successfully")
      }
    } catch {
      print("❌ Failed to start recording: \(error.localizedDescription)")
    }
  }
  
  func stopRecording() async -> URL? {
    print("🛑 Stopping recording process...")
    
    guard let recorder = audioRecorder, let url = recordingURL else {
      print("⚠️ No active recorder or URL found")
      return nil
    }
    
    recorder.stop()
    print("✅ Recording stopped successfully")
    print("📍 Recording saved at: \(url.path)")
    
    return url
  }
  
  func transcribe(audio url: URL) async -> String {
    print("🎯 Transcribing audio from: \(url.path)")
    do {
      if whisperKit == nil {
        print("🔄 Initializing WhisperKit...")
        whisperKit = try await WhisperKit(verbose: true)
      }
      
      print("📝 Starting transcription process...")
      let result = try await whisperKit?.transcribe(audioPath: url.path)
      print("✅ Transcription successful")
      return result?.map { $0.text }.joined(separator: " ") ?? "No transcription available"
    } catch {
      print("❌ Transcription error: \(error)")
      return "Error: \(error.localizedDescription)"
    }
  }
  
  private func getDocumentsDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }
}
