import SwiftUI
import WhisperKit
import AVFoundation
import AppKit

class TranscriptionService: ObservableObject {
  // MARK: - Published Properties
  @Published var hasInputMonitoringPermission = false
  @Published var hasAccessibilityPermissions = false
  @Published var isRecording = false
  @Published var isTranscribing = false
  @Published var transcriptionResult = ""
  
  // MARK: - Private Properties
  private var whisperKit: WhisperKit?
  private var audioRecorder: AVAudioRecorder?
  private var keyboardMonitor: Any?
  private var recordingURL: URL?
  private let inputMonitoring = InputMonitoringPermission.shared
  
  #if os(iOS)
  private var recordingSession: AVAudioSession?
  #endif
  
  // MARK: - Initialization
  init() {
    print("🚀 TranscriptionService: Initializing...")
    checkPermissions()
    setupAudioSession()
    setupKeyboardMonitor()
  }
  
  // MARK: - Permission Handling
  private func checkPermissions() {
    #if os(macOS)
    print("🔍 Checking all required permissions...")
    
    // Check Input Monitoring
    hasInputMonitoringPermission = inputMonitoring.checkPermission()
    if !hasInputMonitoringPermission {
      print("⚠️ Input Monitoring permission needed")
      inputMonitoring.requestPermission()
    }
    
    // Check Accessibility
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    hasAccessibilityPermissions = trusted
    print("🔐 Accessibility permission status: \(trusted)")
    
    // Re-check after a delay to catch permission changes
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      self?.hasInputMonitoringPermission = self?.inputMonitoring.checkPermission() ?? false
      self?.hasAccessibilityPermissions = AXIsProcessTrusted()
    }
    #endif
  }
  
  // MARK: - Audio Session Setup
  private func setupAudioSession() {
    print("🎙 Setting up audio session...")
    #if os(iOS)
    recordingSession = AVAudioSession.sharedInstance()
    do {
      try recordingSession?.setCategory(.playAndRecord, mode: .default)
      try recordingSession?.setActive(true)
      print("✅ Audio session setup complete")
    } catch {
      print("❌ Failed to set up recording session: \(error)")
    }
    #endif
  }
  
  // MARK: - Keyboard Monitoring
  private func setupKeyboardMonitor() {
    #if os(macOS)
    print("⌨️ Setting up keyboard monitor...")
    
    guard inputMonitoring.checkPermission() else {
      print("⚠️ Cannot setup keyboard monitor - missing Input Monitoring permission")
      return
    }
    
    // Local monitor for when app is active
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      print("⌨️ Local keyboard event detected - keyCode: \(event.keyCode)")
      if event.keyCode == 96 { // F5
        print("🎯 F5 key pressed (local)")
        self?.handleF5Press()
        return nil // Consume the event
      }
      return event
    }
    
    // Global monitor for when app is in background
    keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      print("⌨️ Global keyboard event detected - keyCode: \(event.keyCode)")
      if event.keyCode == 96 { // F5
        print("🎯 F5 key pressed (global)")
        self?.handleF5Press()
      }
    }
    print("✅ Keyboard monitors successfully set up")
    #endif
  }
  
  // MARK: - F5 Key Handling
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
            pasteTranscribedText(transcriptionResult)
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
  
  // MARK: - Recording Functions
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
      print("❌ Failed to start recording: \(error)")
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
  
  // MARK: - Transcription
  func transcribe(audio url: URL) async -> String {
    print("🎯 Transcribing audio from: \(url.path)")
    do {
      if whisperKit == nil {
        print("🔄 Initializing WhisperKit...")
        whisperKit = try await WhisperKit(model: "base")
      }
      
      print("📝 Starting transcription process...")
      let result = try await whisperKit?.transcribe(audioPath: url.path)
      print("✅ Transcription successful")
      return result?.map { $0.text }.joined(separator: " ") ?? "No transcription"
    } catch {
      print("❌ Transcription error: \(error)")
      return "Error: \(error.localizedDescription)"
    }
  }
  
  // MARK: - Paste Handling
  private func pasteTranscribedText(_ text: String) {
    print("📋 Attempting to paste text: \(text)")
    
    #if os(macOS)
    // Create a temporary pasteboard
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    
    // Simulate Cmd+V keystroke
    let source = CGEventSource(stateID: .hidSystemState)
    
    // Create key down and up events for Command key (⌘)
    let cmdKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
    let cmdKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
    
    // Create key down and up events for V key
    let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
    let vKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
    
    // Set command flag for V key events
    vKeyDown?.flags = .maskCommand
    vKeyUp?.flags = .maskCommand
    
    // Post the events in sequence
    cmdKeyDown?.post(tap: .cghidEventTap)
    vKeyDown?.post(tap: .cghidEventTap)
    vKeyUp?.post(tap: .cghidEventTap)
    cmdKeyUp?.post(tap: .cghidEventTap)
    
    print("✅ Paste command sent successfully")
    #endif
  }
  
  // MARK: - Cleanup
  deinit {
    print("♻️ TranscriptionService: Cleaning up resources")
    #if os(macOS)
    if let monitor = keyboardMonitor {
      NSEvent.removeMonitor(monitor)
      print("🧹 Removed keyboard monitor")
    }
    #endif
  }
}
