#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build/tests

swiftc \
    -o build/tests/model-catalog-tests \
    Sources/TranscriptionModels.swift \
    Sources/TranscriptionEngine.swift \
    Tests/ModelCatalogTests.swift \
    -framework AVFoundation \
    -framework Speech

build/tests/model-catalog-tests "$@"
