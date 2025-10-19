#!/bin/bash
# Script: check_apk_so_pagesize.sh
# Purpose: Inspect .so page alignment inside final APK
# --- Color Definitions ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

# Default values
WITH_BUILD=false
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
NDK_VERSION="28.2.13676358"

# Parse command line arguments
while [ $# -gt 0 ]; do
    case $1 in
        --apk-path)
            shift || { echo -e "${RED}Missing value for --apk-path${RESET}"; exit 1; }
            APK_PATH="$1"
            shift
            ;;
        --ndk-version)
            shift || { echo -e "${RED}Missing value for --ndk-version${RESET}"; exit 1; }
            NDK_VERSION="$1"
            shift
            ;;
        --build|-b)
            WITH_BUILD=true
            shift
            ;;
        --help|-h)
            echo -e "Usage: $0 [OPTIONS]"
            echo -e "Options:"
            echo -e "  --apk-path      provide custom apk path"
            echo -e "  --build, -b     will build the apk, using fvm flutter specific command"
            echo -e "  --ndk-version   provide your ndk version, where readelf command located"
            echo -e "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option:${RESET} $1"
            echo -e "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [ "$WITH_BUILD" = "true" ]; then
  fvm flutter build apk --release
fi

# Path to llvm-readelf (adjust if needed)
READELF="$HOME/Library/Android/sdk/ndk/$NDK_VERSION/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf"

if [ ! -x "$READELF" ]; then
  echo -e " ❌ ${RED}llvm-readelf not found at:${RESET} $READELF"
  exit 1
fi

if [ ! -f "$APK_PATH" ]; then
  echo -e " ❌ ${RED}APK not found at:${RESET} $APK_PATH"
  exit 1
fi

echo -e "🔍 Extracting .so files from $APK_PATH ..."
TMP_DIR=$(mktemp -d)
unzip -q "$APK_PATH" "lib/**/*.so" -d "$TMP_DIR"

COUNT=0
while read -r sofile; do
  alignments=$("$READELF" -l "$sofile" | grep 'LOAD' | awk '{print $NF}' | sort -u)

  for align in $alignments; do
    if [ "$align" = "0x1000" ]; then
      COUNT=$((COUNT+1))
      echo -e "${YELLOW}📂 $sofile${RESET}"
      echo -e "   → LOAD alignment: $align"
      echo -e "     ⚠️  Uses 4 KB pages (NOT compatible with Android 15+)"
    fi
  done
done < <(find "$TMP_DIR/lib" \( -path "*/arm64-v8a/*.so" -o -path "*/x86_64/*.so" \))

# Summary
if [ "$COUNT" -gt 0 ]; then
  echo -e "${RED}$COUNT .so files need to be fixed (arm64-v8a & x86_64 only)${RESET}"
  rm -rf "$TMP_DIR"
  exit 1  # <-- This makes it CI/CD-friendly
else
  echo -e "${GREEN}✅ All .so files are using 16KB or 64KB page alignment.${RESET}"
fi

# cleanup
rm -rf "$TMP_DIR"
