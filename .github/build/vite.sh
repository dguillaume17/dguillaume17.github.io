#!/usr/bin/env bash
# Vite (React, Vue, Svelte...): npm ci, tests (npm run test --if-present), build with relative paths
# (npm run build -- --base=./), site = dist.
source "$(dirname "$0")/lib.sh"
parse_args "$@"
cd "$(project_folder)"
npm ci
run_tests "npm run test --if-present"
run_build "npm run build -- --base=./"
copy_site dist
