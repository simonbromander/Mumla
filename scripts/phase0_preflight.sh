#!/usr/bin/env bash
set -euo pipefail

echo "Swift"
swift --version | head -n 1

echo
echo "FluidAudio"
gh repo view FluidInference/FluidAudio --json latestRelease,url --jq '"\(.url) latest=\(.latestRelease.tagName)"'

echo
echo "Hugging Face model pages"
curl -fsSI "https://huggingface.co/KlangAI/pianissimo-sv" >/dev/null
echo "OK KlangAI/pianissimo-sv"
curl -fsSI "https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3" >/dev/null
echo "OK nvidia/parakeet-tdt-0.6b-v3"
curl -fsSI "https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml" >/dev/null
echo "OK FluidInference/parakeet-tdt-0.6b-v3-coreml"

echo
echo "Harness tests"
swift test

