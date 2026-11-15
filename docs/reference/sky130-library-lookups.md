# Looking things up in the SKY130 library

This page collects the commands for finding facts in the `sky130_fd_sc_hd` cell library from a
workbench terminal, along with what each one printed when we ran it on
`hpretl/iic-osic-tools:2026.08`. If you want to see how the files fit together, [Lab 02, Part 4](../labs/lab-02-rtl-becomes-gates-overview.md#part-4-open-the-cell-library)
walks you through one cell, `maj3_1`, and [Standard cells](../guide/standard-cells-are-real.md)
explains what the numbers mean.

Every entry assumes you have set these three paths in the same terminal:

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
REF=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd
LEF=$REF/lef/sky130_fd_sc_hd.lef
```

## Sibling libraries

```bash
ls /foss/pdks/sky130A/libs.ref/
```

That directory holds more than the standard cells: the list includes `sky130_sram_macros`,
`sky130_fd_io` and `sky130_fd_pr` next to `sky130_fd_sc_hd`.

## The cells a design used

To list the library cells that synthesis picked for the counter, run this from the Lab 02
package directory:

```bash
yosys -p "read_verilog -sv src/counter.sv; synth -top counter;
          dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean;
          stat -liberty $LIB" 2>&1 | awk '/^6\. Printing statistics/,0' | grep sky130
```

It prints one line for each distinct cell type, and the counter uses seven of them.

## Row height and width grid

```bash
grep '^  SIZE' $LEF | awk '{print $4}' | sort | uniq -c
grep '^  SIZE' $LEF | awk '{print $2}' | sort -g -u | head -4
```

The first command counts the cells in the LEF file by height and prints `430 2.720` and
`7 5.440`, which means 430 cells are one 2.720 µm row tall and 7 are twice that. The second
prints the four smallest widths, `0.460`, `0.920`, `1.380` and `1.840`, which are the first steps
of the width grid. For comparison, the high-voltage family uses a taller row:

```bash
grep '^  SIZE' /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hvl/lef/*.lef | awk '{print $4}' | sort | uniq -c
```

This prints `61 4.070` and `8 8.140`, so the high-voltage row is 4.070 µm tall.

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

The loop prints the transistor channel widths in each of the three `maj3` variants. Each one has
fourteen transistors, and the channels get wider as the drive-strength suffix goes up. The last
line counts the distinct `cell_footprint` values in the library and prints `143`.

## The full-adder cell

```bash
awk '/cell \("sky130_fd_sc_hd__fa_1"\)/,/^    }$/' $LIB \
  | grep -E '^        area :|^            function :' | grep -v power_down
```

You should see `area : 20.019200000;` and two `function` lines, because the cell has two outputs:
one line is for `COUT` and the other is for `SUM`.

## Process corners

```bash
ls $REF/lib/*.lib | wc -l
grep -m3 -E 'nom_temperature|nom_voltage|nom_process' $LIB
```

The first command prints `18`, the number of `.lib` files in the directory, each characterised under a different set of
conditions. The second
prints the nominal conditions of the file `LIB` points to, `nom_process : 1.0000000000;`,
`nom_temperature : 25.000000000;` and `nom_voltage : 1.8000000000;`, which agree with the
`tt_025C_1v80` in its name.

## Smallest and largest cells

```bash
awk '/^    cell \(/{n=$0} /^        area :/{print $3, n}' $LIB | sort -g | head -3
awk '/^    cell \(/{n=$0} /^        area :/{print $3, n}' $LIB | sort -g | tail -3
```

These sort every cell by area and print the three smallest and the three largest. The smallest
is `sky130_fd_sc_hd__diode_2`, at 2.5024 µm², and the largest is
`sky130_fd_sc_hd__lpflow_isobufsrc_16`, at 45.0432 µm².
