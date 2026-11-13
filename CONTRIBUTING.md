# Contributing

Thanks for improving materials for the UofT ASIC Team.

## After creating a course from this template

1. Run `scripts/init-template.py` with `--id`, `--title` and `--description` (the org is always `uoftasic`).
2. Enable GitHub Pages: branch `main`, folder `/docs`.
3. Prefer repo names that match course ids (`dd103`, `ic101`, …).

See [TEMPLATE.md](TEMPLATE.md).

## Placeholders

Only these three are fillable:

| Token | Example |
|-------|---------|
| `dd103` | `dd103` |
| `DD103 — RTL on FPGAs & ASICs` | `DD103 — RTL on FPGAs & ASICs` |
| `SystemVerilog in depth, and how the same RTL lowers differently to FPGA and ASIC.` | `RTL synthesis intro with Yosys` |

## Conventions

| Item | Convention |
|------|------------|
| Org | `uoftasic` |
| Default branch | `main` |
| Docs pages | kebab-case `.md` under `docs/` |
| Lab IDs | `lab-NN-short-name` |
| Adding a guide page | add `.md` under `docs/guide/`, add it to a Read row of the Course path in `docs/README.md`, and link it in `docs/_sidebar.md` in the same order |
| Adding a lab | `labs/<id>/` + `docs/labs/<id>-overview.md` titled `Lab NN: Title`, a Do row in the Course path (`[Lab NN: Title](...)`, then one sentence on what you'll do, then the time; update the course total), and a sidebar entry with the same title |
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
npx docsify-cli serve docs
```

## Pull requests

Keep changes focused. For doc-only PRs, check navigation and math locally when practical. Optional
CI may link-check `docs/**`.
