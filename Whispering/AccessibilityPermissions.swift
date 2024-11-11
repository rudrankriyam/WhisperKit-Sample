import AppKit

class AccessibilityPermissions {
  static func requestPermissions() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    
    if !trusted {
      print("Accessibility permissions not granted. Prompting user...")
    }
  }
  
  static func checkPermissions() -> Bool {
    AXIsProcessTrusted()
  }
} 