{ lib
, writeShellScriptBin
, courseLibs
, coreutils
, gawk
, gnugrep
, docker-client
, kubectl
}:

writeShellScriptBin "doctor" ''
  set -euo pipefail

  source "${courseLibs}/lib/course-libs.sh"

  announce "doctor" "Environment health check and preflight audit for AI Infrastructure for Network Engineers lab"

  run_step "Auditing host platform, resources, container engine, and Kubernetes/BNK state..."

  FAILURES=0
  WARNINGS=0

  check_pass() {
    echo -e "  [PASS] $*"
  }

  check_warn() {
    echo -e "  ''${C_YELLOW}[WARN]''${C_RESET} $*"
    WARNINGS=$(( WARNINGS + 1 ))
  }

  check_fail() {
    echo -e "  ''${C_RED}[FAIL]''${C_RESET} $*"
    FAILURES=$(( FAILURES + 1 ))
  }

  echo "=== 1. Host Architecture & Operating System ==="
  ARCH=$(uname -m)
  OS=$(uname -s)

  if [[ "$OS" == "Linux" && "$ARCH" == "x86_64" ]]; then
    check_pass "Host platform is linux/amd64 (OS: $OS, Arch: $ARCH)"
  else
    if [[ "$ARCH" != "x86_64" ]]; then
      check_fail "Host architecture is '$ARCH' (x86_64/amd64 required per AGENTS.md Rule 6)"
    fi
    if [[ "$OS" != "Linux" ]]; then
      check_warn "Host OS is '$OS' (Linux required for production lab; emulation/macOS active)"
    fi
  fi

  echo -e "\n=== 2. Host Sizing Floor (12c / 28 GB RAM / 120 GB Disk floor) ==="
  # CPU cores
  NCPUS=0
  if command -v nproc >/dev/null 2>&1; then
    NCPUS=$(nproc)
  elif [[ "$OS" == "Darwin" ]]; then
    NCPUS=$(sysctl -n hw.ncpu 2>/dev/null || echo 0)
  fi

  if (( NCPUS >= 16 )); then
    check_pass "CPU cores: $NCPUS (>= 16 recommended)"
  elif (( NCPUS >= 12 )); then
    check_pass "CPU cores: $NCPUS (>= 12 floor met, 16 recommended)"
  else
    check_fail "CPU cores: $NCPUS is below the absolute floor of 12 cores (PLAN §2)"
  fi

  # Total RAM
  TOTAL_RAM_KB=0
  if [[ -f /proc/meminfo ]]; then
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  elif [[ "$OS" == "Darwin" ]]; then
    MEM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    TOTAL_RAM_KB=$(( MEM_BYTES / 1024 ))
  fi
  TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1024 / 1024 ))

  if (( TOTAL_RAM_GB >= 32 )); then
    check_pass "RAM: ''${TOTAL_RAM_GB} GB (>= 32 GB recommended)"
  elif (( TOTAL_RAM_GB >= 28 )); then
    check_pass "RAM: ''${TOTAL_RAM_GB} GB (>= 28 GB floor met, 32 GB recommended)"
  else
    check_fail "RAM: ''${TOTAL_RAM_GB} GB is below the absolute floor of 28 GB (PLAN §2)"
  fi

  # Available disk space
  DISK_AVAIL_GB=$(df -k . | tail -1 | awk '{print int($4 / 1024 / 1024)}')
  if (( DISK_AVAIL_GB >= 160 )); then
    check_pass "Disk available: ''${DISK_AVAIL_GB} GB (>= 160 GB recommended)"
  elif (( DISK_AVAIL_GB >= 120 )); then
    check_pass "Disk available: ''${DISK_AVAIL_GB} GB (>= 120 GB floor met, 160 GB recommended)"
  else
    check_fail "Disk available: ''${DISK_AVAIL_GB} GB is below the 120 GB floor (PLAN §2)"
  fi

  echo -e "\n=== 3. Container Engine (Docker) ==="
  if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      DOCKER_VER=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "running")
      check_pass "Docker engine running (Server version: $DOCKER_VER)"
    else
      check_fail "Docker CLI found but Docker daemon is unreachable"
    fi
  else
    check_fail "Docker CLI not found in PATH"
  fi

  echo -e "\n=== 4. Cluster & BIG-IP Next for Kubernetes (BNK) ==="
  KUBECONFIG_PATH="''${KUBECONFIG:-$HOME/.kube/config}"
  if [[ -f "$PWD/poc/kubeconfig" ]]; then
    KUBECONFIG_PATH="$PWD/poc/kubeconfig"
  fi

  CLUSTER_RUNNING=0
  if command -v kubectl >/dev/null 2>&1; then
    if KUBECONFIG="$KUBECONFIG_PATH" kubectl cluster-info >/dev/null 2>&1; then
      CLUSTER_RUNNING=1
      check_pass "Kubernetes cluster reachable via KUBECONFIG=$KUBECONFIG_PATH"

      # Check nodes
      NOT_READY_NODES=$(KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready" | wc -l || echo 0)
      if [[ "$NOT_READY_NODES" -eq 0 ]]; then
        check_pass "All Kubernetes nodes Ready"
      else
        check_warn "Some Kubernetes nodes are NotReady"
      fi

      # Check TMM pods if present
      TMM_PODS=$(KUBECONFIG="$KUBECONFIG_PATH" kubectl get pods -A -l app=f5-tmm --no-headers 2>/dev/null | wc -l || echo 0)
      if [[ "$TMM_PODS" -gt 0 ]]; then
        check_pass "TMM pods detected ($TMM_PODS instances)"
      else
        check_warn "No TMM pods detected (bootstrap not yet executed)"
      fi
    else
      echo "  [INFO] Kubernetes cluster not yet created (run 'nix run .#bootstrap' to provision)"
    fi
  else
    echo "  [INFO] kubectl not available in ambient PATH (use 'nix develop' or flake app)"
  fi

  verify_step "Evaluating doctor summary"

  if (( FAILURES > 0 )); then
    echo -e "''${C_RED}Doctor audit found $FAILURES failure(s) and $WARNINGS warning(s). Environment floor not met.''${C_RESET}"
    exit 1
  elif (( WARNINGS > 0 )); then
    echo -e "''${C_YELLOW}Doctor audit passed host floor with $WARNINGS warning(s). Ready for bootstrap.''${C_RESET}"
  else
    echo -e "''${C_GREEN}Doctor green board! Host platform and environment floor verified.''${C_RESET}"
  fi

  expected_output "Host platform: linux/amd64
CPU floor: >= 12 cores
RAM floor: >= 28 GB
Disk floor: >= 120 GB
Docker: reachable
Cluster/BNK: healthy (when deployed)"
''
