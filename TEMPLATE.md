# Template bootstrap (UofT ASIC)

Create a course or lab-notes repo from this template under `uoftasic`, fill in the three course
fields, and enable Pages.

## Fixed vs fillable

| Item | Value |
|------|--------|
| GitHub org | `uoftasic` (hardcoded; do not change) |
| Team | UofT ASIC Team |

| Token | Meaning | Example |
|-------|---------|---------|
| `dd103` | Repo slug / course id | `dd103`, `ic101`, `serdes-lab` |
| `DD103 — RTL on FPGAs & ASICs` | Display name | `DD103 — RTL on FPGAs & ASICs` |
| `SystemVerilog in depth, and how the same RTL lowers differently to FPGA and ASIC.` | One-line blurb | `RTL synthesis intro with Yosys` |

## Init script

```bash
python3 scripts/init-template.py \
  --id dd103 \
  --title "DD103 — RTL on FPGAs & ASICs" \
  --description "RTL on FPGAs and open-source ASIC flows"
```

For a dry run, add `--dry-run`.

## After-clone checklist

- [ ] Repo created under `uoftasic` with id matching `dd103`
- [ ] `scripts/init-template.py` run (or the three tokens replaced by hand)
- [ ] Pushed to `main`
- [ ] Pages: **Settings → Pages → `main` / `/docs`**
- [ ] Live: `https://uoftasic.com/<course-id>/` (org Pages; hub: https://edu.uoftasic.com/)
- [ ] Sidebar navigates Home → Getting started → Lab 01
- [ ] Math and the sample figure render on the home page
- [ ] (Maintainers of this template) **Settings → Template repository** enabled

## Naming

Prefer course ids the team already uses (`ic###`, `ad###`, `dd###`) or a clear kebab-case lab
name. Keep the GitHub repo name equal to `dd103` so Pages and clone URLs stay predictable.

## Related

Each course from this template publishes at `https://uoftasic.com/<course-id>/`, with Docsify docs
under `docs/` (no build step) and separate `labs/` and `scripts/` trees. The education hub is
https://edu.uoftasic.com/.
