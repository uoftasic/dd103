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
| Adding a lab | `labs/<id>/` + `docs/labs/<id>-overview.md`, a Do row in the Course path, and a sidebar entry |
| Binaries | small images in `docs/assets/`; large data → Git LFS or external |

## Guide pages, labs and packages

- `docs/guide/` pages are for reading: concepts, figures and worked examples. They have no
  required commands. When a guide page needs the student to run something, the step goes in the
  matching lab writeup, and the guide page points to it.
- `docs/labs/` writeups are where students do things: before you start, a time estimate,
  numbered parts with numbered steps, a "you should see" check at the end of each part, and a
  finishing check.
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
