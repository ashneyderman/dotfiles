# Source all function files from .functions directory
FUNCTIONS_DIR="${HOME}/.functions"

[ -f "${FUNCTIONS_DIR}/path.sh" ] && source "${FUNCTIONS_DIR}/path.sh"
[ -f "${FUNCTIONS_DIR}/k8s.sh" ] && source "${FUNCTIONS_DIR}/k8s.sh"
[ -f "${FUNCTIONS_DIR}/worktrees.sh" ] && source "${FUNCTIONS_DIR}/worktrees.sh"
