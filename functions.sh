function pdl() {
  if [[ -n "$1" ]]; then
    kubectl get pods | grep $1
  else
    kubectl get pods
  fi
}

function pdx() {
  if [[ -n "$2" ]]; then
    kubectl exec -it "$(kubectl get pods | grep $1 | awk 'NR==1{print $1}')" -- sh -c "$2"
  else
    kubectl exec -it "$(kubectl get pods | grep $1 | awk 'NR==1{print $1}')" -- bash
  fi
}

function pdfw() {
  kubectl port-forward "$(kubectl get pods | grep $1 | awk 'NR==1{print $1}')" "$2"
}

function mkwt() {
    local PATH_PREFIX=".worktrees"
    local BRANCH=""
    local TARGET_PATH=""

    # Usage message
    local usage_msg="Usage: mkwt [OPTIONS] <path>

Create a git worktree with automatic branch handling.

Arguments:
    path                Target path for the worktree (required)

Options:
    -b, --branch <name>     Branch name to checkout (default: same as path)
    -p, --path-prefix <dir> Path prefix for worktree (default: .worktrees)
    -h, --help              Display this help message

Examples:
    mkwt feature-x
    mkwt -b main feature-y
    mkwt --branch main feature-y
    mkwt -p ~/worktrees feature-z"

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

    # cd into target directory and checkout
    cd "$FULL_PATH" || return 1
    git checkout "$BRANCH" || return 1

    echo "Successfully created worktree at: $FULL_PATH"
    echo "Branch: $BRANCH"
}
