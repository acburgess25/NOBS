#!/bin/bash
# NOBS AI — runs Aider with local Ollama in the NOBS project
export OLLAMA_API_BASE=http://localhost:11434
cd "/Users/alexburgess/Library/Mobile Documents/com~apple~CloudDocs/NOBS"
aider \
  --model ollama/qwen2.5-coder:14b \
  --no-auto-commits \
  --watch-files \
  --no-show-model-warnings
