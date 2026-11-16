# DD103 — RTL on FPGAs & ASICs

Run the same SystemVerilog through an FPGA flow and an ASIC flow, and take an elevator controller from its state table to a chip layout that passes DRC and LVS.

The third course in the UofT ASIC Team digital track. The published docs live under `./docs` and
are served by GitHub Pages; the runnable lab packages live in `labs/`.

Org: [github.com/uoftasic](https://github.com/uoftasic)

## Live docs

**This course:** https://uoftasic.com/dd103/

**Education hub:** https://edu.uoftasic.com/

**Prerequisites:** [IC101](https://uoftasic.com/ic101/) then [DD102](https://uoftasic.com/dd102/), in that order.

Students start at the Course path table on the course home page, `docs/index.md`.

## Quick start

Every package under `labs/` runs with `make` alone in a bare container, with no environment setup
(no `.designinit`, no `mod`, no exported PDK variables), and Labs 01–04 exit 0. Lab 05 uses
LibreLane, so it needs the full workbench.

```bash
git clone https://github.com/uoftasic/dd103.git
cd dd103

docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/work" -w /work \
  hpretl/iic-osic-tools:2026.08 --skip \
  bash -c 'cd /work/labs/lab-01-one-adder-two-targets && make'
```

That `docker run` line is for maintainers checking a package. Students run the labs inside the
`workspace` desktop they set up in IC101.

Docs preview (requires [Quarto](https://quarto.org/docs/get-started/) 1.11):

```bash
quarto preview docs                            # -> http://localhost:4200
quarto render docs --profile pdf --to typst    # whole course as one PDF in docs/_book/
```

Courses that need IIC-OSIC-TOOLS and SKY130 document the team workbench setup in the course,
rather than bundling Docker in every repo.

## Layout

| Path | On Pages? | Purpose |
|------|-----------|---------|
| `docs/` | Yes | Quarto site (`docs/_quarto.yml`): home page with the Course path, guide pages, reference pages |
| `docs/guide/` | Yes | Guide pages: reading only, no required commands |
| `docs/labs/` | Yes | Lab writeups: the numbered steps students run |
| `labs/` | No | Runnable packages (HDL, Python, data, graders) |
| `scripts/` | No | Team utilities / automation |
| `notebooks/` | No | Exploratory / assignment notebooks |
| `data/`, `figures/` | No | Shared datasets / source figures |

## GitHub Pages

| Setting | Value |
|---------|--------|
| Source | GitHub Actions |

On every push to `main` that touches `docs/`, `.github/workflows/site.yml` renders `docs/` with
Quarto, adds the whole-course PDF, checks the rendered links with `scripts/check_site.py` and
deploys `docs/_site`. The site has a PDF of every page next to its HTML.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) — Copyright UofT ASIC Team / `uoftasic`
