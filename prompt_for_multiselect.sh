#!/bin/bash

function prompt_for_multiselect {

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()   { printf "%s[?25h" "$ESC"; }
    cursor_blink_off()  { printf "%s[?25l" "$ESC"; }
    cursor_to()         { printf "%s[%s;%sH" "$ESC" "$1" "${2:-1}"; }
    print_inactive()    { printf "%s   %s " "$2" "$1"; }
    print_active()      { printf "%s  %s[7m %s %s[27m" "$2" "$ESC" "$1" "$ESC"; }
    get_cursor_row()    { IFS=';' read -rsdR -p $'\E[6n' ROW COL; echo "${ROW#*[}"; }
    key_input()         {
      local key
      IFS= read -rsn1 key 2>/dev/null >&2
      if [[ $key = ""      ]]; then echo enter; fi;
      if [[ $key = $'\x20' ]]; then echo space; fi;
      if [[ $key = $'\x1b' ]]; then
        read -rsn2 key
        if [[ $key = [A ]]; then echo up;    fi;
        if [[ $key = [B ]]; then echo down;  fi;
      fi 
    }
    toggle_option()    {
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

    local retval=$1
    local options
    local defaults

    IFS=';' read -r -a options <<< "$2"
    if [[ -z $3 ]]; then
      defaults=()
    else
      IFS=';' read -r -a defaults <<< "$3"
    fi
    local selected=()

    for ((i=0; i<${#options[@]}; i++)); do
      selected+=("${defaults[i]}")
      printf "\n"
    done

    # determine current screen position for overwriting the options
    local lastrow
    lastrow=$(get_cursor_row)
    local startrow=$((lastrow - ${#options[@]}))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local active=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for option in "${options[@]}"; do
            local prefix="[ ]"
            if [[ ${selected[idx]} == true ]]; then
              prefix="[x]"
            fi

            cursor_to $((startrow + idx))
            if [ $idx -eq $active ]; then
                print_active "$option" "$prefix"
            else
                print_inactive "$option" "$prefix"
            fi
            ((idx++))
        done

        # user key control
        case $(key_input) in
            space)  toggle_option selected $active;;
            enter)  break;;
            up)     ((active--));
                    if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
            down)   ((active++));
                    if [ $active -ge ${#options[@]} ]; then active=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to "$lastrow"
    printf "\n"
    cursor_blink_on

    eval "$retval"='("${selected[@]}")'
}

# prompt_for_multiselect result "Option 1;Option 2;Option 3" "true;;true"

# # Votre logique pour appeler des fonctions en fonction des options sélectionnées
# for i in "${!result[@]}"; do
#     if [[ ${result[$i]} == true ]]; then
#         case $i in
#             0) echo 'option 1' ;; # Appeler fonction1 pour l'Option 1
#             1) echo 'option 2' ;; # Appeler fonction2 pour l'Option 2
#             2) echo 'option 3' ;; # Appeler fonction3 pour l'Option 3
#         esac
#     fi
# done