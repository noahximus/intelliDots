#!/usr/bin/env bash

# Shared hardware probes. Sourced by the root install.sh (to decide whether
# to add TG Pro to the merged Brewfile) and by macos-defaults.sh (to decide
# whether to write TG Pro's preferences), so the two cannot disagree about
# what machine they are on.

# Fanless Macs -- every Apple Silicon MacBook Air, and the 12-inch MacBook --
# have nothing for TG Pro to report on or control.
#
# Model Name is used rather than the model identifier because Apple's
# identifiers stopped encoding the family in 2022: "Mac14,2" is an M2 Air and
# "Mac15,12" an M3 Air, so a substring match on "MacBookAir" silently reports
# every recent Air as fanned. The marketing name stayed stable.
#
# ioreg is not an option either: on Apple Silicon, fan data moved behind
# IOHIDEventSystemClient, so `ioreg -c AppleSMC` and `ioreg -l | grep -i fan`
# both return nothing even on a Mac with fans. powermetrics can see them but
# needs sudo, which an installer should not ask for.
machine_has_fans() {
  local model
  model="$(system_profiler SPHardwareDataType 2>/dev/null |
    awk -F': ' '/Model Name/ { print $2; exit }')"
  case "${model}" in
    "MacBook Air" | "MacBook") return 1 ;;
    *) return 0 ;;
  esac
}
