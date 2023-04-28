#!/usr/bin/env bash

ROOT="$(dirname "$(dirname "${BASH_SOURCE:-$0}")")"

pushd "$ROOT/tool"

dart pub get >/dev/null

exec dart "$ROOT/tool/bin/fmr.dart" $@
