#!/usr/bin/env bash

set -euo pipefail

ROOT="$(dirname "$(dirname "${BASH_SOURCE:-$0}")")"

pushd "$ROOT/tool"

dart pub get >/dev/null

popd

exec dart "$ROOT/tool/bin/fmr.dart" $@
