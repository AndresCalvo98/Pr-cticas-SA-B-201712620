#!/bin/bash
# Smoke test simple
curl -f http://localhost:80/health || exit 1
echo "Smoke test passed"
