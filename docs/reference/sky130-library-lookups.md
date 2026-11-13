# Looking things up in the SKY130 library

Commands for finding facts in the `sky130_fd_sc_hd` cell library from a workbench terminal, with
what each one printed on `hpretl/iic-osic-tools:2026.08`. [Lab 02, Part 4](labs/lab-02-rtl-becomes-gates-overview.md#part-4-open-the-cell-library)
walks through one cell, `maj3_1`; [Standard cells](guide/standard-cells-are-real.md) explains
what the numbers mean.

Every entry assumes these three paths are set:

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
REF=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd
LEF=$REF/lef/sky130_fd_sc_hd.lef
```

## Sibling libraries

```bash
ls /foss/pdks/sky130A/libs.ref/
```

The list includes `sky130_sram_macros`, `sky130_fd_io` and `sky130_fd_pr` next to
`sky130_fd_sc_hd`.

## The cells a design used

From the Lab 02 package directory, for the counter:

```bash
yosys -p "read_verilog -sv src/counter.sv; synth -top counter;
          dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean;
          stat -liberty $LIB" 2>&1 | awk '/^6\. Printing statistics/,0' | grep sky130
```

It prints seven distinct cell types.

## Row height and width grid

```bash
grep '^  SIZE' $LEF | awk '{print $4}' | sort | uniq -c
grep '^  SIZE' $LEF | awk '{print $2}' | sort -g -u | head -4
```

`430 2.720` and `7 5.440`, then widths `0.460`, `0.920`, `1.380`, `1.840`. For comparison, the
high-voltage family uses a taller row:

```bash
grep '^  SIZE' /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hvl/lef/*.lef | awk '{print $4}' | sort | uniq -c
```

`61 4.070` and `8 8.140`: the high-voltage row is 4.070 µm tall.

## Drive strengths

```bash
for C in maj3_1 maj3_2 maj3_4; do
  echo -n "$C: "
  awk "/^\.SUBCKT sky130_fd_sc_hd__$C /,/^\.ENDS/" $REF/cdl/sky130_fd_sc_hd.cdl \
    | grep -o 'w=[0-9.]*' | sort | uniq -c | tr '\n' ' '
  echo
done
grep 'cell_footprint :' $LIB | sort -u | wc -l
```

Fourteen transistors in each variant, with wider channels as the suffix goes up, and then `143`
distinct footprints.

## The full-adder cell

```bash
awk '/cell \("sky130_fd_sc_hd__fa_1"\)/,/^    }$/' $LIB \
  | grep -E '^        area :|^            function :' | grep -v power_down
```

`area : 20.019200000;` and two `function` lines, one for `COUT` and one for `SUM`.

## Process corners

```bash
ls $REF/lib/*.lib | wc -l
grep -m3 -E 'nom_temperature|nom_voltage|nom_process' $LIB
```

`18`, then `nom_process : 1.0000000000;`, `nom_temperature : 25.000000000;` and
`nom_voltage : 1.8000000000;`.

## Smallest and largest cells

```bash
awk '/^    cell \(/{n=$0} /^        area :/{print $3, n}' $LIB | sort -g | head -3
awk '/^    cell \(/{n=$0} /^        area :/{print $3, n}' $LIB | sort -g | tail -3
```

`sky130_fd_sc_hd__diode_2` at 2.5024 µm² at the bottom and
`sky130_fd_sc_hd__lpflow_isobufsrc_16` at 45.0432 µm² at the top.
