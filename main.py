import os, sys, json, subprocess, shlex
from pathlib import Path
import typer


app = typer.Typer()


# Determine the base directory for all environment data
def get_env_base_dir():
    """Get the base directory for storing environment configurations."""
    # Option 1: Use ENV_MANAGER_HOME if set
    if "ENV_MANAGER_HOME" in os.environ:
        return Path(os.environ["ENV_MANAGER_HOME"])
    
    # Option 2: Use XDG_CONFIG_HOME if set (Linux standard)
    if "XDG_CONFIG_HOME" in os.environ:
        return Path(os.environ["XDG_CONFIG_HOME"]) / "env-manager"
    
    # Option 3: Default to EnvWrap installation directory (clean approach)
    # Get the directory where this script is located
    script_dir = Path(__file__).parent
    return script_dir / "envs"


# Global Configs
ENV_BASE_DIR = get_env_base_dir()
CONFIG_FILE = ENV_BASE_DIR / ".current_env"


class Env:
    def __init__(self, name: str):
        self.name = name
        self.env_file_path = ENV_BASE_DIR / f"{name}.json"
        self.env_paths = []
        self.load()

    def __str__(self):
        return self.name

    def get_name(self):
        return self.name

    def get_env_file_path(self):
        return self.env_file_path

    def get_env_paths(self):
        return self.env_paths
    
    def load(self):
        """Load environment configuration from file"""
        if self.env_file_path.exists():
            try:
                with open(self.env_file_path, "r") as f:
                    config = json.load(f)
                    self.env_paths = config.get("paths", [])
            except (json.JSONDecodeError, OSError):
                self.env_paths = []
    
    def save(self):
        """Save environment configuration to file"""
        config = {
            "name": self.name,
            "paths": self.env_paths
        }
        self.env_file_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.env_file_path, "w") as f:
            json.dump(config, f, indent=2)
    
    def add_path(self, path: str):
        """Add a path to the environment"""
        abs_path = str(Path(path).resolve())
        if abs_path not in self.env_paths:
            self.env_paths.append(abs_path)
            self.save()
            return True
        return False
    
    def remove_path(self, path: str):
        """Remove a path from the environment"""
        abs_path = str(Path(path).resolve())
        if abs_path in self.env_paths:
            self.env_paths.remove(abs_path)
            self.save()
            return True
        return False


def get_current_env_name():
    """Get the name of the currently active environment"""
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError):
            return "base"
    return "base"


def set_current_env(name: str):
    """Set the current environment"""
    CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        json.dump(name, f)


@app.command()
def current():
    """Show the current active environment"""
    current_env = get_current_env_name()
    print(f"Current env: {current_env}")
    
    # Also show the paths in the current environment
    env = Env(current_env)
    if env.env_paths:
        print("\nPaths in this environment:")
        for path in env.env_paths:
            print(f"  - {path}")


@app.command()
def reset():
    """Reset to the base environment and clear its paths"""
    # Set current env to base
    set_current_env("base")
    
    # Clear base environment paths
    base_env = Env("base")
    base_env.env_paths = []
    base_env.save()
    
    print("Reset to base environment and cleared all paths")


@app.command()
def list(names_only: bool = typer.Option(False, "--names-only", help="Only output environment names")):
    """List all available environments"""
    current_env = get_current_env_name()
    
    if names_only:
        # Simple output for shell completion
        print("base")
        env_dir = ENV_BASE_DIR
        if env_dir.exists():
            for env_file in env_dir.glob("*.json"):
                if env_file.stem != "base":
                    print(env_file.stem)
        return
    
    # Always show base environment
    if current_env == "base":
        print(f"+ base (active)")
    else:
        print(f"+ base")
    
    # List other environments
    env_dir = ENV_BASE_DIR
    if not env_dir.exists():
        return
        
    for env_file in env_dir.glob("*.json"):
        if env_file.stem == "base":
            continue
            
        try:
            text = env_file.read_text(encoding="utf-8")
        except OSError as e:
            print(f"+ !!! Error: {env_file} is an invalid env file")
            continue

        if not text.strip():
            print(f"+ !!! Error: {env_file} is an invalid env file")
            continue

        try:
            env_config = json.loads(text)
        except json.JSONDecodeError as e:
            print(f"+ !!! Error: {env_file} is an invalid env file")
            continue

        if 'name' not in env_config:
            print(f"+ !!! Error: {env_file} is an invalid env file")
            continue

        if env_config['name'] == current_env:
            print(f"+ {env_config['name']} (active)")
        else:
            print(f"+ {env_config['name']}")


@app.command()
def create(name: str):
    """Create a new environment"""
    if name == "base":
        print("Error: Cannot create an environment named 'base'")
        raise typer.Exit(1)
    
    env = Env(name)
    if env.env_file_path.exists():
        print(f"Error: Environment '{name}' already exists")
        raise typer.Exit(1)
    
    env.save()
    print(f"Created environment: {name}")


@app.command()
def clone(source: str, target: str):
    if target == "base":
        print("Error: Cannot clone to base environment")
        raise typer.Exit(1)
    
    source_env = Env(source)
    target_env = Env(target)
    if not source_env.env_file_path.exists():
        print(f"Error: Environment '{source}' does not exist")
        raise typer.Exit(1)
    
    target_env.env_paths = source_env.env_paths
    target_env.save()
    print(f"Cloned environment: {source} to {target}")
    

@app.command()
def activate(
    name: str,
    export_shell: str = typer.Option(None, "--export-shell", help="Export shell commands to file")
):
    """Activate an environment and update PATH"""
    # Check if environment exists (except for base which always exists)
    if name != "base":
        env_file = ENV_BASE_DIR / f"{name}.json"
        if not env_file.exists():
            print(f"Error: Environment '{name}' does not exist", file=sys.stderr)
            raise typer.Exit(1)
    
    # Get ALL current envwrap paths to remove (from any environment)
    # This ensures we clean up paths from ANY previously active environment
    all_envwrap_paths = set()
    if ENV_BASE_DIR.exists():
        for env_file in ENV_BASE_DIR.glob("*.json"):
            try:
                with open(env_file, "r") as f:
                    config = json.load(f)
                    paths = config.get("paths", [])
                    all_envwrap_paths.update(paths)
            except (json.JSONDecodeError, OSError):
                continue
    
    # Set new current environment
    set_current_env(name)
    
    # Load new environment
    env = Env(name)
    
    if export_shell:
        # Export shell commands for the shell function to source
        with open(export_shell, "w") as f:
            # First, remove ALL envwrap paths from PATH (from any environment)
            # This ensures only one environment's paths are active at a time
            f.write('#!/bin/bash\n')
            f.write('# Clean up all EnvWrap paths from PATH\n')
            f.write('CLEANED_PATH="$PATH"\n')
            
            for path in all_envwrap_paths:
                # Escape special characters for sed
                escaped_path = path.replace('/', '\\/')
                f.write(f'CLEANED_PATH=$(echo "$CLEANED_PATH" | sed -e "s|{escaped_path}:||g" -e "s|:{escaped_path}||g" -e "s|^{escaped_path}$||g")\n')
            
            f.write('export PATH="$CLEANED_PATH"\n\n')
            
            # Now add only the new environment's paths
            if env.env_paths:
                f.write(f'# Add paths from environment: {name}\n')
                for path in env.env_paths:
                    f.write(f'''if [[ ":$PATH:" != *":{path}:"* ]]; then
    export PATH="{path}:$PATH"
fi
''')
            
            # Set environment variable to track current env
            f.write(f'\n# Set current environment\n')
            f.write(f'export ENVWRAP_CURRENT="{name}"\n')
    else:
        # Normal operation without shell integration
        # First remove all envwrap paths
        current_path = os.environ.get("PATH", "").split(os.pathsep)
        cleaned_path = [p for p in current_path if p not in all_envwrap_paths]
        
        # Then add new environment's paths
        for path in env.env_paths:
            if path not in cleaned_path:
                cleaned_path.insert(0, path)
        
        os.environ["PATH"] = os.pathsep.join(cleaned_path)
    
    print(f"Activated environment: {name}")
    if env.env_paths:
        print("Added paths to PATH:")
        for path in env.env_paths:
            print(f"  - {path}")


def deactivate(name: str):
    """Deactivate an environment and remove its paths from PATH"""
    env = Env(name)
    
    # Remove paths from PATH
    current_path = os.environ.get("PATH", "").split(os.pathsep)
    for path in env.env_paths:
        if path in current_path:
            current_path.remove(path)
    
    os.environ["PATH"] = os.pathsep.join(current_path)


@app.command()
def addpath(path: str):
    """Add a path to the current environment"""
    # Check if path exists
    path_obj = Path(path)
    if not path_obj.exists():
        print(f"Error: Path '{path}' does not exist")
        raise typer.Exit(1)
    
    # Get current environment
    current_env_name = get_current_env_name()
    env = Env(current_env_name)
    
    # Add path to environment
    if env.add_path(path):
        abs_path = str(path_obj.resolve())
        print(f"Added path '{abs_path}' to environment '{current_env_name}'")
        
        # Also add to current PATH if this is the active environment
        if abs_path not in os.environ.get("PATH", "").split(os.pathsep):
            os.environ["PATH"] = f"{abs_path}{os.pathsep}{os.environ.get('PATH', '')}"
    else:
        print(f"Path '{str(path_obj.resolve())}' already exists in environment '{current_env_name}'")


@app.command()
def removepath(path: str):
    """Remove a path from the current environment"""
    # Get current environment
    current_env_name = get_current_env_name()
    env = Env(current_env_name)
    
    # Remove path from environment
    path_obj = Path(path)
    if env.remove_path(path):
        abs_path = str(path_obj.resolve())
        print(f"Removed path '{abs_path}' from environment '{current_env_name}'")
        
        # Also remove from current PATH
        current_path = os.environ.get("PATH", "").split(os.pathsep)
        if abs_path in current_path:
            current_path.remove(abs_path)
            os.environ["PATH"] = os.pathsep.join(current_path)
    else:
        print(f"Path '{str(path_obj.resolve())}' not found in environment '{current_env_name}'")


@app.command()
def delete(name: str):
    """Delete an environment"""
    if name == "base":
        print("Error: Cannot delete the base environment")
        raise typer.Exit(1)
    
    env_file = ENV_BASE_DIR / f"{name}.json"
    if not env_file.exists():
        print(f"Error: Environment '{name}' does not exist")
        raise typer.Exit(1)
    
    # If this is the current environment, switch to base first
    current_env_name = get_current_env_name()
    if current_env_name == name:
        print(f"Switching to base environment before deleting '{name}'")
        activate("base")
    
    # Delete the environment file
    env_file.unlink()
    print(f"Deleted environment: {name}")


@app.command()
def info():
    """Show information about the environment manager configuration"""
    print(f"Environment Manager Configuration")
    print(f"=================================")
    print(f"Config directory: {ENV_BASE_DIR}")
    print(f"Current env file: {CONFIG_FILE}")
    print(f"Current environment: {get_current_env_name()}")
    print()
    
    # Count environments
    env_dir = ENV_BASE_DIR
    if env_dir.exists():
        env_count = len(list(env_dir.glob("*.json")))
        print(f"Total environments: {env_count}")
    else:
        print("No environments directory found")
    
    # Show environment variable overrides if any
    print()
    print("Environment Variables:")
    if "ENV_MANAGER_HOME" in os.environ:
        print(f"  ENV_MANAGER_HOME = {os.environ['ENV_MANAGER_HOME']}")
    else:
        print(f"  ENV_MANAGER_HOME = (not set, using default)")
    
    if "XDG_CONFIG_HOME" in os.environ:
        print(f"  XDG_CONFIG_HOME = {os.environ['XDG_CONFIG_HOME']}")


if __name__ == "__main__":
    # Ensure the config directory exists
    ENV_BASE_DIR.mkdir(parents=True, exist_ok=True)
    
    # Initialize configuration
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE, "r") as f:
            try:
                current_env = json.load(f)
            except json.JSONDecodeError:
                current_env = "base"
    else:
        current_env = "base"
        CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
        CONFIG_FILE.touch(exist_ok=True)
        with open(CONFIG_FILE, "w") as f:
            json.dump(current_env, f)
    
    # Ensure base environment exists
    base_env = Env("base")
    if not base_env.env_file_path.exists():
        base_env.save()

    app()