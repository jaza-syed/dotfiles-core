#!/usr/bin/env bash

# Topology discovery and formatting helpers. Intended to be sourced.
# Output format:
#   aerospace_monitor|sketchybar_display|direct_display|appkit_screen|name|scale|geometry_group
#
# The raw Swift probe additionally emits display_kind as field 7:
#   builtin | external
# Geometry grouping is based on that display kind, not scale. This keeps the
# notch/offset workaround tied to the actual built-in display rather than to
# Retina/non-Retina status.

classify_topology() {
  awk -F'|' '
    NF {
      group = $7 == "builtin" ? "primary" : "offset"
      print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6 "|" group
    }
  '
}

fallback_topology() {
  local monitors
  local monitor

  monitors="$(aerospace_query list-monitors --format '%{monitor-id}' || true)"
  if [[ -z "$monitors" ]]; then
    monitors="1"
  fi

  for monitor in $monitors; do
    # If the expensive mapping is unavailable, keep the historical behavior:
    # target all displays from the primary bar geometry rather than guessing an
    # offset class.
    printf '%s|%s|0||unknown|2.0|builtin\n' "$monitor" "$monitor"
  done
}

discover_topology() {
  local raw

  raw="$(run_with_timeout "$SWIFT_TIMEOUT_SECONDS" swift "$LIB_DIR/topology.swift" 2>/dev/null || true)"
  if [[ -z "$raw" ]]; then
    raw="$(fallback_topology)"
  fi

  printf '%s\n' "$raw" | classify_topology
}

discover_workspaces() {
  local workspaces

  workspaces="$(aerospace_query list-workspaces --all --format '%{workspace}' || true)"
  if [[ -n "$workspaces" ]]; then
    printf '%s\n' "$workspaces"
  else
    default_workspaces_string
  fi
}

topology_filter_group() {
  local topology="$1"
  local group="$2"

  printf '%s\n' "$topology" | awk -F'|' -v group="$group" 'NF && $7 == group { print }'
}

topology_monitor_ids() {
  local topology="$1"

  printf '%s\n' "$topology" | awk -F'|' 'NF { print $1 }'
}

topology_display_list() {
  local topology="$1"

  printf '%s\n' "$topology" | awk -F'|' '
    NF && $2 != "" {
      displays = displays ? displays "," $2 : $2
    }
    END { if (displays != "") print displays }
  '
}

topology_count() {
  local topology="$1"

  printf '%s\n' "$topology" | awk 'NF { count++ } END { print count + 0 }'
}

topology_display_for_monitor() {
  local topology="$1"
  local monitor="$2"

  printf '%s\n' "$topology" | awk -F'|' -v monitor="$monitor" '$1 == monitor { print $2; exit }'
}
