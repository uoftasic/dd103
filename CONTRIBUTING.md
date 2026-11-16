# Contributing

Thanks for improving materials for the UofT ASIC Team.

## After creating a course from this template

1. Run `scripts/init-template.py` with `--id`, `--title` and `--description` (the org is always `uoftasic`).
2. Enable GitHub Pages with the source set to "GitHub Actions", so that
   `.github/workflows/site.yml` can build `docs/` with Quarto and deploy it.
3. Prefer repo names that match course ids (`dd103`, `ic101`, …).

See [TEMPLATE.md](TEMPLATE.md).

## Placeholders

Only these three are fillable:

| Token | Example |
|-------|---------|
| `dd103` | `dd103` |
| `DD103 — RTL on FPGAs & ASICs` | `DD103 — RTL on FPGAs & ASICs` |
| `Run the same SystemVerilog through an FPGA flow and an ASIC flow, and take an elevator controller from its state table to a chip layout that passes DRC and LVS.` | `RTL synthesis intro with Yosys` |

## Conventions

| Item | Convention |
|------|------------|
| Org | `uoftasic` |
| Default branch | `main` |
| Docs pages | kebab-case `.md` under `docs/` |
| Lab IDs | `lab-NN-short-name` |
| Adding a guide page | add `.md` under `docs/guide/`, add it to a Read row of the Course path in `docs/index.md`, and add it to the sidebar in `docs/_quarto.yml` and the chapters in `docs/_quarto-pdf.yml` in the same order |
| Adding a lab | `labs/<id>/` + `docs/labs/<id>-overview.md` titled `Lab NN: Title`, a Do row in the Course path (`[Lab NN: Title](...)`, then one sentence on what you'll do, then the time; update the course total), a sidebar entry in `docs/_quarto.yml` with the same title, and a chapter in `docs/_quarto-pdf.yml` |
| Links between pages | relative to the page they are written in (`../guide/x.md` from a lab) |
| Binaries | small images in `docs/assets/`; large data → Git LFS or external |

## Guide pages, labs and packages

- `docs/guide/` pages are for reading: concepts, figures and worked examples. They have no
  required commands. When a guide page needs the student to run something, the step goes in the
  matching lab writeup, and the guide page points to it.
- `docs/labs/` writeups are where students do things: before you start, a time estimate,
  numbered parts with numbered steps, each opening with the question it answers and ending in a
  "you should see" check, and at least one part where the student produces something. Questions
  sit at the step where they arise, with a collapsed `<details>` answer. Optional parts go at the
  end, marked "(optional)". Every lab ends with Finishing (You're done when, Questions, Submit),
  then Going further (optional) and a "Next on the Course path" line. `AGENTS.md` has the full
  shape.
- `labs/<id>/` is runnable HDL, Python and data. Each `labs/<id>/README.md` is short: a link to
  the writeup, how to run, the make targets and the file list.
- `scripts/` holds utilities; list entry points in `scripts/README.md`.

Don't put grades, solution keys or PII under `docs/`. Put them in `labs/**/solutions/` and
gitignore them on student forks when needed.

## Local docs preview

```bash
quarto preview docs
```

The preview runs at http://localhost:4200.

## Pull requests

Keep changes focused. For doc-only PRs, check navigation and math in the local preview when you
can. On every pull request that touches `docs/**`, `.github/workflows/site.yml` renders the site
and the course PDF and runs `scripts/check_site.py` on the result, which lists every local
link or `#anchor` that doesn't resolve. Read its output in the build log: the script exits 0 even
when it finds broken links, so a green build doesn't mean there were none. `.github/workflows/docs-link-check.yml` also checks the
links in `docs/**/*.md`, including external ones, and that every image a page references exists.
