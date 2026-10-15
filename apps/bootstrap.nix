{ lib
, writeShellScriptBin
, courseLibs
, kindbnkctl
, coreutils
, gnugrep
, gawk
, docker-client
}:

writeShellScriptBin "bootstrap" ''
  set -euo pipefail

  source "${courseLibs}/lib/course-libs.sh"

  announce "bootstrap" "AI Infrastructure for Network Engineers lab bootstrap pipeline (PLAN §8.2)"

  OFFLINE=0
  BUNDLE_DIR=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --offline)
        OFFLINE=1
        shift
        ;;
      --bundle)
        BUNDLE_DIR="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        echo "Usage: nix run .#bootstrap [-- --offline --bundle <path>]" >&2
        exit 1
        ;;
    esac
  done

  run_step "1/4 Preflight verification (Host platform & sizing floor)"

  ARCH=$(uname -m)
  OS=$(uname -s)

  if [[ "$ARCH" != "x86_64" || "$OS" != "Linux" ]]; then
    log_warn "Host platform is $OS/$ARCH. Production lab requires linux/amd64 (AGENTS.md Rule 6)."
    if [[ "$ARCH" != "x86_64" ]]; then
      log_error "Architecture $ARCH is unsupported. F5 container images are linux/amd64 only."
      exit 1
    fi
  else
    log_success "Host platform verified: linux/amd64"
  fi

  # Core floor check
  NCPUS=0
  if command -v nproc >/dev/null 2>&1; then
    NCPUS=$(nproc)
  elif [[ "$OS" == "Darwin" ]]; then
    NCPUS=$(sysctl -n hw.ncpu 2>/dev/null || echo 0)
  fi

  if (( NCPUS < 12 )); then
    log_error "Host has $NCPUS CPU cores. Absolute minimum floor is 12 cores (PLAN §2)."
    exit 1
  fi
  log_success "CPU cores: $NCPUS (floor 12 cores satisfied)"

  # Memory floor check
  TOTAL_RAM_KB=0
  if [[ -f /proc/meminfo ]]; then
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  elif [[ "$OS" == "Darwin" ]]; then
    MEM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    TOTAL_RAM_KB=$(( MEM_BYTES / 1024 ))
  fi
  TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1024 / 1024 ))

  if (( TOTAL_RAM_GB < 28 )); then
    log_error "Host has ''${TOTAL_RAM_GB} GB RAM. Absolute minimum floor is 28 GB (PLAN §2)."
    exit 1
  fi
  log_success "RAM: ''${TOTAL_RAM_GB} GB (floor 28 GB satisfied)"

  # Disk floor check
  DISK_AVAIL_GB=$(df -k . | tail -1 | awk '{print int($4 / 1024 / 1024)}')
  if (( DISK_AVAIL_GB < 120 )); then
    log_error "Host has ''${DISK_AVAIL_GB} GB available disk. Floor is 120 GB (PLAN §2)."
    exit 1
  fi
  log_success "Disk space: ''${DISK_AVAIL_GB} GB free (floor 120 GB satisfied)"

  # Docker check
  if ! docker info >/dev/null 2>&1; then
    log_error "Docker daemon is unreachable. Start Docker before running bootstrap."
    exit 1
  fi
  log_success "Docker daemon is reachable"

  run_step "2/4 Nix installation check"
  if ! command -v nix >/dev/null 2>&1; then
    log_error "Nix is not found in PATH."
    echo "Install Determinate Nix: curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
    exit 1
  fi
  log_success "Nix package manager active"

  run_step "3/4 Keys check (FAR image-pull secret + license JWT)"
  KEYS_DIR="$PWD/keys"
  if [[ ! -d "$KEYS_DIR" ]]; then
    log_error "Keys directory '$KEYS_DIR' does not exist."
    echo "Per PLAN §8.2 step 3: Place the customer FAR tarball and operator JWT in keys/."
    echo "Consult FACILITATOR.md for credential acquisition and setup."
    exit 1
  fi

  TAR_COUNT=$(find "$KEYS_DIR" -maxdepth 1 -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.tgz" \) | wc -l || echo 0)
  JWT_COUNT=$(find "$KEYS_DIR" -maxdepth 1 -type f \( -name "*.jwt" -o -name "*jwt*" \) | wc -l || echo 0)

  if (( TAR_COUNT == 0 || JWT_COUNT == 0 )); then
    log_error "Credentials missing in '$KEYS_DIR'. Found $TAR_COUNT tarball(s) and $JWT_COUNT JWT(s)."
    echo "Per PLAN §8.2 step 3: Both the FAR image-pull secret tarball and the operator license JWT must be present in keys/."
    echo "Consult FACILITATOR.md for details."
    exit 1
  fi
  log_success "Credentials verified in keys/ (TAR + JWT present)"

  if (( OFFLINE == 1 )); then
    log_info "Offline mode enabled. Bundle path: ''${BUNDLE_DIR:-default}"
  fi

  run_step "4/4 Cluster deployment skeleton (Stage 1)"
  log_info "Preflight, Nix, and Keys verification complete."
  log_info "Full kindbnkctl 2.4.0 cluster deployment is executed in Stage 2."

  verify_step "Verifying preflight and readiness state"
  log_success "Stage 1 bootstrap preflight assertions completed successfully."

  expected_output "Bootstrap Preflight: PASSED
- Host floor: linux/amd64, >=12c, >=28GB RAM, >=120GB disk
- Docker: reachable
- Nix: installed
- Credentials: keys/ populated
- Stage: Stage 1 skeleton ready for Stage 2 cluster init"
''
