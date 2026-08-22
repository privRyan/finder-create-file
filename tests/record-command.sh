#!/bin/bash
set -u

printf '%s %s\n' "$(basename "$0")" "$*" >> "${UNINSTALL_COMMAND_LOG:?}"
[[ "${FAIL_TOOL_NAME:-}" != "$(basename "$0")" ]]
