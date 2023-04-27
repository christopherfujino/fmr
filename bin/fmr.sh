#!/usr/bin/env bash

ROOT="$(dirname "$(dirname "${BASH_SOURCE:-$0}")")"

exec dart "$ROOT/tool/bin/fmr.dart" $@
