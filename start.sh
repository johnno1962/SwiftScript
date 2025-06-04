#!/bin/sh -x

cd `dirname $0`
echo "Installing swiftscript Swift package interpretor" >/dev/null
swift Sources/swiftscript/main.swift Sources/swiftscript/main.swift "$@"

echo "Now try the command: swiftscript example.swift" >/dev/null
