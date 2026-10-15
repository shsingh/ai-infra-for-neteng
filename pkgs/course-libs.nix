{ lib
, stdenv
, makeWrapper
, kubectl
, jq
, coreutils
}:

stdenv.mkDerivation {
  pname = "course-libs";
  version = "1.0.0";

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib

    cat <<'EOF' > $out/lib/course-libs.sh
    #!/usr/bin/env bash
    set -euo pipefail

    # ANSI Color codes
    C_RESET='\033[0m'
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[0;33m'
    C_BLUE='\033[0;34m'
    C_CYAN='\033[0;36m'
    C_BOLD='\033[1m'

    log_info() {
      echo -e "''${C_CYAN}[INFO]''${C_RESET} $*"
    }

    log_success() {
      echo -e "''${C_GREEN}[OK]''${C_RESET} $*"
    }

    log_warn() {
      echo -e "''${C_YELLOW}[WARN]''${C_RESET} $*" >&2
    }

    log_error() {
      echo -e "''${C_RED}[ERROR]''${C_RESET} $*" >&2
    }

    # AGENTS.md Rule 7 Contract helpers:
    # 1. Announce what will be done and why
    announce() {
      local title="$1"
      local purpose="$2"
      echo -e "\n''${C_BOLD}''${C_BLUE}=== [1/4 ANNOUNCE] ''${title} ===''${C_RESET}"
      echo -e "Purpose: ''${purpose}\n"
    }

    # 2. Run action message
    run_step() {
      local step_msg="$1"
      echo -e "''${C_BOLD}=== [2/4 RUN] ''${step_msg} ===''${C_RESET}"
    }

    # 3. Verify against running state
    verify_step() {
      local verify_msg="$1"
      echo -e "\n''${C_BOLD}=== [3/4 VERIFY] ''${verify_msg} ===''${C_RESET}"
    }

    # 4. Print expected output block
    expected_output() {
      local expected_text="$1"
      echo -e "\n''${C_BOLD}''${C_GREEN}=== [4/4 EXPECTED OUTPUT] ===''${C_RESET}"
      echo -e "''${expected_text}"
      echo -e "''${C_BOLD}''${C_GREEN}=============================''${C_RESET}\n"
    }
    EOF

    cat <<'EOF' > $out/bin/wait-for-status
    #!/usr/bin/env bash
    set -euo pipefail

    # wait-for-status <resource_type> <name> <namespace> <jsonpath> <expected_value> [timeout_seconds] [poll_interval_seconds]
    RESOURCE_TYPE="''${1:-}"
    RESOURCE_NAME="''${2:-}"
    NAMESPACE="''${3:-}"
    JSONPATH="''${4:-}"
    EXPECTED_VALUE="''${5:-}"
    TIMEOUT="''${6:-300}"
    INTERVAL="''${7:-3}"

    if [[ -z "$RESOURCE_TYPE" || -z "$RESOURCE_NAME" || -z "$JSONPATH" || -z "$EXPECTED_VALUE" ]]; then
      echo "Usage: wait-for-status <resource_type> <resource_name> <namespace|-> <jsonpath> <expected_value> [timeout_seconds] [poll_interval]" >&2
      exit 2
    fi

    NS_FLAG=()
    if [[ -n "$NAMESPACE" && "$NAMESPACE" != "-" && "$NAMESPACE" != "default" ]]; then
      NS_FLAG=("-n" "$NAMESPACE")
    fi

    echo "[WAIT] Waiting for $RESOURCE_TYPE/$RESOURCE_NAME in namespace '$NAMESPACE' ($JSONPATH == '$EXPECTED_VALUE') up to ''${TIMEOUT}s..."

    START_TIME=$(date +%s)
    LAST_PROGRESS=$START_TIME

    while true; do
      CURRENT_TIME=$(date +%s)
      ELAPSED=$(( CURRENT_TIME - START_TIME ))

      if (( ELAPSED > TIMEOUT )); then
        echo -e "\n[TIMEOUT] Timed out after ''${TIMEOUT}s waiting for $RESOURCE_TYPE/$RESOURCE_NAME" >&2
        echo "=== Current resource state ===" >&2
        kubectl get "$RESOURCE_TYPE" "$RESOURCE_NAME" "''${NS_FLAG[@]}" -o yaml || true
        echo "=== Resource describe ===" >&2
        kubectl describe "$RESOURCE_TYPE" "$RESOURCE_NAME" "''${NS_FLAG[@]}" || true
        exit 1
      fi

      ACTUAL_VALUE=$(kubectl get "$RESOURCE_TYPE" "$RESOURCE_NAME" "''${NS_FLAG[@]}" -o "jsonpath={$JSONPATH}" 2>/dev/null || echo "")

      if [[ "$ACTUAL_VALUE" == "$EXPECTED_VALUE" ]]; then
        echo -e "\n[OK] $RESOURCE_TYPE/$RESOURCE_NAME condition met in ''${ELAPSED}s: $JSONPATH == $EXPECTED_VALUE"
        exit 0
      fi

      # Progress output every 30 seconds per PLAN §8.3
      if (( CURRENT_TIME - LAST_PROGRESS >= 30 )); then
        echo "[PROGRESS] Still waiting... (elapsed ''${ELAPSED}s, current value: '$ACTUAL_VALUE', target: '$EXPECTED_VALUE')"
        LAST_PROGRESS=$CURRENT_TIME
      fi

      sleep "$INTERVAL"
    done
    EOF

    chmod +x $out/bin/wait-for-status

    wrapProgram $out/bin/wait-for-status \
      --prefix PATH : ${lib.makeBinPath [ kubectl jq coreutils ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Shared shell library and helpers for AI Infrastructure for Network Engineers lab apps";
    license = licenses.asl20;
    platforms = platforms.all;
  };
}
