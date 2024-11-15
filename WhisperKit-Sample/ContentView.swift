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
      if !transcriptionService.hasInputMonitoringPermission || 
         !transcriptionService.hasAccessibilityPermissions {
        VStack(spacing: 12) {
          Text("Required Permissions")
            .font(.headline)
          
          if !transcriptionService.hasInputMonitoringPermission {
            PermissionRow(
              title: "Input Monitoring",
              description: "Required to detect F5 key press",
              action: {
                InputMonitoringPermission.shared.checkPermission()
              }
            )
          }
          
          if !transcriptionService.hasAccessibilityPermissions {
            PermissionRow(
              title: "Accessibility",
              description: "Required to paste transcribed text",
              action: {
                NSWorkspace.shared.open(
                  URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                )
              }
            )
          }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding()
      }
      #endif
    }
    .padding()
  }
}

struct PermissionRow: View {
  let title: String
  let description: String
  let action: () -> Void
  
  var body: some View {
    VStack(alignment: .leading) {
      Text(title)
        .font(.subheadline)
        .bold()
      Text(description)
        .font(.caption)
        .foregroundColor(.secondary)
      Button("Open Settings") {
        action()
      }
      .padding(.top, 4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color.white.opacity(0.5))
    .cornerRadius(8)
  }
}

#Preview {
  ContentView()
}
