function mkwt() {
    local PATH_PREFIX=".worktrees"
    local PATH_PREFIX_EXPLICIT=false
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
    -p, --path-prefix <dir> Path prefix for worktree (default: .worktrees or parent of current worktree)
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
                PATH_PREFIX_EXPLICIT=true
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

    # Auto-detect worktree parent if -p not explicitly set
    if [[ "$PATH_PREFIX_EXPLICIT" = false ]]; then
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            local current_toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
            local main_worktree=$(git worktree list --porcelain 2>/dev/null | grep -m1 "^worktree" | cut -d' ' -f2)

            if [[ -n "$current_toplevel" ]] && [[ -n "$main_worktree" ]] && [[ "$current_toplevel" != "$main_worktree" ]]; then
                # We're in a worktree (not the main repo)
                PATH_PREFIX="$(dirname "$current_toplevel")"
                echo "Detected worktree, using parent directory: $PATH_PREFIX"
            fi
        fi
    fi

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
    -p, --path-prefix <dir> Path prefix for worktree (default: .worktrees or parent of current worktree)
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

function _rmwt() {
    local FORCE=false
    local DRY_RUN=false
    local patterns=()

    # Usage message
    local usage_msg="Usage: rmwt [OPTIONS] <pattern>...

Remove git worktrees matching the given patterns.

Arguments:
    pattern             Worktree name or glob pattern (can specify multiple)

Options:
    -f, --force         Skip confirmation and force removal even if dirty
    -n, --dry-run       Show what would be removed without removing
    -h, --help          Display this help message

Examples:
    rmwt feature-x
    rmwt feature-x feature-y
    rmwt feature-*
    rmwt -f feature-x
    rmwt -n *-test"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                FORCE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
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
                patterns+=("$1")
                shift
                ;;
        esac
    done

    # Validate at least one pattern provided
    if [[ ${#patterns[@]} -eq 0 ]]; then
        echo "Error: at least one pattern is required" >&2
        echo "Use --help for usage information" >&2
        return 1
    fi

    # Get list of worktrees (excluding the main worktree)
    local main_worktree=$(git worktree list --porcelain 2>/dev/null | grep -m1 "^worktree" | cut -d' ' -f2)
    if [[ -z "$main_worktree" ]]; then
        echo "Error: not in a git repository or no worktrees found" >&2
        return 1
    fi

    # Build list of worktree paths and names
    local -a worktree_paths=()
    local -a worktree_names=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
            local wt_path="${match[1]}"
            # Skip main worktree
            if [[ "$wt_path" != "$main_worktree" ]]; then
                worktree_paths+=("$wt_path")
                worktree_names+=("$(basename "$wt_path")")
            fi
        fi
    done < <(git worktree list --porcelain 2>/dev/null)

    if [[ ${#worktree_paths[@]} -eq 0 ]]; then
        echo "No worktrees found (excluding main repository)" >&2
        return 1
    fi

    # Find worktrees matching the patterns
    local -a to_remove=()
    for pattern in "${patterns[@]}"; do
        local found=false
        local idx=1
        for name in "${worktree_names[@]}"; do
            local wt_path="${worktree_paths[$idx]}"
            # Check if pattern matches the name (using glob matching)
            if [[ "$name" == $~pattern ]] || [[ "$wt_path" == $~pattern ]]; then
                # Avoid duplicates
                local already_added=false
                for existing in "${to_remove[@]}"; do
                    if [[ "$existing" == "$wt_path" ]]; then
                        already_added=true
                        break
                    fi
                done
                if [[ "$already_added" = false ]]; then
                    to_remove+=("$wt_path")
                fi
                found=true
            fi
            ((idx++))
        done
        if [[ "$found" = false ]]; then
            echo "Warning: no worktree matches pattern '$pattern'" >&2
        fi
    done

    if [[ ${#to_remove[@]} -eq 0 ]]; then
        echo "No worktrees matched the given patterns" >&2
        return 1
    fi

    # Show what will be removed
    echo "Worktrees to remove:"
    for wt in "${to_remove[@]}"; do
        echo "  - $wt"
    done

    if [[ "$DRY_RUN" = true ]]; then
        echo "(dry run - no worktrees were removed)"
        return 0
    fi

    # Confirm removal unless force flag is set
    if [[ "$FORCE" = false ]]; then
        local confirm_msg
        if [[ ${#to_remove[@]} -eq 1 ]]; then
            confirm_msg="Remove this worktree? [y/N] "
        else
            confirm_msg="Remove these ${#to_remove[@]} worktrees? [y/N] "
        fi
        echo -n "$confirm_msg"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Aborted."
            return 0
        fi
    fi

    # Remove each worktree
    local failed=0
    local force_flag=""
    if [[ "$FORCE" = true ]]; then
        force_flag="--force"
    fi

    for wt in "${to_remove[@]}"; do
        echo "Removing: $wt"
        if git worktree remove $force_flag "$wt"; then
            echo "  ✓ Removed successfully"
        else
            echo "  ✗ Failed to remove (use -f to force)" >&2
            ((failed++))
        fi
    done

    if [[ $failed -gt 0 ]]; then
        echo "$failed worktree(s) failed to remove" >&2
        return 1
    fi

    echo "All worktrees removed successfully"
}

# Alias with noglob so patterns like test-* don't get expanded by the shell
alias rmwt='noglob _rmwt'
