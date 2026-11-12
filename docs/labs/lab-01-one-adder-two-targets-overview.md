# Lab 01: One adder, two targets

You'll set up DD103 in your workbench (the IIC-OSIC-TOOLS container desktop you run from the
`workspace` repo), then run your DD102 ripple-carry adder through two synthesis flows, one for
an iCE40 FPGA and one for SKY130 standard cells, and write down what each one built. You'll
finish by sending a 2 KB memory to both targets.

Time: about 1.5 hours. The tools themselves run in seconds; most of the time is setup and
reading output.

Package: [`labs/lab-01-one-adder-two-targets/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-01-one-adder-two-targets)

## Before you start

- [IC101](https://uoftasic.com/ic101/) is complete: the noVNC desktop opens and you can get a
  terminal on it.
- [DD102](https://uoftasic.com/dd102/) is complete, and you have a `ripple4.sv` you wrote.
- Read [Getting started](guide/getting-started.md).

## Part 1: Set up the workbench

1. On your own machine, in your `workspace` clone, start the desktop:

   ```bash
   cd workspace
   ./scripts/start_vnc.sh          # Windows: scripts\start_vnc.bat
   ```

2. Open http://localhost/ and open a terminal on that desktop, the same one you used for the
   IC101 smoke test. Every command from here on is typed in that terminal, not on your laptop.
   Maximize the terminal window. LibreLane, which you'll use in Lab 05, wraps its log to the
   terminal width.

3. Load the environment. Do this in every new terminal.

   ```bash
   . /foss/designs/common/.designinit
   ```

   ```
   ASIC-EDU: PDK=sky130A  PDK_ROOT=/foss/pdks  designs=/foss/designs
             run 'mod' to list course modules, or 'mod <name>' to enter one.
   ```

4. Check the two technology variables:

   ```bash
   echo $PDK
   echo $STD_CELL_LIBRARY
   ```

   `PDK` must say `sky130A`. If it says `ihp-sg13g2`, step 3 did not run in this terminal, so
   run it again. `STD_CELL_LIBRARY` must end up as `sky130_fd_sc_hd`. Run these two lines either
   way; the first sets the cell library and the second sets the terminal width:

   ```bash
   export STD_CELL_LIBRARY=sky130_fd_sc_hd
   export COLUMNS=200
   ```

   Exports last only for the terminal you type them in, so repeat steps 3 and 4 in every new
   terminal.

5. Get the course files. `mod add` is needed only the first time:

   ```bash
   mod add dd103      # first time only: clones github.com/uoftasic/dd103
   mod dd103          # every time after that
   ```

   ```
   Cloning https://github.com/uoftasic/dd103.git
        into /foss/designs/modules/dd103
   Cloning into '/foss/designs/modules/dd103'...
   OK  module ready: /foss/designs/modules/dd103
       run: mod dd103
   cwd: /foss/designs/modules/dd103
   ```

   `mod add` also moves you into the module, which is what the `cwd:` line shows. In later
   sessions, `mod dd103` takes you there. `mod` with no arguments lists what you already have:

   ```
   Available modules:
   dd103
   ic101_setup
   ```

   If something goes wrong here, it is probably one of these:

   | What you see | What it means |
   |---|---|
   | `bash: mod: command not found` | You did not run step 3 in this terminal. Every new tab starts clean. |
   | `mod: no such module: dd103` | You ran `mod dd103` before `mod add dd103`. |
   | `fatal: could not read Username for 'https://github.com'` | git could not read the repo anonymously and is asking you to log in. Check the spelling first. If it is right, ask in [Discord](https://discord.gg/hrJnP5UsGz). Do not type your password. |

6. Check your versions:

   ```bash
   yosys -V
   librelane --version
   ```

   ```
   Yosys 0.68 (git sha1 38e001a6f, Release, GNU /usr/bin/c++ 13.3.0)
   ```

   ```
   LibreLane v3.1.0.dev3

   Copyright ©2025-2026 LibreLane Contributors

   Adapted from OpenLane 2.0
   Copyright ©2020-2025 Efabless Corporation
   ```

   `0.68` and `3.1.0.dev3` are the numbers that matter. If either is different, you are on a
   different image; see [IC101: Launch the noVNC desktop](https://uoftasic.com/ic101/#/guide/launch-novnc)
   for the image the `workspace` scripts pull. The rest of the toolchain, if you want to check
   it:

   | Tool | Command | Expect |
   |---|---|---|
   | Yosys | `yosys -V` | `Yosys 0.68` |
   | LibreLane | `librelane --version` | `LibreLane v3.1.0.dev3` |
   | Icarus Verilog | `iverilog -V` | `14.0 (devel)` |
   | Verilator | `verilator --version` | `Verilator 5.050` |
   | Surfer | `surfer --version` | `surfer 0.7.0` |
   | nextpnr | `nextpnr-ice40 --version` | `nextpnr-0.11.1-9-gb17408e2` |

7. From `/foss/designs/modules/dd103`, list the lab packages:

   ```bash
   ls labs/
   ```

You should see `Yosys 0.68` from `yosys -V`, and `ls labs/` should list the five lab packages,
`lab-01-one-adder-two-targets` through `lab-05-elevator`.

## Part 2: Run both flows

1. Go to the lab package and, optionally but recommended, drop in your own adder. Your
   `workspace` folder on your laptop is mounted at `/foss/designs` in the container, so first put
   your DD102 `ripple4.sv` somewhere inside the `workspace` folder, then copy it from there:

   ```bash
   cd labs/lab-01-one-adder-two-targets
   cp /foss/designs/path/to/your/ripple4.sv src/ripple4.sv
   ```

   Keep the module named `ripple4` with ports `a`, `b`, `cin`, `sum`, `cout`. If it
   instantiates a `fulladder`, keep that in `src/fulladder.sv`. The package README covers
   other file layouts. The numbers in this writeup come from the shipped adder, so with your
   own expect different ones; `git checkout src/ripple4.sv` puts the shipped one back.

2. Run both flows:

   ```bash
   make
   ```

You should see `make` finish in a couple of seconds with a `YOUR NUMBERS` summary at the end
and no red. `make` already ran both flows. Parts 3 and 4 look at each flow's output in turn;
`make fpga` and `make asic` re-run one flow each if you want to watch it again.

## Part 3: The FPGA flow

On an FPGA the cells already exist in silicon. An iCE40 `SB_LUT4` is four inputs, sixteen bits
of configuration memory and a multiplexer. It can be any 4-input Boolean function, chosen when
the bitstream loads.

1. Read the `=== ripple4 ===` block near the end of `results/fpga-synth.log`:

   ```
   === ripple4 ===

           +----------Local Count, excluding submodules.
           | 
          29 wires
          48 wire bits
          29 public wires
          48 public wire bits
           5 ports
          14 port bits
          12 cells
           4   $scopeinfo
           8   SB_LUT4
   ```

   `$scopeinfo` is not hardware. `synth_ice40` flattened your four `fulladder` instances into
   one module and left one `$scopeinfo` marker per dissolved instance, so it can still tell you
   which slice a cell came from. `write_verilog` does not emit them. Eight `SB_LUT4` is the
   real answer.

2. Read the placement report from `nextpnr-ice40` in `results/fpga-pnr.log`:

   ```
   Info: Device utilisation:
   Info: 	         ICESTORM_LC:      10/   5280     0%
   Info: 	        ICESTORM_RAM:       0/     30     0%
   Info: 	               SB_IO:      14/     39    35%
   ```

   There are 10 logic cells for 8 LUTs because placement packs LUTs together with carry logic;
   [FPGA and ASIC targets](guide/warehouse-and-empty-lot.md) explains. `icepack` then turns the
   placed design into the bitstream `results/ripple4.bin`, 104,090 bytes.

You should see logic-cell and I/O counts that are each out of a fixed total: `10/5280`, `14/39`. An FPGA design does not get bigger; it gets closer to not fitting. "Does it fit?" is
the question you'll be asked about an FPGA design, and this report answers it.

## Part 4: The ASIC flow

On an ASIC the cells are shapes that will be manufactured. `sky130_fd_sc_hd__maj3_1` is a fixed
arrangement of fourteen transistors that computes "at least two of these three inputs are
high". Carry-out, however you write it,

$$c_{\text{out}} = ab + c_{\text{in}}(a \oplus b)$$

is the majority of $a$, $b$ and $c_{\text{in}}$. SKY130 ships a cell for exactly that. iCE40
does not; its logic is built from LUTs that can each be any 4-input function.

1. Read the last twenty lines of `results/asic.log`:

   ```
   === ripple4 ===

           +----------Local Count, excluding submodules.
           |        +-Local Area, excluding submodules.
           |        | 
          16  110.106 cells
           4        -   $scopeinfo
           4   40.038   sky130_fd_sc_hd__maj3_1
           8   70.067   sky130_fd_sc_hd__xnor2_1

      Area for cell type $scopeinfo is unknown!

      Chip area for module '\ripple4': 110.105600
        of which used for sequential elements: 0.000000 (0.00%)
   ```

   The `$scopeinfo` warning is harmless: as in Part 3, those cells are markers, not hardware.

2. Before that block, `abc` prints 94 lines like these, 63 of them about flip-flops and
   latches:

   ```
   ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbn_1".
   ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbn_2".
   ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbp_1".
   ```

   You did not break anything. ABC maps combinational logic only; flip-flops are handled by a
   separate pass called `dfflibmap`, which you'll meet in Lab 02. Your adder has no flip-flops,
   so ABC skipping every flop in the library costs you nothing.

You should see a chip area of `110.105600` µm² and no denominator anywhere. An ASIC design
cannot fail to fit. It just costs more silicon, and silicon is sold by the square millimetre,
so `110.105600 µm²` is a price.

## Part 5: Fill in the table

1. Run `make table`, and copy the numbers into this table by hand. Typing them is the exercise.
   For "cells reported", say whether your number includes the `$scopeinfo` markers.

   | | iCE40 UP5K (FPGA) | SKY130 (ASIC) |
   |---|---|---|
   | cells reported | | |
   | what the cells are called | | |
   | the "how big" number | | |
   | the denominator, if any | | |
   | the file you hand over | | |
   | size of that file | | |

   This lab doesn't produce the ASIC handover file; you'll make one in Lab 05. Write down what
   it is called and leave its size blank.

You should see two columns whose rows do not share units. There is no conversion factor between
`10/5280` and `110.1056 µm²`. "It fits" is an FPGA answer; "it costs this much silicon" is an
ASIC answer.

## Part 6: Predict the 4-bit area

1. Synthesize one full adder on its own and read its area:

   ```bash
   LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
   yosys -p "read_verilog -sv src/fulladder.sv; synth -top fulladder;
             abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

   ```
   === fulladder ===
           2   33.782 cells
           1    10.01   sky130_fd_sc_hd__maj3_1
           1   23.773   sky130_fd_sc_hd__xor3_1
      Chip area for module '\fulladder': 33.782400
   ```

2. Multiply by four to get the area you would predict for `ripple4` from one adder alone, and
   write it down.

3. Compare your prediction with the area you measured in Part 4, and look at the cell mix to see
   where the difference came from.

You should see a prediction of $4 \times 33.7824 = 135.1296\ \mu\text{m}^2$ against a
measured 110.1056 µm²: the chained adder is 18.5 % smaller than your prediction. Alone, the sum
becomes one `xor3_1` (23.773 µm²). In the chain, ABC used two `xnor2_1` (17.517 µm²) per slice
instead, because in context it can share the intermediate $a \oplus b$ term across the carry
path. `asic.ys`, the script `make asic` runs, has a `flatten` before `abc`. It dissolves the four
`fulladder` instances, and that is what let ABC see across the module boundary you drew.

A block costs less in context than it does alone. This is why you can't answer "how big is my
design?" with a spreadsheet of sub-block areas, and why every area figure in a datasheet is for
a whole block. You'll take this gap apart in Lab 04.

## Part 7: A memory on both targets

The memory is a 2 KB array in `examples/mem.sv`:

```systemverilog
logic [7:0] store [0:2047];
always_ff @(posedge clk) begin
    if (we) store[addr] <= din;
    dout <= store[addr];
end
```

1. Send it to the FPGA:

   ```bash
   yosys -p "read_verilog -sv examples/mem.sv; synth_ice40 -top mem; stat"
   ```

   Read the last `=== mem ===` block.

2. Send the same file to SKY130, using the `LIB` you set in Part 6 (set it again if you opened
   a new terminal). This takes about twelve seconds, because there are twenty-seven thousand
   cells to map:

   ```bash
   yosys -p "read_verilog -sv examples/mem.sv; synth -top mem;
             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

3. Compare the two. Divide the SKY130 flip-flop count by the number of bits in the array.

You should see four `SB_RAM40_4K` block RAMs on the FPGA side, and on the SKY130 side
16,384 `sky130_fd_sc_hd__edfxtp_1`, 2,748 `sky130_fd_sc_hd__mux4_2` and a chip area of
`606554.233600` µm². 16,384 is exactly 2048 × 8: one flip-flop for every bit. The reading
after this lab, [FPGA and ASIC targets](guide/warehouse-and-empty-lot.md), explains why.

## Finishing

You are done when all of these are true:

| Check | Expected |
|---|---|
| `grep SB_LUT4 results/fpga-synth.log` | `8   SB_LUT4` |
| `grep ICESTORM_LC results/fpga-pnr.log` | `10/   5280     0%` |
| `stat -c %s results/ripple4.bin` (the shell's `stat`, not Yosys's) | `104090` |
| `grep "Chip area" results/asic.log` | `110.105600` |
| `grep sky130 results/asic.log \| tail -2` | 4 × `maj3_1`, 8 × `xnor2_1` |
| Your filled-in table | six rows, two columns, no shared units |

If you brought your own `ripple4.sv` and wrote the carry differently, your numbers will differ.
That is a result, not an error: two adders that simulate identically can synthesize to
different cells. Write down what you got.

## Going further

- Delete three of your four full adders and rebuild the bitstream with `make fpga`
  (`git checkout src/ripple4.sv` restores the file afterwards). `results/ripple4.bin` stays
  at 104,090 bytes. It is not a description of your adder. It configures every LUT, every
  routing switch and every I/O buffer on the entire UP5K, including the 5,270 logic cells you
  left empty. A GDSII is the opposite: it describes only what you built, and it grows when your
  design does.
- Search `results/asic.log` for this line from `abc`:

  ```
  ABC: Warning: Detected 9 multi-output cells (for example, "sky130_fd_sc_hd__fa_1").
  ```

  SKY130 ships a full-adder cell. `sky130_fd_sc_hd__fa_1` is in the liberty file at
  20.0192 µm², with `A`, `B`, `CIN` in and `SUM`, `COUT` out. ABC did not use it, because ABC
  maps single-output cells and a full adder has two outputs. So the netlist you measured is the
  smallest one this mapper knows how to find, which is not necessarily the smallest one that
  exists. Nobody hand-picks cells on a real design, but "the tool's answer" and "the best
  answer" can differ.

Next: read [FPGA and ASIC targets](guide/warehouse-and-empty-lot.md), then
[What synthesis does](guide/synthesis-is-translation.md) and
[Standard cells](guide/standard-cells-are-real.md) before Lab 02.
