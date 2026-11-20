#!/usr/bin/env bash
# Avalonia (browser project, Microsoft.NET.Sdk.WebAssembly + Avalonia.Browser): installs wasm-tools, then as blazor.sh.
source "$(dirname "$0")/lib.sh"
install_workload wasm-tools
BUILD_SCRIPT_NAME=avalonia exec "$(dirname "$0")/blazor.sh" "$@"
