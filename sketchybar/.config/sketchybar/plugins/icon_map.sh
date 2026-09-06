#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/icon_map.generated.sh" ]]; then
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/icon_map.generated.sh"
fi

fallback_app_icon() {
  local app_name="$1"
  local trimmed_name first_char upper_char

  trimmed_name="${app_name#"${app_name%%[![:space:]]*}"}"
  first_char="${trimmed_name:0:1}"

  if [[ -z "$first_char" ]]; then
    echo ":default:"
    return
  fi

  upper_char="$(printf '%s\n' "$first_char" | tr '[:lower:]' '[:upper:]')"

  case "$upper_char" in
    A) echo "Ⓐ" ;;
    B) echo "Ⓑ" ;;
    C) echo "Ⓒ" ;;
    D) echo "Ⓓ" ;;
    E) echo "Ⓔ" ;;
    F) echo "Ⓕ" ;;
    G) echo "Ⓖ" ;;
    H) echo "Ⓗ" ;;
    I) echo "Ⓘ" ;;
    J) echo "Ⓙ" ;;
    K) echo "Ⓚ" ;;
    L) echo "Ⓛ" ;;
    M) echo "Ⓜ" ;;
    N) echo "Ⓝ" ;;
    O) echo "Ⓞ" ;;
    P) echo "Ⓟ" ;;
    Q) echo "Ⓠ" ;;
    R) echo "Ⓡ" ;;
    S) echo "Ⓢ" ;;
    T) echo "Ⓣ" ;;
    U) echo "Ⓤ" ;;
    V) echo "Ⓥ" ;;
    W) echo "Ⓦ" ;;
    X) echo "Ⓧ" ;;
    Y) echo "Ⓨ" ;;
    Z) echo "Ⓩ" ;;
    0) echo "⓪" ;;
    1) echo "①" ;;
    2) echo "②" ;;
    3) echo "③" ;;
    4) echo "④" ;;
    5) echo "⑤" ;;
    6) echo "⑥" ;;
    7) echo "⑦" ;;
    8) echo "⑧" ;;
    9) echo "⑨" ;;
    *) echo ":default:" ;;
  esac
}

app_icon() {
  case "$1" in
    "NTS Radio") echo "􀪔";;
    "TasksBoard") echo "􀃲";;
    *)
      if declare -F __icon_map >/dev/null 2>&1; then
        __icon_map "$1"
        if [[ -n "${icon_result:-}" && "$icon_result" != ":default:" ]]; then
          echo "$icon_result"
          return
        fi
      fi

      fallback_app_icon "$1"
      ;;
  esac
}
