# Lab 01: One adder, two targets

You'll load DD103 into your workbench (the IIC-OSIC-TOOLS container desktop you run from the
`workspace` repo), then run a 4-bit ripple-carry adder through two synthesis flows, one for an
iCE40 FPGA and one for SKY130 standard cells, and write down what each one built. Along the way
you'll predict three numbers before the tools print them, and finish by sending a 2 KB memory to
both targets.

Time: about 1.5 hours. The tools themselves run in seconds. The optional Part 8 and Going further
are not counted.

Package: [`labs/lab-01-one-adder-two-targets/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-01-one-adder-two-targets)

## Before you start

- [IC101](https://uoftasic.com/ic101/) is complete: the noVNC desktop opens and you can get a
  terminal on it.
- [DD102](https://uoftasic.com/dd102/) is complete. If you have the `ripple4.sv` you wrote
  there, you can run it in the optional Part 8.
- Read [Getting started](guide/getting-started.md).

## Part 1: Load the course

If you haven't set up the workbench, do
[IC101 Lab 03](https://uoftasic.com/ic101/#/labs/lab-03-launch-the-workbench-overview) first.

1. Start the desktop from your `workspace` clone (`./scripts/start_vnc.sh`, or
   `scripts\start_vnc.bat` on Windows), open http://localhost/ and open a terminal on the
   desktop. Type every command from here on in that terminal, not on your laptop.

2. Load the environment and check the two technology variables. Repeat this step in every new
   terminal, because exports last only for the terminal you type them in.

   ```bash
   . /foss/designs/common/.designinit
   echo $PDK $STD_CELL_LIBRARY
   export COLUMNS=200
   ```

   You should see the `ASIC-EDU: PDK=sky130A ...` banner, then `sky130A sky130_fd_sc_hd`. If the
   first word is `ihp-sg13g2`, the image's own default, `.designinit` didn't run in this
   terminal; run it again. If the second word is anything else (the image's default is
   `sg13g2_stdcell`), run `export STD_CELL_LIBRARY=sky130_fd_sc_hd`. LibreLane, which you'll use
   in Lab 05, wraps its log to the terminal width; `COLUMNS=200` tells it the terminal is 200
   columns wide, which does the same job as maximizing the window.

3. Get the course files. `mod add` is needed only the first time; after that, `mod dd103` takes
   you to the module folder.

   ```bash
   mod add dd103      # first time only: clones github.com/uoftasic/dd103
   ```

   You should see `OK  module ready: /foss/designs/modules/dd103` and then
   `cwd: /foss/designs/modules/dd103`: `mod add` also moves you into the module. If it fails:

   | If you see | It means |
   |---|---|
   | `mod: no such module: dd103` | You ran `mod dd103` before `mod add dd103`. |
   | `fatal: could not read Username for 'https://github.com'` | git could not read the repo anonymously and is asking you to log in. Check that you typed `dd103`. If you did, ask in [Discord](https://discord.gg/hrJnP5UsGz). Do not type your password. |

   Anything else about Docker, the desktop, `.designinit` or `mod` is on IC101's
   [Troubleshooting](https://uoftasic.com/ic101/#/reference/troubleshooting) page. If `mod`
   won't work at all, `./scripts/add_module.sh dd103`, run on your laptop from your `workspace`
   clone, clones the course into the same folder (IC101's
   [What the smoke test checks](https://uoftasic.com/ic101/#/guide/smoke-test) describes it).
   Labs 01 to 04 then run even without `.designinit`: each package names its own PDK and cell
   library, so `make` in the package directory needs no environment setup.

4. Check the versions that every printed result in this course was measured with:

   ```bash
   yosys -V
   librelane --version
   ```

   You should see `Yosys 0.68 (git sha1 38e001a6f, Release, GNU /usr/bin/c++ 13.3.0)` and a
   first line of `LibreLane v3.1.0.dev3`. If either version number is different, you are not on
   `hpretl/iic-osic-tools:2026.08`; see
   [IC101: Launch the noVNC desktop](https://uoftasic.com/ic101/#/guide/launch-novnc) for the
   image the `workspace` scripts pull. You don't need to check the others now; later labs print
   `iverilog -V` (`14.0 (devel)`), `verilator --version` (`Verilator 5.050`),
   `nextpnr-ice40 --version` (`nextpnr-0.11.1-9-gb17408e2`) and `surfer --version`
   (`surfer 0.7.0`).

5. List the lab packages with `ls labs/`.

You should see the five lab packages, `lab-01-one-adder-two-targets` through `lab-05-elevator`.

## Part 2: Run both flows

1. Go to the lab package and run both flows:

   ```bash
   cd labs/lab-01-one-adder-two-targets
   make
   ```

You should see `make` finish in a couple of seconds with a `YOUR NUMBERS` summary at the end
and no red. `make` already ran both flows; Parts 3 and 4 look at each flow's output in turn.
`make fpga` and `make asic` re-run one flow each. Every number in this writeup comes from the
adder shipped in `src/`. You'll run your own in Part 8.

## Part 3: The FPGA flow

What did the FPGA flow build, and what does its report measure?

On an FPGA the cells already exist in silicon. This flow targets a Lattice iCE40 UP5K, whose
`SB_LUT4` is four inputs, sixteen bits of configuration memory and a multiplexer. It can be any 4-input Boolean function, chosen when
the bitstream loads.

1. Open `results/fpga-synth.log` and find the `=== ripple4 ===` block near the end. It should
   match this:

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

   `$scopeinfo` is not hardware. `ripple4` is built from four `fulladder` instances, one per bit
   slice; `synth_ice40` flattened them into one module and left one `$scopeinfo` marker per dissolved instance, so it can still tell you
   which slice a cell came from. `write_verilog` does not emit them. Eight `SB_LUT4` is the
   real answer.

2. Find the placement report from `nextpnr-ice40` in `results/fpga-pnr.log`:

   ```
   Info: Device utilisation:
   Info: 	         ICESTORM_LC:      10/   5280     0%
   Info: 	        ICESTORM_RAM:       0/     30     0%
   Info: 	               SB_IO:      14/     39    35%
   ```

   There are 10 logic cells for 8 LUTs because placement packs LUTs together with carry logic;
   [FPGA and ASIC targets](guide/warehouse-and-empty-lot.md) explains. `icepack` then turns the
   placed design into the bitstream `results/ripple4.bin`, 104,090 bytes.

   What does the `/5280` tell you that a cell count alone doesn't?

   <details>
   <summary>Answer</summary>

   Every count is out of a fixed total. An FPGA design does not get bigger; it gets closer to not
   fitting. "Does it fit?" is the question you'll be asked about an FPGA design, and this report
   answers it.

   </details>

3. Write down how big you expect `results/ripple4.bin` to be if the design had one full adder
   instead of four. Then open `src/ripple4.sv`, change `i < 4` to `i < 1` in the `generate`
   loop, and rebuild only the FPGA side:

   ```bash
   make fpga
   ```

   Yosys warns `Wire ripple4.\sum [3] is used but has no driver.`, and the same for `sum [2]`,
   `sum [1]` and `c [4]`, because you deleted the adders that drove them. The synthesis report
   now shows `1   SB_LUT4`, and the placement report `ICESTORM_LC:       3/   5280`.

   Did the bitstream shrink? Compare the size `make fpga` printed with your guess.

   <details>
   <summary>Answer</summary>

   No: `results/ripple4.bin` is still 104,090 bytes. It is not a description of your adder. It
   configures every LUT, every routing switch and every I/O buffer on the entire UP5K, including
   every logic cell you left empty (5,270 of them with the whole `ripple4`). A GDSII is the
   opposite: it describes only what you built, and it grows when your design does.

   </details>

4. Put the shipped adder back and rebuild, so Part 5 reads the right logs:

   ```bash
   git checkout src/ripple4.sv
   make fpga
   ```

You should see `8   SB_LUT4` in `results/fpga-synth.log` again, `10/   5280` and `14/     39` in
`results/fpga-pnr.log`, and a 104,090-byte `results/ripple4.bin`.

## Part 4: The ASIC flow

What did the ASIC flow build, and what does its "how big" number measure?

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

   The `$scopeinfo` warning is harmless: as in Part 3, those cells are markers left by `flatten`,
   not hardware.

2. Before that block, `abc` prints 94 lines like these, 63 of them about flip-flops and
   latches:

   ```
   ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbn_1".
   ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbn_2".
   ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbp_1".
   ```

   You did not break anything. ABC maps combinational logic only; flip-flops are handled by a
   separate pass called `dfflibmap`, which you'll use in Part 7 and meet properly in Lab 02. Your adder has no flip-flops,
   so ABC skipping every flop in the library costs you nothing.

You should see a chip area of `110.105600` µm² and no denominator anywhere.

Why is there no denominator, the way there was on the FPGA side?

<details>
<summary>Answer</summary>

An ASIC design cannot fail to fit. It just costs more silicon, and silicon is sold by the square
millimetre, so `110.105600 µm²` is a price.

</details>

## Part 5: Fill in the table

1. Run `make table`, which reprints the `YOUR NUMBERS` summary, and copy what it prints into
   this table by hand, on paper or in your own notes. Typing it is the exercise.
   For "cells reported", say whether your number includes the `$scopeinfo` markers.

   | | iCE40 UP5K (FPGA) | SKY130 (ASIC) |
   |---|---|---|
   | cells reported | | |
   | what the cells are called | | |
   | the "how big" number | | |
   | the denominator, if any | | |
   | the file you hand over | | |
   | size of that file | | |

   This lab doesn't produce the ASIC handover file, a GDSII layout; you'll make one in Lab 05.
   Write GDSII in that row and leave its size blank.

You should see two columns whose rows do not share units. There is no conversion factor between
`10/5280` and `110.1056 µm²`: "it fits" is an FPGA answer, and "it costs this much silicon" is an
ASIC answer.

## Part 6: Predict the 4-bit area

Can you get the adder's area from the area of one full adder?

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

3. Compare your prediction with the area you measured in Part 4, and look at the two cell lists.
   Then open `asic.ys`, the script `make asic` runs, and read the command just before `abc`.

You should see a prediction of $4 \times 33.7824 = 135.1296\ \mu\text{m}^2$ against a
measured 110.1056 µm²: the chained adder is 18.5 % smaller than your prediction.

Where did the difference come from, and what in `asic.ys` made it possible?

<details>
<summary>Answer</summary>

Alone, the sum becomes one `xor3_1` (23.773 µm²). In the chain, ABC used two `xnor2_1`
(17.517 µm²) per slice instead, because in context it can share the intermediate $a \oplus b$
term across the carry path. `asic.ys` has a `flatten` before `abc`. It dissolves the four
`fulladder` instances, and that is what let ABC see across the module boundary you drew.

A block costs less in context than it does alone. This is why you can't answer "how big is my
design?" with a spreadsheet of sub-block areas, and why every area figure in a datasheet is for
a whole block. You'll take this gap apart in Lab 04.

</details>

## Part 7: A memory on both targets

How does each target build 2 KB of memory?

The memory is a 2 KB array in `examples/mem.sv`:

```systemverilog
logic [7:0] store [0:2047];
always_ff @(posedge clk) begin
    if (we) store[addr] <= din;
    dout <= store[addr];
end
```

1. Send it to the FPGA, and read the last `=== mem ===` block:

   ```bash
   yosys -p "read_verilog -sv examples/mem.sv; synth_ice40 -top mem; stat"
   ```

2. Work out how many bits the array holds, and write down how many flip-flops you expect
   SKY130 to need for it.

3. Send the same file to SKY130, using the `LIB` you set in Part 6 (set it again if you opened
   a new terminal). This takes about twelve seconds, because there are twenty-seven thousand
   cells to map:

   ```bash
   yosys -p "read_verilog -sv examples/mem.sv; synth -top mem;
             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

4. Divide the SKY130 flip-flop count (the `sky130_fd_sc_hd__edfxtp_1` cells, flip-flops with an
   enable) by the number of bits in the array.

You should see four `SB_RAM40_4K` block RAMs on the FPGA side, and on the SKY130 side
16,384 `sky130_fd_sc_hd__edfxtp_1` and 2,748 `sky130_fd_sc_hd__mux4_2` among 27,684 cells, and a
chip area of `606554.233600` µm². 16,384 is exactly 2048 × 8: one flip-flop for every bit.

Why did the FPGA need four block RAMs where SKY130 needed a flip-flop for every bit?

<details>
<summary>Answer</summary>

The FPGA already had block RAM on the die, and the four `SB_RAM40_4K` are that dedicated memory
hardware. SKY130 has to build every bit out of flip-flops, plus multiplexers to pick which one you
meant. The reading after this lab, [FPGA and ASIC targets](guide/warehouse-and-empty-lot.md),
covers this, and how real chips use a memory macro instead.

</details>

## Part 8: Your own adder (optional)

Not counted in the lab's time. Run your DD102 adder through both flows and compare it with the
shipped one.

1. Your `workspace` folder on your laptop is mounted at `/foss/designs` in the container, so put
   your DD102 `ripple4.sv` somewhere inside the `workspace` folder, then copy it from there:

   ```bash
   cp /foss/designs/path/to/your/ripple4.sv src/ripple4.sv
   ```

   Keep the module named `ripple4` with ports `a`, `b`, `cin`, `sum`, `cout`. If it
   instantiates a `fulladder`, keep that in `src/fulladder.sv`. The package README covers
   other file layouts.

2. Run `make` and compare its `YOUR NUMBERS` summary with your Part 5 table.

3. Put the shipped adder back with `git checkout src/ripple4.sv`.

If you wrote the carry differently, your numbers will differ. That is a result, not an error:
two adders that simulate identically can synthesize to different cells. Write down what you got.

## Finishing

### You're done when

Your Part 5 table is filled in, and your predictions from Part 3 (the bitstream size), Part 6
(the 4-bit area) and Part 7 (the flip-flop count) each have the tool's number written next to
them.

To check your run of the shipped adder against ours, `make table` reprints your numbers, and
the "You should see" line at the end of each part has ours.

### Questions

1. Someone asks how big your adder is. What do you tell them for each target?

   <details>
   <summary>Answer</summary>

   For the iCE40, 10 of 5280 logic cells: the answer is whether it fits. For SKY130,
   110.1056 µm² of silicon: the answer is what it costs. See Parts 3 and 4. Part 6 is why you
   can't get that area by adding up the areas of the parts.

   </details>

### Submit

Nothing to submit.

## Going further (optional)

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

Next on the [Course path](README.md#course-path): read
[FPGA and ASIC targets](guide/warehouse-and-empty-lot.md),
[What synthesis does](guide/synthesis-is-translation.md) and
[Standard cells](guide/standard-cells-are-real.md), then do
[Lab 02: RTL becomes gates](labs/lab-02-rtl-becomes-gates-overview.md).
