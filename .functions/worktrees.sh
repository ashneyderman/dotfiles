function mkwt() {
    local PATH_PREFIX=""
    local PATH_PREFIX_EXPLICIT=false
    local BRANCH=""
    local TARGET_PATH=""
    local NEW_WINDOW=false

    # Usage message
    local usage_msg="Usage: mkwt [OPTIONS] <path>

Create a git worktree with automatic branch handling.
On success, changes the current working directory to the new worktree
(unless -n/--new-window is given).

Arguments:
    path                Target path for the worktree (required)

Options:
    -b, --branch <name>     Branch name to checkout (default: same as path)
    -p, --path-prefix <dir> Path prefix for worktree (default: \$HOME/worktrees/<project>)
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

    # Default path prefix: $HOME/worktrees/<project_base>
    if [[ "$PATH_PREFIX_EXPLICIT" = false ]]; then
        local project_base=""
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            local main_worktree=$(git worktree list --porcelain 2>/dev/null | grep -m1 "^worktree" | cut -d' ' -f2)
            [[ -n "$main_worktree" ]] && project_base="$(basename "$main_worktree")"
        fi
        [[ -z "$project_base" ]] && project_base="$(basename "$(pwd)")"
        PATH_PREFIX="$HOME/worktrees/$project_base"
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

    # Decide how to materialize the branch in the new worktree
    local -a WT_ARGS=(--no-checkout)
    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        # Local branch exists, check it out as-is (preserve its tip)
        WT_ARGS+=("$FULL_PATH" "$BRANCH")
        echo "Branch '$BRANCH' exists locally, checking it out"
    elif git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
        # Remote branch exists, create local tracking branch from it
        WT_ARGS+=(--track -b "$BRANCH" "$FULL_PATH" "origin/$BRANCH")
        echo "Creating local branch '$BRANCH' tracking origin/$BRANCH"
    else
        # Branch doesn't exist anywhere, create new from current HEAD
        WT_ARGS+=(-b "$BRANCH" "$FULL_PATH")
        echo "Creating new branch '$BRANCH' from current HEAD"
    fi

    echo "Creating worktree at: $FULL_PATH"
    git worktree add "${WT_ARGS[@]}" || return 1

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

Create a git worktree, open the project in Zed, and move it to the next
empty workspace.

Supported window managers:
    - AeroSpace (macOS) via 'aerospace' CLI
    - COSMIC (Linux) via 'cos-cli'
If neither is available, the worktree is created and Zed is opened
without any workspace movement.

Arguments:
    path                Target path for the worktree (required)

Options:
    -b, --branch <name>     Branch name to checkout (default: same as path)
    -p, --path-prefix <dir> Path prefix for worktree (default: \$HOME/worktrees/<project>)
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

    # Detect window manager
    local WM=""
    if command -v aerospace >/dev/null 2>&1; then
        WM="aerospace"
    elif command -v cos-cli >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        WM="cosmic"
    fi

    # Find empty workspace
    local TARGET_WORKSPACE=""
    local TARGET_WORKSPACE_LABEL=""
    local COS_ZED_SNAPSHOT=""
    case "$WM" in
        aerospace)
            # Check workspaces 1-5 for an empty one
            for ws in {1..5}; do
                local window_count=$(aerospace list-windows --workspace "$ws" 2>/dev/null | wc -l | tr -d ' ')
                if [[ "$window_count" -eq 0 ]]; then
                    TARGET_WORKSPACE="$ws"
                    TARGET_WORKSPACE_LABEL="$ws"
                    echo "Found empty workspace: $TARGET_WORKSPACE_LABEL"
                    break
                fi
            done
            if [[ -z "$TARGET_WORKSPACE" ]]; then
                # No empty workspace found, use current one
                TARGET_WORKSPACE=$(aerospace list-workspaces --focused)
                TARGET_WORKSPACE_LABEL="$TARGET_WORKSPACE"
                echo "No empty workspace found, using current workspace: $TARGET_WORKSPACE_LABEL"
            fi
            ;;
        cosmic)
            # Snapshot existing Zed window titles so we can identify the new one later.
            # cos-cli matches --app-id with a partial, case-insensitive contains, so
            # if Zed is already running we cannot disambiguate by app-id alone.
            COS_ZED_SNAPSHOT=$(cos-cli info --json 2>/dev/null | jq -r '
                .apps[]
                | select((.app_id // "") | ascii_downcase | contains("zed"))
                | (.title // "")
            ' 2>/dev/null)

            # Find first empty workspace in group 0 (limit to first 5 to match aerospace behavior).
            # cos-cli's workspace --workspace flag wants the 0-based index; we display the 1-based name.
            local empty_info
            empty_info=$(cos-cli info --json 2>/dev/null | jq -r '
                . as $root
                | ($root.apps | map(.workspaces[] | select(.group_index == 0) | .index) | unique) as $occupied
                | ($root.workspace_groups[0].workspaces // [])[:5]
                | map(select((.index | tostring) as $i | ($occupied | map(tostring) | index($i)) | not))
                | .[0] // empty
                | "\(.index)\t\(.name)"
            ' 2>/dev/null)
            if [[ -n "$empty_info" ]]; then
                TARGET_WORKSPACE="${empty_info%%	*}"
                TARGET_WORKSPACE_LABEL="${empty_info##*	}"
                echo "Found empty workspace: $TARGET_WORKSPACE_LABEL (index $TARGET_WORKSPACE)"
            else
                echo "No empty workspace found in first 5; Zed will open on the current workspace"
            fi
            ;;
        *)
            echo "No supported window manager detected (aerospace, cos-cli); skipping workspace move"
            ;;
    esac

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

    # Move Zed to target workspace
    case "$WM" in
        aerospace)
            if [[ -n "$TARGET_WORKSPACE" ]]; then
                # Give Zed a moment to fully launch
                sleep 0.5

                echo "Moving Zed window to workspace $TARGET_WORKSPACE_LABEL..."
                aerospace move-node-to-workspace "$TARGET_WORKSPACE"

                echo "Switching to workspace $TARGET_WORKSPACE_LABEL..."
                aerospace workspace "$TARGET_WORKSPACE"
            fi
            ;;
        cosmic)
            if [[ -n "$TARGET_WORKSPACE" ]]; then
                # Poll cos-cli until a Zed window appears whose title is NOT in
                # the pre-launch snapshot — that's the one we just opened.
                local new_index=""
                local attempt
                for attempt in {1..20}; do
                    new_index=$(cos-cli info --json 2>/dev/null | jq -r --arg known "$COS_ZED_SNAPSHOT" '
                        ($known | split("\n") | map(select(length > 0))) as $known_titles
                        | .apps[]
                        | select((.app_id // "") | ascii_downcase | contains("zed"))
                        | (.title // "") as $t
                        | select(($known_titles | index($t)) | not)
                        | .index
                    ' 2>/dev/null | head -1)
                    [[ -n "$new_index" ]] && break
                    sleep 0.5
                done

                if [[ -n "$new_index" ]]; then
                    echo "Moving Zed window (index $new_index) to workspace $TARGET_WORKSPACE_LABEL..."
                    cos-cli move --index "$new_index" --workspace "$TARGET_WORKSPACE"

                    echo "Switching to workspace $TARGET_WORKSPACE_LABEL..."
                    cos-cli ws-activate --workspace "$TARGET_WORKSPACE"
                else
                    echo "Could not identify the new Zed window; leaving on current workspace"
                fi
            fi
            ;;
    esac

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
