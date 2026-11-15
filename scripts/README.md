# Scripts

Utilities for DD103 — RTL on FPGAs & ASICs under the UofT ASIC org (`uoftasic`).

## Entry points

| Script | Purpose |
|--------|---------|
| `hello.py` | Smoke-check that Python runs in this clone |
| `init-template.py` | Fill `dd103` / title / description after using the template |
| `check_site.py` | After `quarto render docs`, list every local link, image and `#anchor` in `docs/_site` that doesn't resolve: `python3 scripts/check_site.py docs/_site`. It exits 0 even when it finds some, so read the output |

## Usage

```bash
# From repo root
python3 scripts/hello.py

python3 scripts/init-template.py \
  --id dd103 \
  --title "DD103 — RTL on FPGAs & ASICs" \
  --description "RTL on FPGAs and open-source ASIC flows"
```

## Conventions

- Prefer Python; HDL tooling belongs in `labs/` or the shared workbench.
- No secrets in the repo; use `.env.example` if configuration is needed.
- Document new scripts here when you add them.
