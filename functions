function kgpg() {
  kubectl get pods | grep "$1"
}

function kex() {
  if [[ -n "$2" ]]; then
    kubectl exec -it "$(kubectl get pods | grep $1 | awk 'NR==1{print $1}')" -- sh -c "$2"
  else
    kubectl exec -it "$(kubectl get pods | grep $1 | awk 'NR==1{print $1}')" -- bash
  fi
}

function kpf() {
  kubectl port-forward "$(kubectl get pods | grep $1 | awk 'NR==1{print $1}')" "$2"
}
