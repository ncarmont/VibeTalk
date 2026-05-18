#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="VibeTalk"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

echo ""
echo "  Building ${APP_NAME}..."

# Create bundle structure (preserve existing to keep Accessibility trust)
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
cp Info.plist "${APP_BUNDLE}/Contents/"
cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"

# Clean stale codesign artifacts
rm -f "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}.cstemp"
rm -rf "${APP_BUNDLE}/Contents/_CodeSignature"

# Detect architecture
ARCH=$(uname -m)
TARGET="${ARCH}-apple-macos13.0"

# Bundle llama-cli for LLM formatting (downloaded once, cached in bundle)
LLAMA_VERSION="b9114"
LLAMA_RESOURCE_DIR="${APP_BUNDLE}/Contents/Resources/llama.cpp"
LLAMA_CLI="${LLAMA_RESOURCE_DIR}/llama-cli"

if [ ! -f "${LLAMA_CLI}" ]; then
    echo "  Bundling llama-cli ${LLAMA_VERSION} for ${ARCH}..."
    TARBALL_ARCH="arm64"
    [ "${ARCH}" = "x86_64" ] && TARBALL_ARCH="x64"
    TARBALL_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_VERSION}/llama-${LLAMA_VERSION}-bin-macos-${TARBALL_ARCH}.tar.gz"
    TMPDIR_DL=$(mktemp -d)
    if curl -sSfL "${TARBALL_URL}" -o "${TMPDIR_DL}/llama.tar.gz"; then
        tar -xzf "${TMPDIR_DL}/llama.tar.gz" -C "${TMPDIR_DL}"
        mkdir -p "${LLAMA_RESOURCE_DIR}"
        cp "${TMPDIR_DL}/llama-${LLAMA_VERSION}/llama-completion" "${LLAMA_RESOURCE_DIR}/"
        cp "${TMPDIR_DL}/llama-${LLAMA_VERSION}/llama-cli" "${LLAMA_RESOURCE_DIR}/" 2>/dev/null || true
        cp "${TMPDIR_DL}/llama-${LLAMA_VERSION}/"*.dylib "${LLAMA_RESOURCE_DIR}/" 2>/dev/null || true
        # Allow binaries to find dylibs in their own directory
        install_name_tool -add_rpath @loader_path "${LLAMA_RESOURCE_DIR}/llama-completion" 2>/dev/null || true
        install_name_tool -add_rpath @loader_path "${LLAMA_CLI}" 2>/dev/null || true
        chmod +x "${LLAMA_RESOURCE_DIR}/llama-completion" "${LLAMA_CLI}"
        echo "  llama-cli bundled."
    else
        echo "  Warning: Could not download llama-cli; will use Homebrew install at runtime."
    fi
    rm -rf "${TMPDIR_DL}"
fi

echo "  Compiling for ${ARCH}..."
swiftc \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/TranscriptionModels.swift \
    Sources/TranscriptCleanup.swift \
    Sources/TranscriptionEngine.swift \
    Sources/HotkeyManager.swift \
    Sources/TextInjector.swift \
    Sources/PillWindowController.swift \
    Sources/RecentImagePickerWindowController.swift \
    Sources/ModelSettingsWindowController.swift \
    Sources/MainWindowController.swift \
    Sources/OnboardingWindowController.swift \
    Sources/HistoryWindowController.swift \
    -framework Cocoa \
    -framework AVFoundation \
    -framework Speech \
    -framework QuartzCore \
    -framework ServiceManagement \
    -target "${TARGET}" \
    -O

# Sign with configured identity, defaulting to ad-hoc for local builds.
echo "  Signing with '${SIGN_IDENTITY}'..."
codesign --force --sign "${SIGN_IDENTITY}" \
    --entitlements Entitlements.plist \
    "${APP_BUNDLE}"

echo ""
echo "  Build complete: ${APP_BUNDLE}"
echo "  To run: open ${APP_BUNDLE}"
echo ""
