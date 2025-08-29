# EnvWrap

EnvWrap is a lightweight environment management tool for managing PATH environment variables across different projects (Maybe not only PATH in the future). It allows you to create independent environment configurations for different projects and quickly switch between them.

## Installation

### Method 1: Direct Usage

1. Clone or download EnvWrap to a local directory
2. Load EnvWrap in your shell:

```bash
source EnvWrap/env-init.sh
```

### Method 2: Add to Shell Configuration

Add the following line to your shell configuration file (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
source /path/to/EnvWrap/env-init.sh
```

## Usage

### Basic Commands

- `ewrap help` - Show help information
- `ewrap list` - List all environments
- `ewrap current` - Show current environment
- `ewrap create <name>` - Create a new environment
- `ewrap activate <name>` - Activate an environment
- `ewrap deactivate` - Deactivate current environment (return to base)
- `ewrap addpath <path>` - Add a path to the current environment
- `ewrap removepath <path>` - Remove a path from the current environment
- `ewrap delete <name>` - Delete an environment
- `ewrap reset` - Reset to base environment and clear all paths
- `ewrap clone <source> <target>` - Clone source environment to target environment (creates target if it doesn't exist, overwrites if it does)

### Shortcut Commands

- `ew` - Alias for `ewrap`
- `ewa` - Alias for `ewrap activate`
- `ewl` - Alias for `ewrap list`
- `ewc` - Alias for `ewrap current`
- `ewd` - Alias for `ewrap deactivate`

### Usage Examples

```bash
# Create a new environment
ewrap create myproject

# Activate the environment
ewrap activate myproject

# Add paths to the environment
ewrap addpath /usr/local/myproject/bin
ewrap addpath /opt/myproject/tools

# Quick example: Add current directory to PATH
ewrap addpath $(pwd)

# View current environment
ewrap current

# List all environments
ewrap list

# Switch to another environment
ewrap activate another-project

# Deactivate environment (return to base)
ewrap deactivate
```

### Quick Path Addition with pwd

A common use case is adding the current working directory to your environment's PATH:

```bash
# Create and activate a project environment
ewrap create myproject
ewrap activate myproject

# Add current directory to PATH (useful for development)
ewrap addpath $(pwd)

# Or using the shortcut
ewrap addpath .
```

This is particularly useful when you have executable scripts or binaries in your current project directory that you want to run without specifying the full path.

### Environment Variable Configuration

You can customize EnvWrap's behavior by setting environment variables:

- `ENV_MANAGER_HOME` - Specify the storage location for environment configuration files
- `XDG_CONFIG_HOME` - Use XDG standard configuration directory

If these variables are not set, EnvWrap defaults to storing configuration files in the `envs` subdirectory of the installation directory.

## Uninstallation

To unload EnvWrap from the current shell session:

```bash
source EnvWrap/env-unload.sh
```

## Configuration Files

EnvWrap stores environment configurations in JSON files, with one file per environment. Configuration files contain the environment name and a list of paths.

By default, configuration files are stored in:
- If `ENV_MANAGER_HOME` is set: Use that directory
- If `XDG_CONFIG_HOME` is set: `$XDG_CONFIG_HOME/env-manager`
- Default: `EnvWrap/envs/`

## Notes

- EnvWrap only affects the PATH environment variable of the current shell session
- Environment configurations are persistent and remain available after shell restart
- When an environment is activated, `[environment_name]` is displayed before the shell prompt
- The base environment is the default environment and cannot be deleted
