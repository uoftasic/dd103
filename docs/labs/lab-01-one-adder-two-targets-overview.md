# Lab 01: One adder, two targets

You'll load DD103 into your workbench (the IIC-OSIC-TOOLS container desktop you run from the
`workspace` repo), then run a 4-bit ripple-carry adder through two synthesis flows, one for an
iCE40 FPGA and one for SKY130 standard cells, and write down what each one built. Along the way
you'll make three predictions and compare each one with what the tools report, and you'll finish
by sending a 2 KB memory to both targets.

Time: about 1.5 hours, even though the tools themselves run in seconds. That estimate doesn't
include the optional Part 8 or Going further.

Package: [`labs/lab-01-one-adder-two-targets/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-01-one-adder-two-targets)

## Before you start

- [IC101](https://uoftasic.com/ic101/) is complete: the noVNC desktop opens and you can get a
  terminal on it.
- [DD102](https://uoftasic.com/dd102/) is complete. If you have the `ripple4.sv` you wrote
  there, you can run it in the optional Part 8.
- Read [Getting started](../guide/getting-started.md).

## Part 1: Load the course

If you haven't set up the workbench, do
[IC101 Lab 03](https://uoftasic.com/ic101/labs/lab-03-launch-the-workbench-overview.html) first.

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
   first word is `ihp-sg13g2`, which is the image's own default, then `.designinit` didn't run in
   this terminal, so run it again. If the second word is anything else (the image's default is
   `sg13g2_stdcell`), run `export STD_CELL_LIBRARY=sky130_fd_sc_hd`. LibreLane, which you'll use
   in Lab 05, wraps its log to the terminal width; `COLUMNS=200` tells it the terminal is 200
   columns wide, which does the same job as maximizing the window.

3. Get the course files. You need `mod add` only the first time; after that, `mod dd103` takes
   you to the module folder.

   ```bash
   mod add dd103      # first time only: clones github.com/uoftasic/dd103
   ```

   You should see `OK  module ready: /foss/designs/modules/dd103` and then
   `cwd: /foss/designs/modules/dd103`, because `mod add` also moves you into the module. If it
   fails, look up the message here:

   | If you see | It means |
   |---|---|
   | `mod: no such module: dd103` | You ran `mod dd103` before `mod add dd103`. Run `mod add dd103`. |
   | `fatal: could not read Username for 'https://github.com'` | git couldn't read the repo anonymously, so it's asking you to log in. Check that you typed `dd103`, and if you did, ask in [Discord](https://discord.gg/hrJnP5UsGz). Don't type your password. |

   For any other problem with Docker, the desktop, `.designinit` or `mod`, see IC101's
   [Troubleshooting](https://uoftasic.com/ic101/reference/troubleshooting.html) page. If `mod`
   won't work at all, you can get the course another way: on your laptop, from your `workspace`
   clone, run `./scripts/add_module.sh dd103`. It clones the course into `modules/dd103` in that
   clone, which is the same folder `mod add` uses (IC101's
   [What the smoke test checks](https://uoftasic.com/ic101/guide/smoke-test.html) describes it).
   Then, in the desktop terminal, `cd /foss/designs/modules/dd103` takes you there. Labs 01 to 04
   will run even without `.designinit`, because each package names its own PDK and cell library,
   so running `make` in the package directory needs no environment setup.

4. Check the versions that every printed result in this course was measured with:

   ```bash
   yosys -V
   librelane --version
   ```

   You should see `Yosys 0.68 (git sha1 38e001a6f, Release, GNU /usr/bin/c++ 13.3.0)` and a
   first line of `LibreLane v3.1.0.dev3`. If either version number is different, you aren't
   running `hpretl/iic-osic-tools:2026.08`, and
   [IC101: Launch the noVNC desktop](https://uoftasic.com/ic101/guide/launch-novnc.html) explains
   which image the `workspace` scripts pull. You don't need to check the other tools now, because
   later labs print their versions: `iverilog -V` (`14.0 (devel)`),
   `verilator --version` (`Verilator 5.050`),
   `nextpnr-ice40 --version` (`nextpnr-0.11.1-9-gb17408e2`) and `surfer --version`
   (`surfer 0.7.0`).

5. List the lab packages with `ls labs/`.

You should see the five lab packages, `lab-01-one-adder-two-targets` through `lab-05-elevator`.

## Part 2: Run both flows

Do both flows run on your workbench?

1. Go to the lab package and run both flows:

   ```bash
   cd labs/lab-01-one-adder-two-targets
   make
   ```

You should see `make` finish in a couple of seconds with no red text, ending in a `YOUR NUMBERS`
summary that lists the FPGA logic cells, LUT4s and bitstream size, then the ASIC cells and area.
That one `make` ran both flows, and Parts 3 and 4 look at each flow's output in turn. To re-run
just one flow, use `make fpga` or `make asic`. Every number in this writeup comes from the adder
shipped in `src/`, and you'll run your own adder in Part 8.

Parts 3 to 8 all run from this directory, so if you open a new terminal, run `mod dd103` and
`cd labs/lab-01-one-adder-two-targets` first.

## Part 3: The FPGA flow

What did the FPGA flow build, and what does its report measure?

On an FPGA the cells already exist in silicon. This flow targets a Lattice iCE40 UP5K, whose
`SB_LUT4` is made of four inputs, sixteen bits of configuration memory and a multiplexer, so it
can compute any 4-input Boolean function. Which function it computes is chosen when the
bitstream loads.

1. Open `results/fpga-synth.log` and find the `=== ripple4 ===` block near the end. It should
   match this:

   ```
   === ripple4 ===

           +----------Local Count, excluding submodules.
           | 
          28 wires
          47 wire bits
          28 public wires
          47 public wire bits
           5 ports
          14 port bits
          13 cells
           4   $scopeinfo
           9   SB_LUT4
   ```

   The `$scopeinfo` cells aren't hardware. `ripple4` is built from four `fulladder` instances,
   one per bit slice, and `synth_ice40` flattened them into one module. It left one `$scopeinfo`
   marker for each instance it dissolved, so that Yosys can still tell you which slice a cell
   came from, and `write_verilog` leaves them out of the netlist it writes. The hardware is the
   nine `SB_LUT4`.

2. Find the placement report from `nextpnr-ice40` in `results/fpga-pnr.log`:

   ```
   Info: Device utilisation:
   Info: 	         ICESTORM_LC:      11/   5280     0%
   Info: 	        ICESTORM_RAM:       0/     30     0%
   Info: 	               SB_IO:      14/     39    35%
   ```

   There are 11 logic cells for 9 LUTs because the packer in `nextpnr` adds two cells of its
   own, `$PACKER_GND` and `$PACKER_VCC`. Some LUT inputs in the design are tied to a constant,
   and the chip has no wire that is permanently 0 or permanently 1, so the packer makes the
   constants out of logic cells. (Add `--verbose` to the `nextpnr-ice40` command and the packer lists both by
   name.) [FPGA and ASIC targets](../guide/warehouse-and-empty-lot.md), the reading after this
   lab, comes back to this. After placement, `icepack` turns the placed design into the
   bitstream `results/ripple4.bin`, which is 104,090 bytes.

   What does the `/5280` tell you that a cell count alone doesn't?

   <details>
   <summary>Answer</summary>

   It tells you that every count is out of a fixed total. As an FPGA design grows, it uses up more
   of that total and gets closer to not fitting, so the question you'll be asked about an FPGA
   design is "Does it fit?", and this report answers it.

   </details>

3. Write down how big you expect `results/ripple4.bin` to be if the design had one full adder
   instead of four. Then open `src/ripple4.sv`, change `i < 4` to `i < 1` in the `generate`
   loop, and rebuild only the FPGA side:

   ```bash
   make fpga
   ```

   Yosys warns `Wire ripple4.\sum [3] is used but has no driver.`, and gives the same warning for
   `sum [2]`, `sum [1]` and `c [4]` (`c` is the carry chain between the slices), because you
   deleted the adders that drove them. With nothing driving `c [4]`, `cout` is undriven too, so
   Yosys warns about `\cout` as well, and only `sum[0]` is left to compute. The synthesis report
   now shows `1   SB_LUT4`, and the placement report shows `ICESTORM_LC:       3/   5280`: the
   one LUT plus the same two constant cells.

   Did the bitstream shrink? `make fpga` ends by printing `ls -l results/ripple4.bin`; compare
   that size with your guess.

   <details>
   <summary>Answer</summary>

   No, `results/ripple4.bin` is still 104,090 bytes. The bitstream doesn't describe your adder;
   it configures every LUT, every routing switch and every I/O buffer on the entire UP5K,
   including every logic cell you left empty (5,269 of them with the whole `ripple4`), so its
   size doesn't depend on your design. A GDSII, the layout file an ASIC flow hands over, works the
   other way: it describes only what you built, so it grows when your design does.

   </details>

4. Put the shipped adder back and rebuild, so Part 5 reads the right logs:

   ```bash
   git checkout src/ripple4.sv
   make fpga
   ```

You should see `9   SB_LUT4` in `results/fpga-synth.log` again, `11/   5280` and `14/     39` in
`results/fpga-pnr.log`, and a 104,090-byte `results/ripple4.bin`.

## Part 4: The ASIC flow

What did the ASIC flow build, and what does its "how big" number measure?

On an ASIC the cells are shapes that will be manufactured. `sky130_fd_sc_hd__maj3_1`, for
example, is a fixed arrangement of fourteen transistors that computes "at least two of these
three inputs are high". Carry-out, however you write it,

$$c_{\text{out}} = ab + c_{\text{in}}(a \oplus b)$$

is the majority of $a$, $b$ and $c_{\text{in}}$, and SKY130 ships a cell for exactly that
function. iCE40 doesn't have one, because all of its logic is built from LUTs that can each be
any 4-input function.

1. Read the `=== ripple4 ===` block at the end of `results/asic.log`
   (`tail -25 results/asic.log` shows it):

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

   The `$scopeinfo` warning is harmless, because those cells are the same kind of marker you saw
   in Part 3, left behind by `flatten`, rather than hardware.

2. Before that block, `abc` prints 94 lines like these, 63 of them about flip-flops and
   latches:

   ```
   ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbn_1".
   ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbn_2".
   ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbp_1".
   ```

   These lines don't mean you broke anything. ABC maps only combinational logic, and flip-flops
   are handled by a separate pass called `dfflibmap`, which you'll use in Part 7 and meet
   properly in Lab 02. Your adder has no flip-flops, so it loses nothing when ABC skips every
   flop in the library.

You should see a chip area of `110.105600` µm² and no denominator anywhere.

Why is there no denominator, the way there was on the FPGA side?

<details>
<summary>Answer</summary>

An ASIC design can't fail to fit, because there is no fixed chip for it to fit into; a bigger
design just costs more silicon. Silicon is sold by the square millimetre, so `110.105600 µm²` is
really a price.

</details>

## Part 5: Fill in the table

How do the two targets' answers to "how big is it?" compare?

1. Run `make table`, which reprints the `YOUR NUMBERS` summary. Copy its numbers into this table
   by hand, on paper or in your own notes, since copying them yourself is the exercise, and fill
   in the other rows from Parts 3 and 4. For "cells reported", say whether your number includes
   the `$scopeinfo` markers.

   | | iCE40 UP5K (FPGA) | SKY130 (ASIC) |
   |---|---|---|
   | cells reported | | |
   | what the cells are called | | |
   | the "how big" number | | |
   | the denominator, if any | | |
   | the file you hand over | | |
   | size of that file | | |

   This lab doesn't produce the ASIC handover file, which is a GDSII layout (you'll make one in
   Lab 05), so write GDSII in that row and leave its size blank.

You should see two columns whose rows don't share units: there is no conversion factor between
`11/5280` and `110.1056 µm²`.

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
measured 110.1056 µm², so the chained adder is 18.5 % smaller than your prediction.

Where did the difference come from, and what in `asic.ys` made it possible?

<details>
<summary>Answer</summary>

On its own, a full adder's sum becomes one `xor3_1` (23.773 µm²). In the chain, ABC built each
sum from two `xnor2_1` (17.517 µm²) instead, because it was choosing cells for the whole chain at
once rather than for one adder on its own. `asic.ys` has a `flatten` before `abc`, which dissolves
the four `fulladder` instances, and that is what let ABC see across the module boundary you drew.

So a block can cost less inside a design than it does on its own. That's why you can't
answer "how big is my design?" with a spreadsheet of sub-block areas, and why every area figure
in a datasheet is for a whole block. You'll take this gap apart in Lab 04.

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

   You should see four `SB_RAM40_4K` block RAMs in it.

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

You should see four `SB_RAM40_4K` on the FPGA side, and on the SKY130 side
16,384 `sky130_fd_sc_hd__edfxtp_1` and 2,748 `sky130_fd_sc_hd__mux4_2` among 27,684 cells, and a
chip area of `606554.233600` µm². 16,384 is exactly 2048 × 8, so there is one flip-flop for
every bit.

Why did the FPGA need four block RAMs where SKY130 needed a flip-flop for every bit?

<details>
<summary>Answer</summary>

The FPGA already had block RAM on the die, and the four `SB_RAM40_4K` are that dedicated memory
hardware. SKY130 has to build every bit out of flip-flops, plus multiplexers to pick out the one
you meant. The reading after this lab, [FPGA and ASIC targets](../guide/warehouse-and-empty-lot.md),
covers this, and also how real chips use a memory macro instead.

</details>

## Part 8: Your own adder (optional)

Does the adder you wrote in DD102 build the same hardware as the shipped one? This part is not
counted in the lab's time.

1. Your `workspace` folder on your laptop is mounted at `/foss/designs` in the container, so put
   your DD102 `ripple4.sv` somewhere inside the `workspace` folder, then copy it from there:

   ```bash
   cp /foss/designs/path/to/your/ripple4.sv src/ripple4.sv
   ```

   Keep the module named `ripple4` with ports `a`, `b`, `cin`, `sum`, `cout`. If it
   instantiates a `fulladder`, keep that in `src/fulladder.sv`. If your files are laid out
   differently, the package README covers other layouts.

2. Run `make` and compare its `YOUR NUMBERS` summary with your Part 5 table.

3. Put the shipped adder back and rebuild, so `make table` shows the shipped numbers again:

   ```bash
   git checkout src/ripple4.sv
   make
   ```

If you wrote the carry differently, your numbers will differ. That's a result rather than an
error, because two adders that simulate identically can synthesize to different cells, so write
down what you got.

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

   For the iCE40, it uses 11 of 5280 logic cells, which tells them whether it fits. For SKY130,
   it takes 110.1056 µm² of silicon, which tells them what it costs. Parts 3 and 4 cover these,
   and Part 6 shows why you can't get that area by adding up the areas of the parts.

   </details>

### Submit

Nothing to submit.

## Going further (optional)

- Search `results/asic.log` for this line from `abc`:

  ```
  ABC: Warning: Detected 9 multi-output cells (for example, "sky130_fd_sc_hd__fa_1").
  ```

  SKY130 does ship a full-adder cell: `sky130_fd_sc_hd__fa_1` is in the liberty file at
  20.0192 µm², with inputs `A`, `B`, `CIN` and outputs `SUM`, `COUT`. ABC didn't use it, because
  ABC maps only single-output cells and a full adder has two outputs. So the netlist you measured
  is the smallest one this mapper knows how to find, which isn't necessarily the smallest one
  that exists. Nobody hand-picks cells on a real design, but it's worth remembering that
  "the tool's answer" and "the best answer" can differ.

Next on the [Course path](../index.md#course-path): read
[FPGA and ASIC targets](../guide/warehouse-and-empty-lot.md),
[What synthesis does](../guide/synthesis-is-translation.md) and
[Standard cells](../guide/standard-cells-are-real.md), then do
[Lab 02: RTL becomes gates](../labs/lab-02-rtl-becomes-gates-overview.md).
