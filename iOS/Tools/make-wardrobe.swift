#!/usr/bin/env swift
// Run from the repository root. Only Foundation, CoreGraphics and ImageIO are used.
// Shared geometry, palette and raster primitives live in MascotArt.swift.
import Foundation
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
task.arguments = ["-module-cache-path", "/tmp/clockin-art-module-cache",
                  "iOS/Tools/MascotArt.swift", "wardrobe"]
try task.run()
task.waitUntilExit()
exit(task.terminationStatus)
