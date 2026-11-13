# Troubleshooting

Messages you can hit in the DD103 labs that are not mistakes in your design, or that look worse
than they are. Each entry gives the symptom, the cause and the fix. Setup problems with Docker,
the desktop, `.designinit` or `mod` are on IC101's
[Troubleshooting](https://uoftasic.com/ic101/#/reference/troubleshooting) page, and Yosys parse
errors are on [When Yosys says syntax error](reference/yosys-syntax-errors.md).

## `show` says only one module must be selected

**Symptom:** In Lab 02, `show` stops with:

```
ERROR: For formats different than 'ps' or 'dot' only one module must be selected.
```

**Cause:** The `show` line is missing its module name. `show -format svg` draws exactly one
module. The error is confusing because the line that produced it looks like it selected nothing
at all.

**Fix:** End the `show` line with the module name, as both scripts in the Lab 02 package do.

## `sak-v2svg.sh` can't find Netlistsvg

**Symptom:** `sak-v2svg.sh` is on your `PATH` and its help text looks official, but it fails:

```
$ sak-v2svg.sh results/fulladder_sky130.v out.svg
[ERROR] Netlistsvg could not be found!
```

**Cause:** It wraps `netlistsvg`, which is not installed in the workbench and can't be, because
`npm` is not in the image.

**Fix:** Don't use it. `show` is built into Yosys and is what Lab 02 uses.

## Icarus wants an explicit cast

**Symptom:** In Lab 05, `make sim` stops with:

```
src/elevator.sv:89: error: This assignment requires an explicit cast.
```

**Cause:** Icarus rejects an enum assigned through a ternary, such as
`next = (a == b) ? DOORS : MOVING;`. Verilator accepts it and `iverilog -g2012` does not. It is
not a bug in your logic.

**Fix:** Write it as `if`/`else`, and both tools are happy.

## Verilator reads your comment as a directive

**Symptom:** In Lab 05, Verilator stops on a comment:

```
%Error-BADVLTPRAGMA: solutions/elevator.sv:12:1: Unknown verilator comment:
                     '/*verilator --lint-only -Wall -> exit 0*/'
```

**Cause:** A comment that starts with the word `verilator` is read as a directive aimed at
Verilator itself. It is not a bug in your logic.

**Fix:** Don't start a comment with the word `verilator`.

## WARNING lines after `make harden`

**Symptom:** In Lab 05, `make harden` ends with three `Passed ✅` lines and then about a dozen
`WARNING` lines, such as `'PNR_SDC_FILE' is not defined`, `found 2 floating nets` and
`LEF58_ENCLOSURE with no CUTCLASS is not supported`.

**Cause:** They are normal on a design with no SDC file and no power source location.

**Fix:** None needed; none of them is a failure. The three ✅ lines are the results that matter,
and Lab 05, Part 8 checks them properly.

## Re-running `make harden` with the same tag

**Symptom:** A second `make harden TAG=v1` prints `INFO Using existing run at 'v1'` and appends
stages 78, 79, 80… onto the finished run.

**Cause:** Re-running with the same tag does not start over. The result is confusing and doubles
the disk use.

**Fix:** Use a new tag every time: `make harden TAG=v2`. Don't reach for `--overwrite`; it
crashes with a Python traceback when `runs/` does not exist yet.

## Still stuck

Ask in the [team Discord](https://discord.gg/hrJnP5UsGz). [Getting
help](guide/getting-started.md#getting-help) says what to include.
