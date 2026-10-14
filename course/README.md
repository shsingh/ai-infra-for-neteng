# Course — The System of Record for Content

This directory is the authoritative content source for the course: the case study, the
teaching model, and the step-by-step module script. Everything student-facing
(`docs/labs/*.md`) and facilitator-facing (`FACILITATOR.md`) derives from these files in
combination with captured outputs (`docs/expected/`).

## Read order for a build agent

1. `AGENTS.md` (repo contract) and `PLAN.md` (build plan: what to build, pins, gates).
2. `course/case-study.md` — the Meridian University narrative every module sits inside.
3. `course/planes-and-analogies.md` — the teaching model: the three-planes spine, the
   LTM/Kubernetes concept-mapping tables, and the known cognitive traps of this audience.
4. `course/modules/m01.md` … `m13.md` — the module script: narrative beat, lecture targets,
   hands-on steps, verification, break-fix drill, planes check, guide mapping.

## Why this exists

An infrastructure plan can say *what* to build (manifests, apps, fabric). Students and the
facilitator need *why* and *in what order the learning happens*: the work order that motivates
each module, the analogies that make Kubernetes land for a device-oriented audience, and the
one request's journey across all three planes. Those live here, in markdown, versioned with
the code — not in an external document.

## Relationship to the lab guides

- `course/modules/mXX.md` defines the learning contract for module XX.
- `docs/labs/labXX.md` renders that contract into the task-based guide format, with every
  expected output taken from a captured run under `docs/expected/` (never from this source
  alone).
- A change to a module file is a content change; a change to a capture is a behavior
  change. Both travel through review.
