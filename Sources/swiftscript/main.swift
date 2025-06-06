// The Swift Programming Language
// https://docs.swift.org/swift-book
/*
 MIT License

 Copyright (c) 2025 John Holdsworth

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
*/

import Foundation

debug("Parsing:", ProcessInfo.processInfo.arguments)

var cwdBuffer = [CChar](repeating: 0, count: Int(PATH_MAX))
getcwd(&cwdBuffer, cwdBuffer.count)
let cwdURL = URL(fileURLWithPath: String(cString: cwdBuffer))
let FileMngr = FileManager.default

var arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())
if let tail = arguments.firstIndex(of: "--") {
    arguments.removeFirst(tail+1)
}
if arguments.isEmpty {
    print("swiftscript <script> # flexible and performant Swift interpreter.")
    exit(EXIT_FAILURE)
}

let script = arguments[0]
let scriptURL = (script.hasPrefix("https:") ? URL(string: script) : nil) ??
                URL(fileURLWithPath: script, relativeTo: cwdURL)
var scriptName = scriptURL.deletingPathExtension().lastPathComponent
if scriptName == "main" {
    scriptName = scriptURL.deletingLastPathComponent().lastPathComponent
}
scriptName = scriptName.lowercased()

let scriptUpdated = 0
let scriptRunner = "swiftscript"
let scriptIsSelf = scriptName == scriptRunner
let scriptConfig = (scriptIsSelf ? nil : getenv("SCRIPT_CONFIG")
                    .flatMap { String(cString: $0) }) ?? "debug"
let scriptRoot = NSHomeDirectory()+"/Library/SwiftScript/"+scriptName
let scriptExec = scriptRoot+"/.build/\(scriptConfig)/"+scriptName
let scriptHome = scriptRoot+"/Sources/"+scriptName
let scriptMain = scriptHome+"/main.swift"

debug("Arguments:", arguments, scriptURL, scriptMain)

// Should we regenerate Swift Package for script?
if !scriptURL.isFileURL {
    shell(command: "git clone '\(scriptURL.absoluteString)' '\(scriptRoot)'" +
          " || cd '\(scriptRoot)' && git pull")
} else if modified(scriptURL.path) > modified(scriptMain) ||
    scriptUpdated > modified(scriptMain) {
    try installScriptIntoSwiftPackage()
}

// Editing script once installed
if (!scriptIsSelf || arguments.count == 2) && arguments.last == "--edit" {
    #if os(Linux)
    let edit = scriptMain
    #else
    let edit = scriptRoot+"/Package.swift"
    #endif
    shell(command: "open '\(edit)'")
    exit(EXIT_SUCCESS)
}

// Rebuild Swift Package if necessary
debug("Building?", scriptMain, modified(scriptMain), scriptExec, modified(scriptExec))

if modified(scriptMain) > modified(scriptExec) || !scriptURL.isFileURL {
    shell(command: "cd '\(scriptRoot)' && time swift build -c \(scriptConfig)")
}

// Install to script binary directory
let scriptDir = getenv("SCRIPT_BINDIR").flatMap {
    String(cString: $0)+"/" } ?? "/usr/local/bin/"
if !FileMngr.fileExists(atPath: scriptDir+scriptName) {
    if !FileMngr.fileExists(atPath: scriptDir) {
        sudo(command: "mkdir -p '\(scriptDir)'")
    }
    let scriptDest = scriptURL.isFileURL ? scriptDir+scriptName : scriptExec
    sudo(command: "ln -s '\(scriptDest)' '\(scriptDir+scriptName)'")
    print("ℹ️ New swiftscript installed as "+scriptDir+scriptName)
}

replaceProcessWithUpdatedExecutable()

func debug(_ what: Any..., prefix: String = "🐞", separator: String = " ") {
    if getenv("SCRIPT_DEBUG") != nil {
        print(prefix + what.map {"\($0)"}.joined(separator: separator))
    }
}

func modified(_ path: String) -> time_t {
    var info = stat()
    guard stat(path, &info) == EXIT_SUCCESS else {
        return 0
    }
    #if os(Linux)
    return info.st_mtim.tv_sec
    #else
    return info.st_mtimespec.tv_sec
    #endif
}

func installScriptIntoSwiftPackage() throws {
    print("Updating:", scriptMain)
    let enc: String.Encoding = .utf8
    var source = try String(contentsOf: scriptURL, encoding: enc)
    if !source.hasPrefix("#!") {
        source = "#!/usr/bin/env \(scriptIsSelf ? scriptExec : scriptRunner)\n\n"+source
    }
    // Patch time last updated into script.
    source = source.replacingOccurrences(of: #"let scriptUpdated = \d+"#,
                                         with: "let scriptUpdated = \(time(nil))",
                                         options: .regularExpression)
    try FileMngr.createDirectory(
        atPath: scriptHome, withIntermediateDirectories: true)
    try source.write(toFile: scriptMain, atomically: true, encoding: enc)
    chmod(scriptMain, 0o755)
    try createPackageManifest(from: source)
}

func createPackageManifest(from source: String) throws {
    // Extract dependencies and patch them into the Swift Package manifest.
    let extractor = try NSRegularExpression(pattern: #"(?<=//)\s*(\.package\(.+?(\w+").*)"#)
    var packages = "", depends = "", range = NSMakeRange(0, source.utf16.count)
    for match in extractor.matches(in: source, range: range) {
        if let package = Range(match.range(at: 1), in: source) {
            packages += "        \(source[package]),\n"
            if let depend = Range(match.range(at: 2), in: source) {
                depends += "\"\(source[depend]), "
            }
        }
    }

    let manifest = """
            // swift-tools-version:5.2
            // The swift-tools-version declares the minimum version of Swift required to build this package.

            import PackageDescription

            let package = Package(
                name: "\(scriptName)",
                platforms: [.macOS(.v10_13)],
                products: [
                    // Products define the executables and libraries a package produces, making them visible to other packages.
                    .executable(
                        name: "\(scriptName)",
                        targets: ["\(scriptName)"]),
                ],
                dependencies: [
            /*PACKAGES*/    ],
                targets: [
                    // Targets are the basic building blocks of a package, defining a module or a test suite.
                    // Targets can depend on other targets in this package and products from dependencies.
                    .target(
                        name: "\(scriptName)",
                        dependencies: [/*DEPENDS*/]),
                ]
            )
            """
        .replacingOccurrences(of: "/*PACKAGES*/", with: packages)
        .replacingOccurrences(of: "/*DEPENDS*/", with: depends)

    try manifest.write(toFile: scriptRoot+"/Package.swift", atomically: true, encoding: .utf8)
}

@_silgen_name("system")
public func system(_: UnsafePointer<CChar>) -> CInt

func shell(command: String) {
    print("Executing:", command)
    guard system(command) == EXIT_SUCCESS else {
        fatalError(command+": failed")
    }
}

func sudo(command: String) {
    shell(command: "(\(command) 2>/dev/null) || (sudo \(command))")
}

func replaceProcessWithUpdatedExecutable() {
    // Chain process to executable created by building associated Swift package.
    execv(scriptExec, arguments.map { $0.withCString({ strdup($0) }) } + [nil])
    fatalError("execv \(scriptExec) returned \(String(cString: strerror(errno)))")
}
