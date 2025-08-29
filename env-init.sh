#!/bin/bash
# env-init.sh - EnvWrap Shell Integration
# 
# Usage: source env-init.sh
#
# To use: source /path/to/env-init.sh
# Or add to your .bashrc/.zshrc: source /path/to/your/EnvWrap/env-init.sh

# Auto-detect the directory where this script is located
if [ -n "$BASH_SOURCE" ]; then
    ENVWRAP_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
elif [ -n "$ZSH_VERSION" ]; then
    ENVWRAP_PATH="${0:A:h}"
else
    echo "Warning: Could not auto-detect script directory. Please set ENVWRAP_PATH manually."
    ENVWRAP_PATH="."
fi

# Export environment variables
export ENVWRAP_PATH
export ENVWRAP_PYTHON="${ENVWRAP_PYTHON:-python3}"
export ENVWRAP_VERSION="1.0.0"

# Optional: Set custom config directory (defaults to script directory/envs)
# export ENV_MANAGER_HOME="$HOME/.config/envwrap"

# Main ewrap function - wraps the Python script for shell integration
ewrap() {
    local cmd="$1"
    
    # Check if main.py exists
    if [ ! -f "$ENVWRAP_PATH/main.py" ]; then
        echo "Error: main.py not found in $ENVWRAP_PATH"
        echo "Please ensure ENVWRAP_PATH is set correctly"
        return 1
    fi
    
    case "$cmd" in
        "")
            # No command - show help
            cat << 'HELP'
EnvWrap - Environment and PATH Manager

Usage: ewrap COMMAND [OPTIONS]

Commands:
  create NAME       Create a new environment
  activate NAME     Activate an environment (modifies PATH)
  deactivate        Return to base environment  
  list              List all environments
  current           Show current environment
  addpath PATH      Add a path to current environment
  removepath PATH   Remove a path from current environment
  delete NAME       Delete an environment
  reset             Reset base environment
  info              Show configuration info
  which             Show EnvWrap location
  reload            Reload shell integration
  help              Show this help message

Examples:
  ewrap create myproject
  ewrap activate myproject
  ewrap addpath ./node_modules/.bin
  ewrap deactivate

Note: Using [name] in prompt to distinguish from conda's (name)
HELP
            ;;
        
        activate|act|a)
            shift
            local env_name="${1:-base}"
            
            # Special handling for activate - modifies current shell environment
            local tmpfile=$(mktemp /tmp/ewrap-activate-XXXXXX.sh)
            
            # Run Python script and export shell commands to temp file
            if $ENVWRAP_PYTHON "$ENVWRAP_PATH/main.py" activate "$@" --export-shell "$tmpfile"; then
                # Source the temp file to apply PATH changes to current shell
                if [ -f "$tmpfile" ] && [ -s "$tmpfile" ]; then
                    source "$tmpfile"
                fi
                
                # Handle prompt update separately to avoid duplicates
                # Remove any existing EnvWrap markers from prompt first
                if [ -n "$BASH_VERSION" ]; then
                    export PS1="${PS1//\[*\] /}"
                    # if [ "$env_name" != "base" ]; then
                    export PS1="[$env_name] $PS1"
                    # fi
                elif [ -n "$ZSH_VERSION" ]; then
                    export PROMPT="${PROMPT//\[*\] /}"
                    # if [ "$env_name" != "base" ]; then
                    export PROMPT="[$env_name] $PROMPT"
                    # fi
                fi
            fi
            
            # Clean up
            rm -f "$tmpfile"
            ;;
        
        deactivate|deact|d)
            # Deactivate is just activating the base environment
            ewrap activate base
            ;;
        
        reload)
            # Reload this script (useful after updates)
            source "${BASH_SOURCE[0]:-$0}"
            echo "EnvWrap reloaded"
            ;;
        
        which)
            # Show location of EnvWrap
            echo "EnvWrap Location:"
            echo "  Script: $ENVWRAP_PATH"
            echo "  Python: $ENVWRAP_PYTHON"
            echo "  Config: ${ENV_MANAGER_HOME:-$ENVWRAP_PATH/envs}"
            ;;
        
        help|h)
            # Show help
            ewrap
            ;;
        
        # Shortcuts
        c)
            shift
            $ENVWRAP_PYTHON "$ENVWRAP_PATH/main.py" create "$@"
            ;;
        
        l)
            shift
            $ENVWRAP_PYTHON "$ENVWRAP_PATH/main.py" list "$@"
            ;;
        
        cur)
            $ENVWRAP_PYTHON "$ENVWRAP_PATH/main.py" current
            ;;
        
        add)
            shift
            $ENVWRAP_PYTHON "$ENVWRAP_PATH/main.py" addpath "$@"
            ;;
        
        rm)
            shift
            $ENVWRAP_PYTHON "$ENVWRAP_PATH/main.py" removepath "$@"
            ;;
        
        del)
            shift
            $ENVWRAP_PYTHON "$ENVWRAP_PATH/main.py" delete "$@"
            ;;
        
        *)
            # All other commands - pass through to Python script
            shift
            $ENVWRAP_PYTHON "$ENVWRAP_PATH/main.py" "$cmd" "$@"
            ;;
    esac
}

# Bash completion support
if [ -n "$BASH_VERSION" ]; then
    _ewrap_completions() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local prev="${COMP_WORDS[COMP_CWORD-1]}"
        
        # Command list (including shortcuts)
        local commands="create activate deactivate list current addpath removepath delete reset info which reload help c a d l cur add rm del"
        
        if [ $COMP_CWORD -eq 1 ]; then
            # Complete command names
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        elif [ $COMP_CWORD -eq 2 ]; then
            # Complete based on previous command
            case "$prev" in
                activate|a|delete|del)
                    # Get environment names
                    local envs=$($ENVWRAP_PYTHON "$ENVWRAP_PATH/main.py" list --names-only 2>/dev/null)
                    COMPREPLY=($(compgen -W "$envs" -- "$cur"))
                    ;;
                addpath|add|removepath|rm)
                    # Complete with directories
                    COMPREPLY=($(compgen -d -- "$cur"))
                    ;;
                *)
                    COMPREPLY=()
                    ;;
            esac
        fi
    }
    
    complete -F _ewrap_completions ewrap
fi

# Zsh completion support
if [ -n "$ZSH_VERSION" ]; then
    # Initialize completion system if not already done
    if ! command -v compdef >/dev/null 2>&1; then
        autoload -Uz compinit && compinit
    fi
    
    _ewrap() {
        local -a commands
        commands=(
            'create:Create a new environment'
            'c:Create a new environment (shortcut)'
            'activate:Activate an environment'
            'a:Activate an environment (shortcut)'
            'deactivate:Return to base environment'
            'd:Return to base environment (shortcut)'
            'list:List all environments'
            'l:List all environments (shortcut)'
            'current:Show current environment'
            'cur:Show current environment (shortcut)'
            'addpath:Add path to current environment'
            'add:Add path to current environment (shortcut)'
            'removepath:Remove path from environment'
            'rm:Remove path from environment (shortcut)'
            'delete:Delete an environment'
            'del:Delete an environment (shortcut)'
            'reset:Reset base environment'
            'info:Show configuration info'
            'which:Show EnvWrap location'
            'reload:Reload shell integration'
            'help:Show help message'
            'h:Show help message (shortcut)'
        )
        
        if (( CURRENT == 2 )); then
            _describe -t commands 'ewrap command' commands
        elif (( CURRENT == 3 )); then
            case "$words[2]" in
                activate|a|delete|del)
                    local envs=($(${ENVWRAP_PYTHON} ${ENVWRAP_PATH}/main.py list --names-only 2>/dev/null))
                    _describe -t environments 'environment' envs
                    ;;
                addpath|add|removepath|rm)
                    _path_files -/
                    ;;
            esac
        fi
    }
    
    # Only define completion if compdef is available
    if command -v compdef >/dev/null 2>&1; then
        compdef _ewrap ewrap
    fi
fi

# Optional: Set up prompt to show active environment with [name] format
setup_prompt() {
    if [ -n "$BASH_VERSION" ]; then
        # Bash prompt
        _ewrap_prompt() {
            local env_name=$($ENVWRAP_PYTHON "$ENVWRAP_PATH/main.py" current 2>/dev/null | grep "Current env:" | cut -d: -f2 | xargs)
            if [ "$env_name" != "base" ] && [ -n "$env_name" ]; then
                echo "[$env_name] "
            fi
        }
        
        # Add to PS1 if not already there
        if [[ ! "$PS1" =~ _ewrap_prompt ]]; then
            export PS1='$(_ewrap_prompt)'"$PS1"
        fi
    elif [ -n "$ZSH_VERSION" ]; then
        # Zsh prompt
        _ewrap_prompt() {
            local env_name=$($ENVWRAP_PYTHON "$ENVWRAP_PATH/main.py" current 2>/dev/null | grep "Current env:" | cut -d: -f2 | xargs)
            if [ "$env_name" != "base" ] && [ -n "$env_name" ]; then
                echo "[$env_name] "
            fi
        }
        
        # Add to prompt if not already there
        if [[ ! "$PROMPT" =~ _ewrap_prompt ]]; then
            export PROMPT='$(_ewrap_prompt)'"$PROMPT"
        fi
    fi
}

# Uncomment to enable prompt modification with [name] format
# setup_prompt

# Optional: Auto-activate last environment on initialization
auto_restore() {
    local config_dir="${ENV_MANAGER_HOME:-$ENVWRAP_PATH/envs}"
    if [ -f "$config_dir/.current_env" ]; then
        local current_env=$(cat "$config_dir/.current_env" 2>/dev/null | tr -d '"')
        if [ "$current_env" != "base" ] && [ -n "$current_env" ]; then
            echo "Restoring EnvWrap environment: [$current_env]"
            ewrap activate "$current_env" >/dev/null 2>&1
        fi
    fi
}

auto_restore_base() {
    ewrap activate base > /dev/null 2>&1
}

# Uncomment to enable auto-restore
# auto_restore
auto_restore_base

# Aliases for convenience
alias ew='ewrap'
alias ewa='ewrap activate'
alias ewl='ewrap list'
alias ewc='ewrap current'
alias ewd='ewrap deactivate'

# Success message
echo "EnvWrap loaded. Type 'ewrap help' for usage. (Shortcuts: ew, ewa, ewl, ewc, ewd)"
echo "Location: $ENVWRAP_PATH"