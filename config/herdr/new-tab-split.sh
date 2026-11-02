#!/bin/bash

# Créer un onglet et récupérer son terminal initial.
result=$(herdr tab create --focus) || exit 1

pane_id=$(printf '%s\n' "$result" | jq -r '.result.root_pane.pane_id')

# Diviser en deux terminaux gauche/droite (50/50).
herdr pane split "$pane_id" --direction right --ratio 0.5
