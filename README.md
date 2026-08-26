# DD103 — RTL on FPGAs & ASICs

SystemVerilog in depth, and how the same RTL lowers differently to FPGA and ASIC.

The third course in the UofT ASIC Team **digital track**. Published docs live under `./docs` and are served by GitHub Pages; the runnable lab packages live in `labs/`.

Org: [github.com/uoftasic](https://github.com/uoftasic)

## Live docs

**This course:** https://uoftasic.com/dd103/

**Education hub:** https://edu.uoftasic.com/

**Prerequisites:** [IC101](https://uoftasic.com/ic101/) then [DD102](https://uoftasic.com/dd102/), in that order.

## Template provenance

DD103 was created from [uoftasic/course-template](https://github.com/uoftasic/course-template). The rest of this
section is the template's own bootstrap documentation, kept for maintainers.

1. On [uoftasic/course-template](https://github.com/uoftasic/course-template), click **Use this template** → create a repo named after the course id (e.g. `dd103`, `serdes-lab`).
2. Clone and bootstrap:

```bash
python3 scripts/init-template.py \
  --id dd103 \
  --title "DD103 — RTL on FPGAs & ASICs" \
  --description "SystemVerilog in depth, and how the same RTL lowers differently to FPGA and ASIC."
```

3. Enable **Settings → Pages → Deploy from a branch → `main` / `/docs`**.

See [TEMPLATE.md](TEMPLATE.md) for the checklist. Org is always `uoftasic` — only course id / title / description are filled in.

## Quick start

Every package under `labs/` runs with `make` alone, in a bare container, with no environment setup — no `.designinit`, no `mod`, no exported PDK variables. Labs 01–04 exit 0; Lab 05 uses LibreLane and needs the workbench proper.

```bash
git clone https://github.com/uoftasic/dd103.git
cd dd103

docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/work" -w /work \
  hpretl/iic-osic-tools:2026.04 --skip \
  bash -c 'cd /work/labs/lab-01-one-adder-two-targets && make'
```

Docs preview (requires Node.js):

```bash
npx docsify-cli serve docs      # -> http://localhost:3000
```

Tool-heavy courses that need IIC-OSIC-TOOLS / SKY130 should document the team workbench setup in-course rather than bundling Docker in every repo.

## Layout

| Path | On Pages? | Purpose |
|------|-----------|---------|
| `docs/` | **Yes** | Human-facing Docsify site |
| `docs/labs/` | Yes | Lab *writeups* (procedure, theory) |
| `labs/` | No | Runnable packages (HDL, Python, data, graders) |
| `scripts/` | No | Team utilities / automation |
| `notebooks/` | No | Exploratory / assignment notebooks |
| `data/`, `figures/` | No | Shared datasets / source figures |

## GitHub Pages

| Setting | Value |
|---------|--------|
| Source | Deploy from a branch |
| Branch | `main` |
| Folder | `/docs` |

No Actions deploy step is required for the baseline Docsify site.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) — Copyright UofT ASIC Team / `uoftasic`
