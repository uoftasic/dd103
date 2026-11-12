# Agent guide — UofT ASIC course repos

This is a course repository for the UofT ASIC Team (`uoftasic`): teaching materials for IC, RTL,
FPGA and open-source ASIC flows. The site under `docs/` is published on GitHub Pages (Docsify, no
build step). Runnable work lives outside `docs/`.

Optimize for clear student learning paths, not template maintenance. Prefer concrete labs and
notes students can follow end to end over meta documentation.

## Goals

- Teach IC development skills: RTL (SystemVerilog/Verilog), simulation, synthesis, FPGA bring-up,
  and open ASIC flows (Yosys, LibreLane, SKY130) as the course requires.
- Give students one answer to "what do I do next?": the numbered Course path table on
  `docs/README.md`, where each row is either Read (guide pages) or Do (one lab).
- Separate what students read (`docs/guide/`) from what they do (`docs/labs/` writeups, which run
  the packages in `labs/`).
- Never publish grades, solution keys or PII under `docs/`. Put keys in `labs/**/solutions/` and
  gitignore them on student forks when policy requires.

## Layout (keep it)

| Path | Published? | Put here |
|------|------------|----------|
| `docs/README.md` | Yes | Home page: who the course is for, prerequisites, total time, the Course path |
| `docs/guide/` | Yes | Guide pages: concepts, figures, worked examples. No required commands |
| `docs/labs/` | Yes | Lab writeups only (`lab-NN-*-overview.md`) |
| `docs/reference/` | Yes | Lookup pages: tables and short entries |
| `docs/assets/img/` | Yes | Small diagrams / waveforms for docs |
| `labs/<lab-id>/` | No | HDL, Python, testbenches, local data, graders |
| `scripts/` | No | Course utilities / automation |
| `notebooks/` | No | Exploratory or assignment notebooks |
| `data/`, `figures/` | No | Shared datasets / source figures |

Site wiring: `docs/index.html`, `docs/_sidebar.md`, `docs/_navbar.md`. Keep `_sidebar.md` in the
same order as the Course path. Math: `$inline$`, `$$display$$`.

## Adding a lab

Lab IDs: `lab-NN-short-name` (for example `lab-02-rtl-becomes-gates`).

1. Create `labs/<lab-id>/` with at least:
   - `README.md`: a link to the Docsify writeup, how to run, the make targets table, the file list
   - `src/`: HDL / Python / entry points
   - `data/`: small inputs (large binaries → Git LFS or external)
   - `requirements.txt` or tool notes when needed
2. Add `docs/labs/<lab-id>-overview.md` with: what you'll build or measure (2–3 lines), before you
   start (guide pages to read first, setup), a time estimate, numbered parts with numbered steps,
   each part ending in a concrete "you should see" check, and a finishing section (how to check
   you're done, what to submit if anything).
3. Add a Do row to the Course path in `docs/README.md`, and link the writeup from
   `docs/_sidebar.md` in the same position.
4. Cross-link: writeup → GitHub `labs/<lab-id>/`; package README → `docs/labs/<lab-id>-overview.md`.

Writeups are where students do things; packages execute. Don't paste long HDL into Docsify pages;
reference files under `labs/`.

## Adding a guide page

1. Add kebab-case Markdown under `docs/guide/` (for example `yosys-synth.md`).
2. Keep it reading-only. If the student should run or build something, put that step in the
   matching lab writeup and leave a one-line pointer in the guide page. Short pencil-and-paper
   "Check yourself" questions are fine at the end.
3. Add it to a Read row of the Course path and to `docs/_sidebar.md`.
4. Images go under `docs/assets/img/` with paths relative to `docs/`.
5. Use relative Docsify links between pages, and GitHub URLs for `labs/` and `scripts/`.

## Pedagogy checklist

- State what students will build or measure in their own terms ("You'll synthesize a counter and
  inspect the netlist").
- Assume a clone of this repo and the course's documented workbench; don't bundle Docker in every
  lab unless the course already does.
- For EDA-heavy work (LibreLane / SKY130 / IIC-OSIC-TOOLS), document the team workbench steps in
  the course rather than inventing a one-off container setup.
- Keep procedures copy-pasteable (`cd`, install, simulate/synth, check artifact).
- End every lab part with an expected result (printout, waveform check, area/timing ballpark,
  golden hash) so students know they succeeded.
- Increase difficulty across labs, and reuse naming and directory conventions so later labs feel
  familiar.
- Prefer small, inspectable designs over opaque blobs. When using IP or PDK artifacts, keep
  secrets and huge binaries out of git.

## Tooling norms

- Python helpers and graders go under `labs/<id>/src/` or `scripts/`; list entry points in the
  nearest `README.md`.
- SystemVerilog/Verilog goes under `labs/<id>/src/` (or `rtl/` and `tb/` if you split; stay
  consistent within the course).
- Heavy outputs (GDS, large FSDB/VCD, PDK caches) go in a local `results/` or LFS, never under
  `docs/`.
- Preview docs locally: `npx docsify-cli serve docs` → http://localhost:3000

## What not to do

- Don't add maintainer-only pages to the published site (contributing guides, template notes,
  notation stubs "for debugging").
- Don't put solution keys or rubrics in `docs/`.
- Don't replace student-facing content with template or bootstrap instructions. Point people at
  `CONTRIBUTING.md` / `TEMPLATE.md` only when they are bootstrapping or changing repo conventions.
- Don't change org assumptions: the GitHub org is `uoftasic`, and the course id matches the repo
  name.

## Quick references

- Repo conventions: `CONTRIBUTING.md`
- Bootstrap tokens / Pages checklist: `TEMPLATE.md`
- Sample lab: `labs/lab-01-one-adder-two-targets/` + `docs/labs/lab-01-one-adder-two-targets-overview.md`
