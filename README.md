# #!/usr/bin/env swiftscript

### Swift scripting made easy and performant.

SwiftScript is a short script, itself coded in Swift which, by more closely
following UNIX conventions makes scripting in Swift faster and simpler. It's
faster as the "script" is run native and only built when its source file has
been edited rather than running up the compiler each time to run your script.

To get started run the `start.sh` script and the `swiftscript` binary will 
be installed to `/usr/local/bin` which is assumed to be on your `PATH`.
You can specify another directory on your `PATH` to install Swift scripts 
using the `SCRIPT_BINDIR` environment variable.

```Shell
$ ./start.sh
```
SwiftScript is simpler in that you can create a .swift file you want to be 
a script and import external dependencies by specifying their Swift package 
in a comment at the end of the line. 

```Swift
#!/usr/bin/env swiftscript

import DLKit // .package(url: "https://github.com/johnno1962/DLKit", .upToNextMajor(from: "3.4.8"))
import Popen // .package(url: "https://github.com/johnno1962/Popen", .upToNextMajor(from: "2.1.7"))
import Foundation

print("Args:", ProcessInfo.processInfo.arguments)

for (i, m) in DLKit.imageMap
    where m.imageNumber < 10 {
    print("key:", i, "image:", m)
}

let ls = Popen(cmd: "ls")
while let line = ls?.readLine() {
   print("file:", line)
}

print("Hello Script!")
```
You then install the script file using the `swiftscript` binary and it will be 
installed into a Swift Package created at `~/Library/SwiftScript/[name]`. A 
script is also created in `$SCRIPT_BINDIR/[name]` that uses the `swiftscript` 
binary as an interpreter. This checks to see if the package needs to be rebuilt 
then passes control to the up-to-date executable associated with the script.

```Shell
$ swiftscript example.swift
```
Once you have installed a script it can be edited by running it with 
`--edit` as the last argument and this will open the source file using
Xcode inside its containing Swift Package so debugging and completion on 
symbols in package dependencies is fully functional. Once installed, 
a script recompiles automatically once after it has been edited.

Set an environment variable `export SCRIPT_CONFIG=release` when you 
would like your script to be run using a release build.

Alternatives: [mxcl/swift-sh](https://github.com/mxcl/swift-sh) (2019),
[JohnSundell/Marathon](https://github.com/JohnSundell/Marathon) (2017)
or the pre-SPM [johnno1962/diamond](https://github.com/johnno1962/diamond) (2015).

That's all folks.
