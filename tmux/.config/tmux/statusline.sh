#!/usr/bin/env bash

export LC_ALL=en_US.UTF-8

get_tmux_option() {
    local option=$1
    local default_value=$2
    local target=$3
    local option_value

    if [ -n "$target" ]; then
        option_value=$(tmux show-option -qv -t "$target" "$option")
    fi

    if [ -z "$option_value" ]; then
        option_value=$(tmux show-option -gqv "$option")
    fi

    if [ -z "$option_value" ]; then
        printf '%s' "$default_value"
    else
        printf '%s' "$option_value"
    fi
}

normalize_padding() {
    local value=$1
    local max_len=${2:-4}
    local value_len=${#value}
    local diff_len=$((max_len - value_len))
    local left_spaces=$(((diff_len + 1) / 2))
    local right_spaces=$((diff_len / 2))
    printf "%${left_spaces}s%s%${right_spaces}s" "" "$value" ""
}

session_segment() {
    local icon
    icon=$(get_tmux_option "@statusline-session-icon" "")
    printf '%s' "$icon"
}

cpu_segment() {
    local icon percent cpuvalue cpucores cpuusage
    icon=$(get_tmux_option "@statusline-cpu-icon" "")
    case "$(uname -s)" in
        Darwin)
            cpuvalue=$(ps -A -o %cpu | awk -F. '{s+=$1} END {print s}')
            cpucores=$(sysctl -n hw.logicalcpu 2>/dev/null)
            [ -z "$cpucores" ] && return
            cpuusage=$((cpuvalue / cpucores))
            percent=$(normalize_padding "${cpuusage}%")
            ;;
        Linux)
            percent=$(LC_NUMERIC=en_US.UTF-8 top -bn2 -d 0.01 | grep "Cpu(s)" | tail -1 | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{printf "%d%%", 100 - $1}')
            percent=$(normalize_padding "$percent")
            ;;
        *)
            return
            ;;
    esac
    printf '%s %s' "$icon" "$percent"
}

ram_segment() {
    local icon percent used_mem total_mem ram_metric
    icon=$(get_tmux_option "@statusline-ram-icon" "")
    case "$(uname -s)" in
        Darwin)
            ram_metric=$(get_tmux_option "@statusline-ram-metric" "activity")
            case "$ram_metric" in
                pressure)
                    # memory_pressure's free percentage is pressure/headroom, not the
                    # same thing as Activity Monitor's Memory Used. Invert it here so
                    # this segment still reads as a "used" percentage.
                    percent=$(memory_pressure 2>/dev/null | awk -F': ' '
                        /System-wide memory free percentage/ {
                            gsub(/%/, "", $2)
                            printf "%d", 100 - $2
                            exit
                        }')
                    ;;
                activity|*)
                    # Approximate Activity Monitor's Memory Used: App Memory
                    # (anonymous) + Wired Memory + Compressed Memory. This excludes
                    # file cache/speculative pages that macOS can reclaim quickly.
                    total_mem=$(sysctl -n hw.memsize)
                    percent=$(vm_stat | awk -v total="$total_mem" '
                        /page size of/ { ps = $8 }
                        /Pages wired down/              { w = $4 }
                        /Pages occupied by compressor/  { c = $5 }
                        /Anonymous pages/               { a = $3 }
                        END {
                            gsub(/\./, "", w); gsub(/\./, "", c); gsub(/\./, "", a)
                            if (total > 0) printf "%d", (w + c + a) * ps * 100 / total
                        }')
                    ;;
            esac
            ;;
        Linux)
            total_mem=$(LC_ALL=C free -m | awk '/^Mem/ {print $2}')
            used_mem=$(LC_ALL=C free -m | awk '/^Mem/ {print $3}')
            [ -z "$used_mem" ] || [ -z "$total_mem" ] && return
            percent=$(((used_mem * 100) / total_mem))
            ;;
        *)
            return
            ;;
    esac
    [ -z "$percent" ] && return
    printf '%s %s' "$icon" "$(normalize_padding "${percent}%")"
}

battery_segment() {
    local charging_icon missing_icon p0 p1 p2 p3 p4
    local status percent label on_ac
    charging_icon=$(get_tmux_option "@statusline-battery-charging-icon" "")
    missing_icon=$(get_tmux_option "@statusline-battery-missing-icon" "󱉝")
    p0=$(get_tmux_option "@statusline-battery-percentage-0" "")
    p1=$(get_tmux_option "@statusline-battery-percentage-1" "")
    p2=$(get_tmux_option "@statusline-battery-percentage-2" "")
    p3=$(get_tmux_option "@statusline-battery-percentage-3" "")
    p4=$(get_tmux_option "@statusline-battery-percentage-4" "")

    on_ac=false
    case "$(uname -s)" in
        Darwin)
            local pmset_output
            pmset_output=$(pmset -g batt)
            percent=$(printf '%s\n' "$pmset_output" | grep -Eo '[0-9]?[0-9]?[0-9]%' | head -n 1 | sed 's/%//g')
            status=$(printf '%s\n' "$pmset_output" | sed -n 2p | cut -d ';' -f 2 | tr -d ' ')
            if printf '%s\n' "$pmset_output" | grep -Eq "Now drawing from 'AC Power'|AC attached"; then
                on_ac=true
            fi
            ;;
        Linux)
            if command -v acpi >/dev/null 2>&1; then
                percent=$(acpi | cut -d: -f2- | cut -d, -f2 | tr -d '% ')
                status=$(acpi | cut -d: -f2- | cut -d, -f1 | tr -d ' ')
            else
                local bat
                bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
                [ -z "$bat" ] && return
                percent=$(cat "$bat/capacity" 2>/dev/null)
                status=$(cat "$bat/status" 2>/dev/null)
            fi
            ;;
        *)
            return
            ;;
    esac

    [ -z "$percent" ] && return

    if [ "$percent" -gt 90 ]; then
        label=$p4
    elif [ "$percent" -gt 75 ]; then
        label=$p3
    elif [ "$percent" -gt 50 ]; then
        label=$p2
    elif [ "$percent" -gt 25 ]; then
        label=$p1
    elif [ "$percent" -gt 10 ]; then
        label=$p0
    else
        label=$missing_icon
    fi

    if [ "$on_ac" = "true" ] || [ "$status" = "charging" ] || [ "$status" = "Charging" ]; then
        printf '%s %s%%' "$charging_icon" "$percent"
    else
        printf '%s %s%%' "$label" "$percent"
    fi
}

network_segment() {
    local wifi_icon ethernet_icon offline_icon network device_name ssid
    wifi_icon=$(get_tmux_option "@statusline-network-wifi-icon" "")
    ethernet_icon=$(get_tmux_option "@statusline-network-ethernet-icon" "󰈀")
    offline_icon=$(get_tmux_option "@statusline-network-offline-icon" "󰌙")
    network="$offline_icon Offline"

    for host in google.com github.com example.com; do
        if ping -q -c 1 -W 1 "$host" >/dev/null 2>&1; then
            case "$(uname -s)" in
                Darwin)
                    device_name=$(networksetup -listallhardwareports | grep -A 1 Wi-Fi | grep Device | awk '{print $2}')
                    ssid=$(networksetup -listpreferredwirelessnetworks "$device_name" 2>/dev/null | sed -n '2s/^\t//p')
                    ;;
                Linux)
                    if command -v iwgetid >/dev/null 2>&1; then
                        ssid=$(iwgetid -r)
                    fi
                    ;;
            esac
            if [ -n "$ssid" ]; then
                network="$wifi_icon $ssid"
            else
                network="$ethernet_icon Eth"
            fi
            break
        fi
    done

    printf '%s' "$network"
}

time_segment() {
    local icon format
    icon=$(get_tmux_option "@statusline-time-icon" "")
    format=$(get_tmux_option "@statusline-time-format" "%a %I:%M %p")
    date +"$icon $format"
}

apply_statusline() {
    local session=$1
    local left_sep right_sep win_left_sep win_right_sep
    local bg_main fg_main
    local prefix_bg prefix_fg session_bg session_fg visual_bg visual_fg cpu_bg cpu_fg ram_bg ram_fg battery_bg battery_fg
    local active_bg active_fg inactive_bg inactive_fg zoom_flag zoom_icon
    local session_icon session_style session_sep_style
    local status_left status_right prev_bg

    apply_window_option() {
        local option=$1
        local value=$2

        tmux list-windows -t "$session" -F '#{window_id}' | while IFS= read -r window_id; do
            [ -n "$window_id" ] || continue
            tmux set-window-option -q -t "$window_id" "$option" "$value"
        done
    }

    left_sep=$(get_tmux_option "@statusline-left-sep" "" "$session")
    right_sep=$(get_tmux_option "@statusline-right-sep" "" "$session")
    win_left_sep=$(get_tmux_option "@statusline-window-left-sep" "" "$session")
    win_right_sep=$(get_tmux_option "@statusline-window-right-sep" "" "$session")
    bg_main=$(get_tmux_option "@statusline-bg-main" "#171717" "$session")
    fg_main=$(get_tmux_option "@statusline-fg-main" "#d8d8d8" "$session")
    session_icon=$(get_tmux_option "@statusline-session-icon" "" "$session")
    prefix_bg=$(get_tmux_option "@statusline-prefix-bg" "#de6e7c" "$session")
    prefix_fg=$(get_tmux_option "@statusline-prefix-fg" "$bg_main" "$session")
    session_bg=$(get_tmux_option "@statusline-session-bg" "#819b69" "$session")
    session_fg=$(get_tmux_option "@statusline-session-fg" "#171717" "$session")
    cpu_bg=$(get_tmux_option "@statusline-cpu-bg" "#819b69" "$session")
    cpu_fg=$(get_tmux_option "@statusline-cpu-fg" "#171717" "$session")
    ram_bg=$(get_tmux_option "@statusline-ram-bg" "#b77e64" "$session")
    ram_fg=$(get_tmux_option "@statusline-ram-fg" "#171717" "$session")
    visual_bg=$(get_tmux_option "@statusline-visual-bg" "$ram_bg" "$session")
    visual_fg=$(get_tmux_option "@statusline-visual-fg" "$ram_fg" "$session")
    battery_bg=$(get_tmux_option "@statusline-battery-bg" "#b279a7" "$session")
    battery_fg=$(get_tmux_option "@statusline-battery-fg" "#171717" "$session")
    active_bg=$(get_tmux_option "@statusline-window-active-bg" "#6099c0" "$session")
    active_fg=$(get_tmux_option "@statusline-window-active-fg" "#171717" "$session")
    inactive_bg=$(get_tmux_option "@statusline-window-inactive-bg" "#252525" "$session")
    inactive_fg=$(get_tmux_option "@statusline-window-inactive-fg" "$fg_main" "$session")
    zoom_icon=$(get_tmux_option "@statusline-window-zoom-icon" "" "$session")
    zoom_flag="#{?window_zoomed_flag, ${zoom_icon},}"
    session_style="#{?client_prefix,#[fg=${prefix_fg}#,bg=${prefix_bg}],#{?#{==:#{pane_mode},copy-mode},#[fg=${visual_fg}#,bg=${visual_bg}],#[fg=${session_fg}#,bg=${session_bg}]}}"
    session_sep_style="#{?client_prefix,#[fg=${prefix_bg}#,bg=${bg_main}],#{?#{==:#{pane_mode},copy-mode},#[fg=${visual_bg}#,bg=${bg_main}],#[fg=${session_bg}#,bg=${bg_main}]}}"

    move_hint="#{?#{==:#{client_key_table},move},#[fg=${prefix_fg}#,bg=${prefix_bg}] #{@move-hint} #[fg=${prefix_bg}#,bg=${bg_main}]${left_sep} ,}"
    resize_hint="#{?#{==:#{client_key_table},resize},#[fg=${prefix_fg}#,bg=${prefix_bg}] #{@resize-hint} #[fg=${prefix_bg}#,bg=${bg_main}]${left_sep} ,}"
    status_left="${session_style} ${session_icon} #S ${session_sep_style}${left_sep} ${move_hint}${resize_hint}"

    prev_bg="$bg_main"
    status_right=""

    append_right_segment() {
        local seg_bg=$1
        local seg_fg=$2
        local command=$3
        status_right="${status_right}#[fg=${seg_bg},bg=${prev_bg}]${right_sep}#[fg=${seg_fg},bg=${seg_bg}] ${command} "
        prev_bg="$seg_bg"
    }

    append_right_segment "$cpu_bg" "$cpu_fg" "#($0 cpu)"
    append_right_segment "$ram_bg" "$ram_fg" "#($0 ram)"
    append_right_segment "$battery_bg" "$battery_fg" "#($0 battery)"

    tmux set-option -q -t "$session" status-left-length 140
    tmux set-option -q -t "$session" status-right-length 72
    tmux set-option -q -t "$session" status-style "bg=${bg_main},fg=${fg_main}"
    tmux set-option -q -t "$session" message-style "bg=${cpu_bg},fg=${cpu_fg}"
    tmux set-option -q -t "$session" status-left "$status_left"
    tmux set-option -q -t "$session" status-right "$status_right"

    apply_window_option window-status-current-style "none"
    apply_window_option window-status-last-style "none"
    apply_window_option window-status-style "none"
    apply_window_option window-status-current-format "#[fg=${active_bg},bg=${bg_main}]${win_left_sep}#[fg=${active_fg},bg=${active_bg}] #I:#W${zoom_flag} #[fg=${active_bg},bg=${bg_main}]${win_right_sep}"
    apply_window_option window-status-format "#[fg=${inactive_bg},bg=${bg_main}]${win_left_sep}#[fg=${inactive_fg},bg=${inactive_bg}] #I:#W${zoom_flag} #[fg=${inactive_bg},bg=${bg_main}]${win_right_sep}"
}

case "$1" in
    apply)
        apply_statusline "${2:-$(tmux display-message -p '#{session_name}')}"
        ;;
    session)
        session_segment
        ;;
    cpu)
        cpu_segment
        ;;
    ram)
        ram_segment
        ;;
    battery)
        battery_segment
        ;;
    network)
        network_segment
        ;;
    time)
        time_segment
        ;;
    *)
        exit 1
        ;;
esac
