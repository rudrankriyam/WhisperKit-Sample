import AppKit

class InputMonitoringPermission {
  static let shared = InputMonitoringPermission()
  
  @Published private(set) var hasPermission = false
  
  func checkPermission() -> Bool {
    print("🔍 Checking Input Monitoring permission status...")
    
    // Use IOHIDCheckAccess instead of IOHIDRequestAccess for checking
    let inputMonitoringAccess = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    print("🔑 Current Input Monitoring status: \(inputMonitoringAccess)")
    
    hasPermission = (inputMonitoringAccess == kIOHIDAccessTypeGranted)
    return hasPermission
  }
  
  func requestPermission() {
    print("🔐 Requesting Input Monitoring permission...")
    
    // Only request if we don't have permission
    if !hasPermission {
      let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
      print("🎯 Permission request result: \(granted)")
      hasPermission = granted
      
      if !granted {
        print("⚠️ Permission not granted, opening System Settings...")
        openSystemSettings()
      }
    }
  }
  
  private func openSystemSettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
      NSWorkspace.shared.open(url)
      print("🔓 Opened System Settings for Input Monitoring")
    }
  }
} 