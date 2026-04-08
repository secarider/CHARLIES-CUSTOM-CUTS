#!/usr/bin/env bash

# ==============================================================================
# CHARLIE.SH — "CHARLIE'S CUSTOM CUTS"
# Standalone Extraction From THE_FACTORY
# ==============================================================================
# PURPOSE:
# - One-Off Clip Cutting (Brutal + Accurate)
# - Join Two Clips Together
#
# DESIGN:
# - Fully Self-Contained (No factory.sh dependency)
# - House Style Colors + Commentary
# - Safe Output Naming
# - Clean Cancel Flow (q / 0)
# ==============================================================================

# =========================
# COLOR DEFINITIONS
# =========================
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLINK_RED='\033[5;1;31m'
NC='\033[0m'

# =========================
# HELPER: PAUSE
# =========================
pause() {
    echo
    echo -e "${YELLOW}Press Enter To Continue...${NC}"
    read -r
}

# =========================
# HELPER: YES / NO
# =========================
ask_yes_no() {
    local prompt="$1"
    echo -ne "${YELLOW}${prompt}${NC}"
    read -r ans
    ans="${ans,,}"
    [[ "$ans" == y* ]]
}

# =========================
# HELPER: EXIT TOKEN
# =========================
is_factory_exit_token() {
    [[ "$1" == "0" || "$1" == "q" ]]
}

# =========================
# HELPER: TIME CONVERSION
# =========================
to_seconds() {
    local input="$1"

    # normalize 2.20 -> 2:20
    input="${input//./:}"

    IFS=':' read -r h m s <<< "$input"

    if [[ -z "$m" ]]; then
        echo "$h"
    elif [[ -z "$s" ]]; then
        echo "$((h*60 + m))"
    else
        echo "$((h*3600 + m*60 + s))"
    fi
}

# =========================
# HELPER: PROGRESS
# =========================
run_with_progress() {
    local label="$1"
    shift

    echo -e "${CYAN} = = > ${label}${NC}" >&2

    "$@" &
    local pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        echo -ne "${YELLOW}....PLEASE-STAND-BY....${NC}\r" >&2
        sleep 2
    done

    wait "$pid"
    return $?
}

# =========================
# HELPER: SAFE OUTPUT NAME
# =========================
safe_name() {
    local base="$1"
    local ext="$2"
    local i=0
    local out

    while :; do
        [[ $i -eq 0 ]] && out="${base}.${ext}" || out="${base}_${i}.${ext}"
        [[ ! -f "$out" ]] && break
        ((i++))
    done

    echo "$out"
}

# =========================
# DEP CHECK
# =========================
check_deps() {
    command -v ffmpeg >/dev/null || { echo "ffmpeg missing"; exit 1; }
    command -v ffprobe >/dev/null || { echo "ffprobe missing"; exit 1; }
    command -v bc >/dev/null || { echo "bc missing"; exit 1; }
}

# ==============================================================================
# CUSTOM CUT
# ==============================================================================
run_custom_cut() {

    clear
    echo -e "${CYAN}================ CUSTOM CUT ================${NC}"

    shopt -s nullglob nocaseglob
    local files=(*.{mkv,mp4,avi,mov,ts})
    shopt -u nullglob nocaseglob

    local filtered=()
    for f in "${files[@]}"; do
        [[ "$f" =~ ^(REKEY_|SUTURED_|BARFIX_) ]] && continue
        filtered+=("$f")
    done

    [[ ${#filtered[@]} -eq 0 ]] && {
        echo -e "${RED}No valid files found${NC}"
        pause
        return
    }

    echo -e "${CYAN}Select File:${NC}"
    select src in "${filtered[@]}"; do
        [[ -n "$src" ]] && break
    done

    while true; do
        echo -e "${YELLOW}Start Time:${NC}"
        read -r start_raw
        echo -e "${YELLOW}End Time:${NC}"
        read -r end_raw

        start=$(to_seconds "$start_raw")
        end=$(to_seconds "$end_raw")

        (( end <= start )) && continue

        dur=$((end - start))

        echo -e "${CYAN}Duration: $dur seconds${NC}"

        ask_yes_no "Confirm? (y/n): " && break
    done

    out=$(safe_name "custom_cut" "mkv")

    mkdir -p _cut_tmp

    run_with_progress "Cutting..." \
    ffmpeg -y -i "$src" \
        -vf "trim=start=${start}:duration=${dur},setpts=PTS-STARTPTS" \
        -af "atrim=start=${start}:duration=${dur},asetpts=PTS-STARTPTS" \
        -c:v libx264 -crf 18 -preset veryfast \
        -c:a aac \
        "_cut_tmp/temp.mkv"

    mv "_cut_tmp/temp.mkv" "$out"
    rm -rf _cut_tmp

    echo -e "${GREEN}Created: $out${NC}"
    pause
}

# ==============================================================================
# JOIN TWO CLIPS
# ==============================================================================
run_join_two_clips() {

    clear
    echo -e "${CYAN}================ JOIN CLIPS ================${NC}"

    shopt -s nullglob nocaseglob
    local files=(*.{mkv,mp4,avi,mov,ts})
    shopt -u nullglob nocaseglob

    [[ ${#files[@]} -eq 0 ]] && {
        echo -e "${RED}No files found${NC}"
        pause
        return
    }

    echo -e "${CYAN}Select Part 1:${NC}"
    select p1 in "${files[@]}"; do [[ -n "$p1" ]] && break; done

    echo -e "${CYAN}Select Part 2:${NC}"
    select p2 in "${files[@]}"; do [[ -n "$p2" ]] && break; done

    out=$(safe_name "JOINED_${p1%.*}" "mkv")

    ask_yes_no "Proceed with join? (y/n): " || return

    mkdir -p _join_tmp

    printf "file '%s/%s'\n" "$(pwd)" "$p1" > _join_tmp/list.txt
    printf "file '%s/%s'\n" "$(pwd)" "$p2" >> _join_tmp/list.txt

    run_with_progress "Joining..." \
    ffmpeg -f concat -safe 0 -i _join_tmp/list.txt -c copy "$out" -y

    rm -rf _join_tmp

    echo -e "${GREEN}Created: $out${NC}"
    pause
}

# ==============================================================================
# MAIN MENU
# ==============================================================================
run_main_menu() {

    while true; do
        clear
        echo -e "${CYAN}=========== CHARLIE'S CUSTOM CUTS ==========${NC}"
        echo
        echo "1) Custom Cut"
        echo "2) Join Two Clips"
        echo "0) Exit"
        echo

        read -r choice

        case "$choice" in
            1) run_custom_cut ;;
            2) run_join_two_clips ;;
            0) exit 0 ;;
        esac
    done
}

# ==============================================================================
# START
# ==============================================================================
check_deps
run_main_menu
