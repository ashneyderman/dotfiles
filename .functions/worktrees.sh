function mkwt() {
    local PATH_PREFIX=".worktrees"
    local BRANCH=""
    local TARGET_PATH=""
    local NEW_WINDOW=false

    # Usage message
    local usage_msg="Usage: mkwt [OPTIONS] <path>

Create a git worktree with automatic branch handling.

Arguments:
    path                Target path for the worktree (required)

Options:
    -b, --branch <name>     Branch name to checkout (default: same as path)
    -p, --path-prefix <dir> Path prefix for worktree (default: .worktrees)
    -n, --new-window        Open in new Ghostty terminal instead of cd
    -h, --help              Display this help message

Examples:
    mkwt feature-x
    mkwt -b main feature-y
    mkwt --branch main feature-y
    mkwt -p ~/worktrees feature-z
    mkwt -n feature-w"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--branch)
                BRANCH="$2"
                shift 2
                ;;
            -p|--path-prefix)
                PATH_PREFIX="$2"
                shift 2
                ;;
            -n|--new-window)
                NEW_WINDOW=true
                shift
                ;;
            -h|--help)
                echo "$usage_msg"
                return 0
                ;;
            -*)
                echo "Error: Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                return 1
                ;;
            *)
                if [[ -z "$TARGET_PATH" ]]; then
                    TARGET_PATH="$1"
                else
                    echo "Error: Too many arguments" >&2
                    echo "Use --help for usage information" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Validate required parameter
    if [[ -z "$TARGET_PATH" ]]; then
        echo "Error: path parameter is required" >&2
        echo "Use --help for usage information" >&2
        return 1
    fi

    # Default branch name to path if not specified
    if [[ -z "$BRANCH" ]]; then
        BRANCH="$TARGET_PATH"
    fi

    # Construct full target path
    local FULL_PATH
    if [[ "$PATH_PREFIX" = /* ]]; then
        # Absolute path
        FULL_PATH="$PATH_PREFIX/$TARGET_PATH"
    else
        # Relative path - concatenate with cwd
        FULL_PATH="$(pwd)/$PATH_PREFIX/$TARGET_PATH"
    fi

    # Check if target path already exists
    if [[ -e "$FULL_PATH" ]]; then
        echo "Error: Target path already exists: $FULL_PATH" >&2
        return 1
    fi

    # Check if branch exists
    local BRANCH_FLAG
    if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
        # Branch exists, use -B to force reset
        BRANCH_FLAG="-B"
        echo "Branch '$BRANCH' exists, will reset to current HEAD"
    else
        # Branch doesn't exist, use -b to create
        BRANCH_FLAG="-b"
        echo "Creating new branch '$BRANCH'"
    fi

    # Create worktree with --no-checkout
    echo "Creating worktree at: $FULL_PATH"
    git worktree add --no-checkout $BRANCH_FLAG "$BRANCH" "$FULL_PATH" || return 1

    # Either cd or open new window based on flag
    if [[ "$NEW_WINDOW" = true ]]; then
        # Checkout in the background (without cd)
        (cd "$FULL_PATH" && git checkout "$BRANCH") || return 1

        echo "Successfully created worktree at: $FULL_PATH"
        echo "Branch: $BRANCH"
        echo "Opening new Ghostty window..."
        open -a "Ghostty" "$FULL_PATH"
    else
        # cd into target directory and checkout
        cd "$FULL_PATH" || return 1
        git checkout "$BRANCH" || return 1

        echo "Successfully created worktree at: $FULL_PATH"
        echo "Branch: $BRANCH"
    fi
}

function edwt() {
    # Usage message
    local usage_msg="Usage: edwt [OPTIONS] <path>

Create a git worktree, open in Zed, and manage with AeroSpace if available.

Arguments:
    path                Target path for the worktree (required)

Options:
    -b, --branch <name>     Branch name to checkout (default: same as path)
    -p, --path-prefix <dir> Path prefix for worktree (default: .worktrees)
    -h, --help              Display this help message

Examples:
    edwt feature-x
    edwt -b main feature-y
    edwt --branch main feature-y
    edwt -p ~/worktrees feature-z"

    # Check for help flag first
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            echo "$usage_msg"
            return 0
        fi
    done

    # Check if aerospace is available
    local HAS_AEROSPACE=false
    if command -v aerospace >/dev/null 2>&1; then
        HAS_AEROSPACE=true
    fi

    # Find empty workspace if aerospace is available
    local TARGET_WORKSPACE=""
    if [[ "$HAS_AEROSPACE" = true ]]; then
        # Check workspaces 1-5 for an empty one
        for ws in {1..5}; do
            local window_count=$(aerospace list-windows --workspace "$ws" 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$window_count" -eq 0 ]]; then
                TARGET_WORKSPACE="$ws"
                echo "Found empty workspace: $TARGET_WORKSPACE"
                break
            fi
        done

        if [[ -z "$TARGET_WORKSPACE" ]]; then
            # No empty workspace found, use current one
            TARGET_WORKSPACE=$(aerospace list-workspaces --focused)
            echo "No empty workspace found, using current workspace: $TARGET_WORKSPACE"
        fi
    fi

    # Save current directory
    pushd . >/dev/null || return 1

    # Create the worktree
    mkwt "$@" || {
        popd >/dev/null
        return 1
    }

    # Open in Zed
    echo "Opening in Zed..."
    zed . || {
        popd >/dev/null
        return 1
    }

    # If aerospace is available, move window to target workspace
    if [[ "$HAS_AEROSPACE" = true ]] && [[ -n "$TARGET_WORKSPACE" ]]; then
        # Give Zed a moment to fully launch
        sleep 0.5

        echo "Moving Zed window to workspace $TARGET_WORKSPACE..."
        aerospace move-node-to-workspace "$TARGET_WORKSPACE"

        echo "Switching to workspace $TARGET_WORKSPACE..."
        aerospace workspace "$TARGET_WORKSPACE"
    fi

    # Return to original directory
    popd >/dev/null

    echo "Workspace setup complete!"
}
