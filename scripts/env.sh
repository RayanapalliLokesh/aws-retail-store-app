#!/bin/bash
# scripts/env.sh - common settings, sourced by the other start scripts.
# JDK 21 and Go are unpacked under ~/.local/opt (no sudo on this VM).
export JAVA_HOME=$(ls -d "$HOME"/.local/opt/jdk-21* 2>/dev/null | head -1)
export PATH="$JAVA_HOME/bin:$HOME/.local/opt/go/bin:$PATH"
export REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# logs live outside the repo (and *.log is git-ignored anyway)
export LOG_DIR="$HOME/retail-logs"
mkdir -p "$LOG_DIR"
