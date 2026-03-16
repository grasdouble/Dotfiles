# prompt_for_multiselect — Enhanced interactive checkbox menu
#
# Usage:
#   prompt_for_multiselect <result_var> <options_str> <defaults_str> <colors_str> <hints_str> <sections_str> <installed_str>
#
# Arguments (all semicolon-separated):
#   result_var    — name of the array variable to store results (true/false per option)
#   options_str   — option labels          e.g. "Brew;Git;Zsh"
#   defaults_str  — pre-checked flags      e.g. "true;true;false"
#   colors_str    — ANSI color per option  e.g. "\033[0;36m;\033[0;36m;\033[0;33m"
#   hints_str     — hint text per option   e.g. "~1 min;~1 min;~3 min"
#   sections_str  — section header per option index (format: "idx:Title")
#                   e.g. "0:Core;4:Software"
#   installed_str — pre-detected installed flags e.g. "true;false;false"

# ── Top-level helpers (testable without TTY) ─────────────────────────────────

# toggle_option <arr_name> <index>
# Toggles the boolean value at index in the named array.
toggle_option() {
    local arr_name=$1
    eval "local arr=(\"\${${arr_name}[@]}\")"
    local option=$2
    if [[ ${arr[option]} == true ]]; then
        arr[option]=
    else
        arr[option]=true
    fi
    eval "$arr_name"='("${arr[@]}")'
}

# count_selected <arr_name>
# Prints the number of elements equal to 'true' in the named array.
count_selected() {
    local arr_name=$1
    eval "local arr=(\"\${${arr_name}[@]}\")"
    local count=0
    for v in "${arr[@]}"; do [[ $v == true ]] && ((count++)); done
    echo "$count"
}

function prompt_for_multiselect {

    # ── Terminal helpers ─────────────────────────────────────────────────────
    local ESC
    ESC=$(printf "\033")
    cursor_blink_on()   { printf "%s[?25h" "$ESC"; }
    cursor_blink_off()  { printf "%s[?25l" "$ESC"; }
    cursor_to()         { printf "%s[%s;%sH" "$ESC" "$1" "${2:-1}"; }
    get_cursor_row()    { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo "${ROW#*[}"; }

    # ── Colors ───────────────────────────────────────────────────────────────
    local C_RESET=$'\033[0m'
    local C_BOLD=$'\033[1m'
    local C_DIM=$'\033[2m'
    local C_INVERT=$'\033[7m'
    local C_GREEN=$'\033[0;32m'
    local C_CYAN=$'\033[0;36m'
    local C_YELLOW=$'\033[1;33m'
    local C_WHITE=$'\033[1;37m'
    local C_DARK=$'\033[0;90m'

    # ── Key input ────────────────────────────────────────────────────────────
    key_input() {
        local key
        IFS= read -rsn1 key 2>/dev/null >&2
        if   [[ $key == ""      ]]; then echo enter
        elif [[ $key == $'\x20' ]]; then echo space
        elif [[ $key == "a"     ]]; then echo select_all
        elif [[ $key == "n"     ]]; then echo deselect_all
        elif [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            if [[ $key == "[A" ]]; then echo up;   fi
            if [[ $key == "[B" ]]; then echo down; fi
        fi
    }

    # ── Parse arguments ──────────────────────────────────────────────────────
    local retval=$1
    local options colors hints installed_flags
    local -a sections_map

    IFS=';' read -r -a options        <<< "$2"
    IFS=';' read -r -a raw_defaults   <<< "$3"
    IFS='|' read -r -a colors         <<< "$4"
    IFS=';' read -r -a hints          <<< "$5"
    # sections: "0:Core;4:Software" → associative-style
    local sections_str="$6"
    IFS=';' read -r -a raw_installed  <<< "$7"

    # Build section lookup — bash 3.x compatible (no declare -A)
    # section_at_idx[k] = option index, section_at_title[k] = header label
    local -a section_at_idx=()
    local -a section_at_title=()
    if [[ -n "$sections_str" ]]; then
        IFS=';' read -r -a sec_pairs <<< "$sections_str"
        for pair in "${sec_pairs[@]}"; do
            section_at_idx+=("${pair%%:*}")
            section_at_title+=("${pair##*:}")
        done
    fi

    # Helper: get section title for a given option index (empty string if none)
    _section_for() {
        local idx=$1
        for ((k=0; k<${#section_at_idx[@]}; k++)); do
            [[ "${section_at_idx[k]}" == "$idx" ]] && echo "${section_at_title[k]}" && return
        done
    }

    local n=${#options[@]}

    # Build selected and installed arrays
    # Use :-  to handle sparse arrays when trailing empty fields are stripped by read
    local -a selected installed
    for ((i=0; i<n; i++)); do
        selected+=("${raw_defaults[i]:-}")
        installed+=("${raw_installed[i]:-}")
    done

    # ── Count lines needed (options + section headers) ───────────────────────
    local header_count=0
    for ((i=0; i<n; i++)); do
        [[ -n "$(_section_for $i)" ]] && ((header_count++))
    done
    local total_lines=$((n + header_count + 2)) # +2 for counter line + help line

    # Print blank lines to reserve space
    for ((i=0; i<total_lines; i++)); do printf "\n"; done

    local lastrow
    lastrow=$(get_cursor_row)
    local startrow=$(( lastrow - total_lines + 1 ))

    # ── Cleanup on Ctrl+C ─────────────────────────────────────────────────────
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    # ── Render function ───────────────────────────────────────────────────────
    render_menu() {
        local active=$1
        local row=$startrow
        local visual_idx=0  # index into options (skips headers)

        # Counter line
        cursor_to $row
        local sel_count
        sel_count=$(count_selected selected)
        printf "${C_DIM}  %s/%s selected   [a] all  [n] none  [↑↓] move  [space] toggle  [enter] confirm${C_RESET}  " \
               "$sel_count" "$n"
        ((row++))

        # Blank separator
        cursor_to $row
        printf "%-80s" ""
        ((row++))

        for ((i=0; i<n; i++)); do
            # Section header?
            local sec_title
            sec_title="$(_section_for $i)"
            if [[ -n "$sec_title" ]]; then
                cursor_to $row
                printf "${C_DARK}  ── %s ──%-50s${C_RESET}" "$sec_title" ""
                ((row++))
            fi

            cursor_to $row

            # 3-state checkbox:
            #   [✓]  selected (will be installed)
            #   [–]  already installed, not selected (will be skipped)
            #   [ ]  not installed, not selected
            local checkbox
            if [[ ${selected[i]} == true ]]; then
                checkbox="${C_GREEN}[✓]${C_RESET}"
            elif [[ ${installed[i]} == true ]]; then
                checkbox="${C_CYAN}[–]${C_RESET}"
            else
                checkbox="${C_DIM}[ ]${C_RESET}"
            fi

            # Installed hint (dimmed, no redundant tag when checkbox already shows it)
            local installed_tag=""
            [[ ${installed[i]} == true ]] && installed_tag=" ${C_DIM}(installed)${C_RESET}"

            # Option color — dim if already installed and not selected
            local opt_color="${colors[i]:-$C_WHITE}"
            [[ ${installed[i]} == true && ${selected[i]} != true ]] && opt_color="${C_DIM}"

            # Hint
            local hint=""
            [[ -n "${hints[i]}" ]] && hint="${C_DARK} ${hints[i]}${C_RESET}"

            # Active highlight
            if [[ $i -eq $active ]]; then
                printf "  %b ${C_INVERT}${C_BOLD}${opt_color} %-30s ${C_RESET}%b%b%b  " \
                       "$checkbox" "${options[i]}" "$installed_tag" "$hint" "$C_RESET"
            else
                printf "  %b ${opt_color}%-30s${C_RESET}%b%b  " \
                       "$checkbox" "${options[i]}" "$installed_tag" "$hint"
            fi

            ((row++))
        done
    }

    # ── Main loop ─────────────────────────────────────────────────────────────
    local active=0
    render_menu $active

    while true; do
        case $(key_input) in
            space)
                toggle_option selected $active
                render_menu $active
                ;;
            enter)
                break
                ;;
            up)
                ((active--))
                [[ $active -lt 0 ]] && active=$((n - 1))
                render_menu $active
                ;;
            down)
                ((active++))
                [[ $active -ge $n ]] && active=0
                render_menu $active
                ;;
            select_all)
                for ((i=0; i<n; i++)); do selected[i]=true; done
                render_menu $active
                ;;
            deselect_all)
                for ((i=0; i<n; i++)); do selected[i]=; done
                render_menu $active
                ;;
        esac
    done

    # ── Restore cursor ────────────────────────────────────────────────────────
    cursor_to $((startrow + total_lines - 1))
    printf "\n"
    cursor_blink_on

    eval "$retval"='("${selected[@]}")'
}
