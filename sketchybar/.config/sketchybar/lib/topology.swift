import AppKit
import CoreGraphics
import Foundation

struct Display: Decodable {
  let arrangementId: Int
  let directDisplayID: Int

  enum CodingKeys: String, CodingKey {
    case arrangementId = "arrangement-id"
    case directDisplayID = "DirectDisplayID"
  }
}

struct MonitorJSON: Decodable {
  let monitorId: Int
  let monitorName: String

  enum CodingKeys: String, CodingKey {
    case monitorId = "monitor-id"
    case monitorName = "monitor-name"
  }
}

struct Monitor {
  let monitorId: Int
  let appkitScreenId: Int?
  let name: String
}

func run(_ executable: String, _ arguments: [String]) -> Data? {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  let stdout = Pipe()
  process.standardOutput = stdout
  process.standardError = Pipe()

  do {
    try process.run()
  } catch {
    return nil
  }

  process.waitUntilExit()
  guard process.terminationStatus == 0 else { return nil }
  return stdout.fileHandleForReading.readDataToEndOfFile()
}

func string(_ data: Data?) -> String? {
  guard let data = data else { return nil }
  return String(data: data, encoding: .utf8)
}

func formattedMonitors(_ aerospaceBin: String) -> [Monitor] {
  guard let text = string(run(aerospaceBin, [
    "list-monitors",
    "--format",
    "%{monitor-id}|%{monitor-appkit-nsscreen-screens-id}|%{monitor-name}"
  ])) else {
    return []
  }

  return text.split(separator: "\n").compactMap { line in
    let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    guard parts.count >= 3, let monitorId = Int(parts[0]) else { return nil }
    return Monitor(monitorId: monitorId, appkitScreenId: Int(parts[1]), name: parts[2])
  }
}

func jsonMonitors(_ aerospaceBin: String) -> [Monitor] {
  guard let data = run(aerospaceBin, ["list-monitors", "--json"]) else {
    return []
  }

  let decoder = JSONDecoder()
  guard let monitors = try? decoder.decode([MonitorJSON].self, from: data) else {
    return []
  }

  return monitors.map { Monitor(monitorId: $0.monitorId, appkitScreenId: nil, name: $0.monitorName) }
}

let env = ProcessInfo.processInfo.environment
guard
  let sketchybarBin = env["SKETCHYBAR_BIN"],
  let aerospaceBin = env["AEROSPACE_BIN"],
  let displaysData = run(sketchybarBin, ["--query", "displays"])
else {
  exit(0)
}

let decoder = JSONDecoder()
guard let displays = try? decoder.decode([Display].self, from: displaysData) else {
  exit(0)
}

let formatted = formattedMonitors(aerospaceBin)
let monitors = formatted.isEmpty ? jsonMonitors(aerospaceBin) : formatted

if monitors.isEmpty {
  exit(0)
}

var arrangementByDirect: [Int: Int] = [:]
for display in displays {
  arrangementByDirect[display.directDisplayID] = display.arrangementId
}

var directByAppKitScreenId: [Int: Int] = [:]
var directByName: [String: Int] = [:]
var scaleByDirect: [Int: Double] = [:]

for (index, screen) in NSScreen.screens.enumerated() {
  guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
    continue
  }

  let directDisplayId = number.intValue
  let oneBasedIndex = index + 1

  directByAppKitScreenId[oneBasedIndex] = directDisplayId
  directByAppKitScreenId[-oneBasedIndex] = directDisplayId
  directByName[screen.localizedName] = directDisplayId
  scaleByDirect[directDisplayId] = Double(screen.backingScaleFactor)
}

for monitor in monitors {
  let directDisplayId = monitor.appkitScreenId.flatMap { directByAppKitScreenId[$0] }
    ?? directByName[monitor.name]
    ?? monitor.appkitScreenId.flatMap { arrangementByDirect[$0] != nil ? $0 : nil }

  let sketchybarDisplayId = directDisplayId.flatMap { arrangementByDirect[$0] } ?? monitor.monitorId
  let scale = directDisplayId.flatMap { scaleByDirect[$0] } ?? 1.0
  let isBuiltin = directDisplayId.map { CGDisplayIsBuiltin(CGDirectDisplayID($0)) != 0 }
    ?? monitor.name.localizedCaseInsensitiveContains("Built-in")
  let direct = directDisplayId ?? 0
  let appkit = monitor.appkitScreenId.map(String.init) ?? ""
  let displayKind = isBuiltin ? "builtin" : "external"

  print("\(monitor.monitorId)|\(sketchybarDisplayId)|\(direct)|\(appkit)|\(monitor.name)|\(scale)|\(displayKind)")
}
