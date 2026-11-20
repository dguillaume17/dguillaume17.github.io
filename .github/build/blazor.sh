#!/usr/bin/env bash
# Blazor WebAssembly: tests (dotnet test -c Release of each test project of the current folder, i.e. those referencing
# Microsoft.NET.Test.Sdk; none: no tests), dotnet publish of the project (folder or .csproj) without precompressed
# files, with MSBuild properties BuildNumber and BuildBranch; site = wwwroot of the publication.
# --aot: AOT compilation (installs wasm-tools).
source "$(dirname "$0")/lib.sh"
vAot=false
vArgs=()
for fArg in "$@"; do
  if [ "$fArg" = --aot ]; then vAot=true; else vArgs+=("$fArg"); fi
done
parse_args "${vArgs[@]}"

vTests=""
while IFS= read -r fProject; do
  vTests+="${vTests:+ && }dotnet test '$fProject' -c Release"
done < <(grep -rl --include='*.csproj' --exclude-dir={bin,obj,node_modules,.git} 'Microsoft.NET.Test.Sdk' . 2>/dev/null | sort)
if [ -n "$vTests" ] || [ -n "$TEST_COMMAND" ]; then
  run_tests "$vTests"
else
  echo "== Tests : aucun projet de tests"
fi

vPublish=$(mktemp -d)
if [ -n "$BUILD_COMMAND" ]; then
  run_build ""
else
  vOptions=(-c Release -o "$vPublish" -p:CompressionEnabled=false "-p:BuildNumber=$BUILD_NUMBER" "-p:BuildBranch=$BUILD_BRANCH")
  if [ "$vAot" = true ]; then
    install_workload wasm-tools
    vOptions+=(-p:RunAOTCompilation=true)
  fi
  echo "== Build : dotnet publish $PROJECT ${vOptions[*]}"
  dotnet publish "$PROJECT" "${vOptions[@]}"
fi
copy_site "$vPublish/wwwroot"
