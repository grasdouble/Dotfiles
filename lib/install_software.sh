#!/bin/bash

# ============================================================================
# SOFTWARE INSTALL FUNCTIONS
# Requires: lib/colors.sh (log_*, track_result, brew_install, DRY_RUN)
#           step, numberStep, LOG_FILE
# ============================================================================

installSoftwarePro() {
    ((step += 1))
    log_step "Install Software: Pro Bundle"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "brew install --cask visual-studio-code iterm2 sublime-text rectangle cakebrew grandperspective spotify vivaldi audio-hijack whatsapp discord + qemu colima docker"
        track_result "Software: Pro" "ok"; return
    fi
    # Development tools
    brew_install --cask visual-studio-code --appdir=/Applications/Developments
    brew_install --cask iterm2            --appdir=/Applications/Developments
    brew_install --cask sublime-text      --appdir=/Applications/Developments
    brew_install qemu colima docker
    # Tools
    brew_install --cask rectangle         --appdir=/Applications/Tools
    brew_install --cask cakebrew          --appdir=/Applications/Tools
    brew_install --cask grandperspective  --appdir=/Applications/Tools
    # Others
    brew_install --cask spotify           --appdir=/Applications/Others
    brew_install --cask vivaldi           --appdir=/Applications/Others
    # Communications
    brew_install --cask audio-hijack      --appdir=/Applications/Communications
    brew_install --cask whatsapp          --appdir=/Applications/Communications
    brew_install --cask discord           --appdir=/Applications/Communications
    log_success "Software: Pro Bundle installed"
    track_result "Software: Pro" "ok"
}

installSoftwareDevelopment() {
    ((step += 1))
    log_step "Install Software: Development"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "brew install --cask visual-studio-code iterm2 wave sublime-text notion anki + qemu colima docker"
        track_result "Software: Development" "ok"; return
    fi
    brew_install --cask visual-studio-code --appdir=/Applications/Developments
    brew_install --cask iterm2             --appdir=/Applications/Developments
    brew_install --cask wave               --appdir=/Applications/Developments
    brew_install --cask sublime-text       --appdir=/Applications/Developments
    brew_install --cask notion             --appdir=/Applications/Developments
    brew_install --cask anki              --appdir=/Applications/Developments
    brew_install qemu colima docker
    log_success "Software: Development installed"
    track_result "Software: Development" "ok"
}

installSoftwareLLM() {
    ((step += 1))
    log_step "Install Software: LLM Tools"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "brew install --cask lm-studio chatgpt superwhisper opencode opencode-desktop antigravity"
        track_result "Software: LLM" "ok"; return
    fi
    brew_install --cask lm-studio        --appdir=/Applications/Developments
    brew_install --cask chatgpt          --appdir=/Applications/Developments
    brew_install --cask superwhisper     --appdir=/Applications/Developments
    brew_install opencode
    brew_install --cask opencode-desktop --appdir=/Applications/Developments
    brew_install --cask antigravity      --appdir=/Applications/Developments
    log_success "Software: LLM Tools installed"
    track_result "Software: LLM" "ok"
}

installSoftwareTools() {
    ((step += 1))
    log_step "Install Software: Tools"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "brew install --cask rectangle oversight logi-options-plus jdownloader background-music grandperspective pearcleaner clop protonvpn jordanbaird-ice"
        track_result "Software: Tools" "ok"; return
    fi
    brew_install --cask rectangle         --appdir=/Applications/Tools
    brew_install --cask oversight         --appdir=/Applications/Tools
    brew_install --cask logi-options-plus --appdir=/Applications/Tools
    brew_install --cask jdownloader       --appdir=/Applications/Tools
    brew_install --cask background-music  --appdir=/Applications/Tools
    brew_install --cask grandperspective  --appdir=/Applications/Tools
    brew_install --cask pearcleaner       --appdir=/Applications/Tools
    brew_install --cask clop              --appdir=/Applications/Tools
    brew_install --cask protonvpn         --appdir=/Applications/Tools
    brew_install --cask jordanbaird-ice   --appdir=/Applications/Tools
    log_success "Software: Tools installed"
    track_result "Software: Tools" "ok"
}

installSoftwareCommunication() {
    ((step += 1))
    log_step "Install Software: Communication"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "brew install --cask audio-hijack slack whatsapp discord signal"
        track_result "Software: Communication" "ok"; return
    fi
    brew_install --cask audio-hijack --appdir=/Applications/Communications
    brew_install --cask slack        --appdir=/Applications/Communications
    brew_install --cask whatsapp     --appdir=/Applications/Communications
    brew_install --cask discord      --appdir=/Applications/Communications
    brew_install --cask signal       --appdir=/Applications/Communications
    log_success "Software: Communication installed"
    track_result "Software: Communication" "ok"
}

installSoftwareOffice() {
    ((step += 1))
    log_step "Install Software: Office"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "brew install --cask microsoft-office"
        track_result "Software: Office" "ok"; return
    fi
    brew_install --cask microsoft-office --appdir=/Applications/Office
    log_success "Software: Office installed"
    track_result "Software: Office" "ok"
}

installSoftwareGames() {
    ((step += 1))
    log_step "Install Software: Games"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "brew install --cask nvidia-geforce-now epic-games steam prismlauncher scummvm obs openemu sony-ps-remote-play moonlight"
        track_result "Software: Games" "ok"; return
    fi
    brew_install --cask --no-quarantine nvidia-geforce-now  --appdir=/Applications/Games
    brew_install --cask --no-quarantine epic-games          --appdir=/Applications/Games
    brew_install --cask --no-quarantine steam               --appdir=/Applications/Games
    brew_install --cask --no-quarantine prismlauncher       --appdir=/Applications/Games
    brew_install --cask --no-quarantine scummvm             --appdir=/Applications/Games
    brew_install --cask obs                                 --appdir=/Applications/Games
    brew_install --cask --no-quarantine openemu             --appdir=/Applications/Games
    brew_install --cask sony-ps-remote-play                 --appdir=/Applications/Games
    brew_install --cask moonlight                           --appdir=/Applications/Games
    log_success "Software: Games installed"
    track_result "Software: Games" "ok"
}

installSoftwareOthers() {
    ((step += 1))
    log_step "Install Software: Others"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "brew install --cask spotify calibre kindle-previewer send-to-kindle hakuneko affinity vivaldi"
        track_result "Software: Others" "ok"; return
    fi
    brew_install --cask --no-quarantine spotify   --appdir=/Applications/Others
    brew_install --cask calibre                   --appdir=/Applications/Others
    brew_install --cask kindle-previewer          --appdir=/Applications/Others
    brew_install --cask send-to-kindle            --appdir=/Applications/Others
    brew_install --cask hakuneko                  --appdir=/Applications/Others
    brew_install --cask affinity                  --appdir=/Applications/Others
    brew_install --cask --no-quarantine vivaldi   --appdir=/Applications/Others
    log_success "Software: Others installed"
    track_result "Software: Others" "ok"
}
