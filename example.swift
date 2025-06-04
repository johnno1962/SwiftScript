#!/usr/bin/env swiftscript

import DLKit // .package(url: "https://github.com/johnno1962/DLKit", .upToNextMajor(from: "3.4.8"))
import Popen // .package(url: "https://github.com/johnno1962/Popen", .upToNextMajor(from: "2.1.7"))
import Foundation

print("Arguments:", ProcessInfo.processInfo.arguments)

#if !os(Linux)
for (i, m) in DLKit.imageMap
    where m.imageNumber < 10 {
    print("key:", i, "image:", m)
}
#endif

let ls = Popen(cmd: "ls -l")
while let line = ls?.readLine() {
   print("file:", line)
}

print("Hello Script!")
