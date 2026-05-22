#!/bin/sh
# Xcode Cloud post-clone script
# Regenerates the Xcode project from project.yml.
# NOBS.xcodeproj is already committed so Xcode Cloud can find it even if this fails.

set -e

echo "--- Installing xcodegen ---"
brew install xcodegen

echo "--- Regenerating Xcode project ---"
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate || echo "xcodegen failed — using committed xcodeproj"

echo "--- Done ---"
