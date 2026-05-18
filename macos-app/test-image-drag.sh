#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build/tests

swiftc \
    -o build/tests/image-drag-tests \
    Sources/RecentImagePickerWindowController.swift \
    Tests/ImageDragTests.swift \
    -framework Cocoa \
    -framework ImageIO \
    -framework UniformTypeIdentifiers

build/tests/image-drag-tests "$@"
