# Security Policy

## Reporting a vulnerability

Report security issues in this lab repository to the repository owner via GitHub's
private vulnerability reporting:
[Report a vulnerability](https://github.com/shsingh/ai-infra-for-neteng/security/advisories/new).
Do not open a public issue for a security problem.

Include a description of the issue, steps to reproduce, and the affected commit. Reports
are triaged within a few days; accepted issues receive a fix or a documented mitigation.

## Scope

- Credential handling: `apps/bootstrap.nix` key checks, `keys/` exclusion rules, and the
  secret-scanning configuration.
- The fault-injection apps: `apps/break-fix.nix` and module fault implementations —
  verify they cannot affect the host outside the lab cluster.
- Image provenance: pinned digests for external images ([the pin set](PLAN.md#5-version-pins)).

Out of scope for this repo (upstream product security): the F5 platform itself and its
CRDs — report those through F5's Product Security incident process.
