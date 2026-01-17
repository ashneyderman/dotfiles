# Helper function to add directory to PATH only if it exists
prepend_path() {
  [[ -d "$1" ]] && export PATH="$1:$PATH"
}
add_path() {
  [[ -d "$1" ]] && export PATH="$PATH:$1"
}
