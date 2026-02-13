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

function _sso_token_valid() {
  local start_url="$1"
  local cache_dir="$HOME/.aws/sso/cache"

  [[ -d "$cache_dir" ]] || return 1

  local now_epoch
  now_epoch=$(date +%s)

  local files=("$cache_dir"/*.json(N))
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    local file_url file_expires
    file_url=$(grep -o '"startUrl"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | sed 's/"startUrl"[[:space:]]*:[[:space:]]*"//;s/"$//')
    [[ "$file_url" == "$start_url" ]] || continue
    file_expires=$(grep -o '"expiresAt"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | sed 's/"expiresAt"[[:space:]]*:[[:space:]]*"//;s/"$//')
    [[ -n "$file_expires" ]] || continue
    local expires_epoch
    if [[ "$(uname)" == "Darwin" ]]; then
      expires_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$file_expires" "+%s" 2>/dev/null) || continue
    else
      expires_epoch=$(date -u -d "$file_expires" "+%s" 2>/dev/null) || continue
    fi
    [[ "$expires_epoch" -gt "$now_epoch" ]] && return 0
  done
  return 1
}

function sso_login() {
  local force="$1"

  local profiles=()
  profiles=($(grep '^\[profile ' ~/.aws/config | sed 's/\[profile //;s/\]//'))

  if [[ ${#profiles[@]} -eq 0 ]]; then
    echo "No profiles found in ~/.aws/config"
    return 1
  fi

  echo "Available AWS profiles:"
  local i=1
  for p in "${profiles[@]}"; do
    echo "  $i) $p"
    ((i++))
  done

  echo ""
  read "choice?Select profile (1-${#profiles[@]}): "

  if [[ -z "$choice" ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#profiles[@]} ]]; then
    echo "Invalid selection"
    return 1
  fi

  local profile="${profiles[$choice]}"
  echo ""

  local start_url
  start_url=$(grep -A5 "^\[profile ${profile}\]" ~/.aws/config | grep sso_start_url | awk '{print $3}')

  if [[ "$force" != "1" ]] && _sso_token_valid "$start_url"; then
    echo "SSO token is still valid, skipping login (use --force-login to override)"
  else
    echo "Logging out of AWS SSO..."
    aws sso logout

    echo "Logging in with profile: $profile"
    aws sso login --profile "$profile"
  fi

  echo ""
  aws sts get-caller-identity --profile "$profile" --no-cli-pager
}

function skc() {
  local show_help=0
  local force_login=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help=1
        shift
        ;;
      -f|--force-login)
        force_login=1
        shift
        ;;
      *)
        echo "Unknown option: $1"
        return 1
        ;;
    esac
  done

  if [[ "$show_help" -eq 1 ]]; then
    echo "Usage: skc [options]"
    echo ""
    echo "Switch Kubernetes Context - performs AWS SSO re-login and switches kubectl context."
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -f, --force-login   Force SSO logout/login even if token is still valid"
    echo ""
    echo "Steps:"
    echo "  1. Prompts for an AWS profile and logs in via SSO (skipped if token is valid)"
    echo "  2. Prints the caller identity for the selected profile"
    echo "  3. Prompts for a Kubernetes context and switches to it"
    return 0
  fi

  sso_login "$force_login" || return 1

  echo ""
  local contexts=()
  contexts=($(kubectl config get-contexts -o name))

  if [[ ${#contexts[@]} -eq 0 ]]; then
    echo "No kubernetes contexts found"
    return 1
  fi

  echo "Available Kubernetes contexts:"
  local j=1
  for ctx in "${contexts[@]}"; do
    echo "  $j) $ctx"
    ((j++))
  done

  echo ""
  read "ctx_choice?Select context (1-${#contexts[@]}): "

  if [[ -z "$ctx_choice" ]] || [[ "$ctx_choice" -lt 1 ]] || [[ "$ctx_choice" -gt ${#contexts[@]} ]]; then
    echo "Invalid selection"
    return 1
  fi

  local context="${contexts[$ctx_choice]}"
  kubectl config use-context "$context"
}
