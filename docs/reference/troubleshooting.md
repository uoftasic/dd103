# Troubleshooting

This page collects the messages you can run into in the DD103 labs that aren't caused by a
mistake in your design, or that look worse than they are. Each entry gives the symptom, the cause
and the fix. Setup problems with Docker, the desktop, `.designinit` or `mod` are on IC101's
[Troubleshooting](https://uoftasic.com/ic101/reference/troubleshooting.html) page, and Yosys parse
errors are on [When Yosys says syntax error](../reference/yosys-syntax-errors.md).

## `show` says only one module must be selected

**Symptom:** In Lab 02, `show` stops with:

```
ERROR: For formats different than 'ps' or 'dot' only one module must be selected.
```

**Cause:** The `show` line is missing its module name. `show -format svg` draws exactly one
module, so it has to be told which one. The error is confusing, because the line that produced it
looks as if it didn't select anything at all.

**Fix:** End the `show` line with the module name, as both scripts in the Lab 02 package do.

## `sak-v2svg.sh` can't find Netlistsvg

**Symptom:** `sak-v2svg.sh` is on your `PATH` and its help text looks official, but when you
run it, it fails:

```
$ sak-v2svg.sh results/fulladder_sky130.v out.svg
[ERROR] Netlistsvg could not be found!
```

**Cause:** The script is a wrapper around `netlistsvg`, which isn't installed in the workbench.
It can't be installed there either, because `npm` isn't in the image.

**Fix:** Don't use it. Lab 02 draws its diagrams with `show` instead, which is built into Yosys.

## Icarus wants an explicit cast

**Symptom:** In Lab 05, `make sim` stops with:

```
src/elevator.sv:89: error: This assignment requires an explicit cast.
```

**Cause:** Icarus rejects an enum assigned through a ternary, such as
`next = (a == b) ? DOORS : MOVING;`. Verilator accepts the same line but `iverilog -g2012`
doesn't, so the error comes from a difference between the two tools, not from a bug in your
logic.

**Fix:** Write the assignment as an `if`/`else` instead, and both tools accept it.

## Verilator reads your comment as a directive

**Symptom:** In Lab 05, Verilator stops on a comment:

```
%Error-BADVLTPRAGMA: solutions/elevator.sv:12:1: Unknown verilator comment:
                     '/*verilator --lint-only -Wall -> exit 0*/'
```

**Cause:** Verilator reads any comment that starts with the word `verilator` as a directive
aimed at Verilator itself, so the error is about the comment and not a bug in your logic.

**Fix:** Don't start a comment with the word `verilator`.

## WARNING lines after `make harden`

**Symptom:** In Lab 05, `make harden` ends with three `Passed ✅` lines and then about a dozen
`WARNING` lines, such as `'PNR_SDC_FILE' is not defined`, `found 2 floating nets` and
`LEF58_ENCLOSURE with no CUTCLASS is not supported`.

**Cause:** These warnings are normal for a design that has no SDC file and no power source
location.

**Fix:** You don't need to do anything, because none of them is a failure. The three ✅ lines are
the results that matter, and you'll check them properly in Lab 05, Part 8.

## Re-running `make harden` with the same tag

**Symptom:** A second `make harden TAG=v1` prints `INFO Using existing run at 'v1'` and appends
stages 78, 79, 80… onto the finished run.

**Cause:** Re-running with the same tag doesn't start a new run; it adds more stages to the old
one. The result is confusing to read, and it doubles the disk use.

**Fix:** Use a new tag every time, for example `make harden TAG=v2`. Don't reach for
`--overwrite` instead, because it crashes with a Python traceback when `runs/` doesn't exist yet.

## Still stuck

Ask in the [team Discord](https://discord.gg/hrJnP5UsGz). [Getting
help](../guide/getting-started.md#getting-help) says what to include in your question.
