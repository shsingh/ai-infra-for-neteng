{ lib
, writeShellScriptBin
, courseLibs
, kindbnkctl
, coreutils
, docker-client
}:

writeShellScriptBin "teardown" ''
  set -euo pipefail

  source "${courseLibs}/lib/course-libs.sh"

  announce "teardown" "Symmetric destroy of AI Infrastructure for Network Engineers lab environment"

  run_step "Tearing down Kubernetes cluster and fabric containers..."

  # 1. Clean up fabric spine container if running
  if command -v docker >/dev/null 2>&1; then
    if docker ps -a --format '{{.Names}}' | grep -E '^frr-spine$' >/dev/null 2>&1; then
      log_info "Removing frr-spine container..."
      docker rm -f frr-spine || true
      log_success "frr-spine container removed"
    else
      log_info "No frr-spine container detected"
    fi
  fi

  # 2. Destroy kind cluster via kindbnkctl if binary available and poc exists
  if [[ -d "$PWD/poc" ]] && command -v kindbnkctl >/dev/null 2>&1; then
    log_info "Running kindbnkctl destroy in poc workspace..."
    (cd "$PWD/poc" && kindbnkctl destroy || true)
  fi

  # 3. Clean up any kind cluster named bnk or poc
  if command -v kind >/dev/null 2>&1; then
    for cluster in bnk poc kind; do
      if kind get clusters 2>/dev/null | grep -E "^''${cluster}$" >/dev/null 2>&1; then
        log_info "Deleting kind cluster ''${cluster}..."
        kind delete cluster --name "''${cluster}" || true
      fi
    done
  fi

  # 4. Remove poc directory if present (preserving keys/)
  if [[ -d "$PWD/poc" ]]; then
    log_info "Cleaning up local poc/ workspace directory..."
    rm -rf "$PWD/poc"
  fi

  verify_step "Verifying complete teardown"
  if command -v docker >/dev/null 2>&1; then
    ACTIVE_CONTAINERS=$(docker ps --filter "name=bnk" --filter "name=frr-spine" --filter "name=kind" -q | wc -l || echo 0)
    if (( ACTIVE_CONTAINERS == 0 )); then
      log_success "All lab containers terminated"
    else
      log_warn "Some residual containers detected: $ACTIVE_CONTAINERS"
    fi
  fi

  expected_output "Teardown: COMPLETE
- kind cluster destroyed
- frr-spine container removed
- workspace reset to clean state"
''
