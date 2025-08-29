#!/bin/bash
# env-unload.sh - Unload EnvWrap from current shell session
#
# Usage: source env-unload.sh
# 
# This script unloads EnvWrap from the current shell session
# without touching any system files or configurations.

echo "Unloading EnvWrap from current shell..."

# 1. Deactivate any active environment (return to base)
if declare -f ewrap >/dev/null 2>&1; then
    # Check current environment
    current_env=$(ewrap current 2>/dev/null | grep "Current env:" | cut -d: -f2 | xargs)
    if [ "$current_env" != "base" ] && [ -n "$current_env" ]; then
        echo "Deactivating environment: [$current_env]"
        ewrap activate base >/dev/null 2>&1
    fi
fi

# 2. Remove the ewrap function
unset -f ewrap 2>/dev/null

# 3. Remove aliases
unalias ew 2>/dev/null
unalias ewa 2>/dev/null
unalias ewl 2>/dev/null
unalias ewc 2>/dev/null
unalias ewd 2>/dev/null

# 4. Remove completion functions
if [ -n "$BASH_VERSION" ]; then
    complete -r ewrap 2>/dev/null
    unset -f _ewrap_completions 2>/dev/null
elif [ -n "$ZSH_VERSION" ]; then
    compdef -d ewrap 2>/dev/null
    unset -f _ewrap 2>/dev/null
fi

# 5. Remove environment variables
unset ENVWRAP_PATH
unset ENVWRAP_PYTHON
unset ENVWRAP_VERSION

# 6. Remove prompt functions if they exist
unset -f _ewrap_prompt 2>/dev/null
unset -f setup_prompt 2>/dev/null
unset -f auto_restore 2>/dev/null

# 7. Clean up prompt - remove any [environment] markers
if [ -n "$BASH_VERSION" ]; then
    # Remove _ewrap_prompt function calls
    export PS1="${PS1/\$(_ewrap_prompt)/}"
    # Remove any [env_name] patterns from the beginning of PS1
    export PS1=$(echo "$PS1" | sed -E 's/^\[[^]]+\] //')
    # Also remove any [env_name] patterns that might be embedded elsewhere
    export PS1=$(echo "$PS1" | sed -E 's/\[[^]]+\] //g')
elif [ -n "$ZSH_VERSION" ]; then
    # Remove _ewrap_prompt function calls
    export PROMPT="${PROMPT/\$(_ewrap_prompt)/}"
    # Remove any [env_name] patterns from the beginning of PROMPT
    export PROMPT=$(echo "$PROMPT" | sed -E 's/^\[[^]]+\] //')
    # Also remove any [env_name] patterns that might be embedded elsewhere
    export PROMPT=$(echo "$PROMPT" | sed -E 's/\[[^]]+\] //g')
fi

echo "EnvWrap unloaded from current shell."
echo ""
echo "Note: This only affects the current shell session."
echo "- Your environments are still saved in: ${ENV_MANAGER_HOME:-envs/}"
echo "- To use EnvWrap again, run: source env-init.sh"