#!/bin/bash

docker() {
    if [[ $1 == "compose" ]]; then
        shift
        command docker-compose "$@"
    elif [[ $1 == "lint" ]]; then
        shift
        command dockerfilelint "$@"
    else
        command docker "$@"
    fi
}
export -f docker

_yarn_completions() {
    local suggestions=$(npm run | grep -E '^  [^ ]' | sed 's/\s*//g' | tr '\n' ' ')
    suggestions+="add install --dev --fix"

    COMPREPLY=($(compgen -W "$suggestions" -- "$2"))
}
complete -F _yarn_completions yarn
