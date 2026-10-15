{ pkgs
, kindbnkctl
, courseLibs
}:

pkgs.mkShell {
  name = "ai-infra-neteng-shell";

  packages = [
    kindbnkctl
    courseLibs
    pkgs.kind
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.jq
    pkgs.yq-go
    pkgs.git
  ];

  shellHook = ''
    export KUBECONFIG="''${KUBECONFIG:-$PWD/poc/kubeconfig}"
    export PS1="\[\033[1;36m\](ai-infra-neteng)\[\033[0m\] \w \$ "

    echo "==========================================================="
    echo "  AI Infrastructure for Network Engineers — Lab Shell"
    echo "  KUBECONFIG: $KUBECONFIG"
    echo "  Tools: kind, kubectl, helm, jq, yq, git, kindbnkctl"
    echo "==========================================================="
  '';
}
