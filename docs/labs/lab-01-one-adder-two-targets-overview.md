# Lab 01 — One adder, two targets

Full runnable package: [`labs/lab-01-one-adder-two-targets/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-01-one-adder-two-targets).

You finished DD102 with a 4-bit ripple-carry adder that simulated correctly. Nobody
ever told you what it *is*. This lab hands the same file to two different
synthesizers and makes you write down what each one built.

## Prerequisites

- [IC101](https://uoftasic.com/ic101/) complete — the noVNC desktop opens and you can get a shell
- [DD102](https://uoftasic.com/dd102/) complete — you have a `ripple4.sv` you wrote
- DD103 cloned: `mod add dd103` then `mod dd103`
- `yosys -V` says **`Yosys 0.64`**. If it says something else you are not in the workbench.
- Read [Synthesis is translation with an accent](guide/synthesis-is-translation.md)

## Objectives

- Run one RTL file through an FPGA flow and an ASIC flow and get two different netlists
- Read the two things they report — *slots used* versus *area consumed* — and say which is which
- Produce a bitstream and explain why its size has nothing to do with your design
- Predict the ASIC area of a 4-bit adder from a 1-bit adder, be wrong, and find out why

## Theory (short)

Synthesis maps your operators onto whatever cells the target actually has.

On an **FPGA** the cells already exist in silicon. An iCE40 `SB_LUT4` is four
inputs, sixteen bits of configuration memory, and a multiplexer — it can be *any*
4-input Boolean function, decided at load time. Synthesis asks: which shelves do I
fill?

On an **ASIC** the cells are shapes you are about to pour. `sky130_fd_sc_hd__maj3_1`
is a fixed arrangement of fourteen transistors that computes "at least two of these
three inputs are high", forever. Synthesis asks: which shapes, and how much land?

Carry-out is where this bites. Write it however you like —

$$c_{\text{out}} = ab + c_{\text{in}}(a \oplus b)$$

— and it is still the **majority** of $a$, $b$, $c_{\text{in}}$. SKY130 ships a
cell for exactly that. iCE40 does not, because it does not ship cells for anything
in particular.

The background for all of this is [The warehouse and the empty lot](guide/warehouse-and-empty-lot.md).
Read it after you have your own numbers, not before — the numbers land harder when
they are yours.

## Procedure

```bash
. /foss/designs/common/.designinit
mod dd103
cd labs/lab-01-one-adder-two-targets

# use your own adder instead of the shipped copy
cp ~/path/to/your/ripple4.sv src/ripple4.sv   # optional but do it

make            # runs both flows and prints a summary
```

Total runtime is a couple of seconds. If `make` finishes and you did not see any
red, both flows worked.

### Step 1 — The FPGA: `make fpga`

- **Try this:** `make fpga`, then read the `=== ripple4 ===` block near the end of
  `results/fpga-synth.log`.
- **What you should see:**

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

  Then `nextpnr-ice40` places it on a real UP5K:

  ```
  Info: Device utilisation:
  Info: 	         ICESTORM_LC:      10/   5280     0%
  Info: 	        ICESTORM_RAM:       0/     30     0%
  Info: 	               SB_IO:      14/     39    35%
  ```

  and `icepack` writes **104,090 bytes**.

- **Why an engineer cares:** every number here is *out of* something. `10/5280`.
  `14/39`. An FPGA design does not get bigger — it gets *closer to not fitting*.
  The question you will be asked about an FPGA design is "does it fit", and this
  is the report that answers it.

> **`$scopeinfo` is not hardware.** `synth_ice40` flattened your four `fulladder`
> instances into one module and left one `$scopeinfo` marker behind per dissolved
> instance so it can still tell you which slice a cell came from. Eight `SB_LUT4`
> is the real answer. `write_verilog` does not emit `$scopeinfo` at all.

### Step 2 — The ASIC: `make asic`

- **Try this:** `make asic`, then read the last twenty lines of `results/asic.log`.
- **What you should see:**

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

- **Why an engineer cares:** nothing here is out of anything. There is no
  denominator. An ASIC design cannot fail to fit — it just costs more silicon, and
  silicon is sold by the square millimetre. `110.105600 µm²` is a price tag.

**Expect to hit this at least once.** Before that block, `abc` prints **94 lines**
of this — 63 of them about flip-flops and latches:

```
ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbn_1".
ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbn_2".
ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbp_1".
```

You did not break anything. ABC maps combinational logic only; flip-flops are
handled by a separate pass called `dfflibmap` (Lab 02). Your adder has no
flip-flops, so ABC skipping all 63 flop variants in the library costs you nothing.

### Step 3 — Fill in the table

- **Try this:** `make table`, and copy the numbers into this table by hand. Typing
  them is the exercise.

  | | iCE40 UP5K (FPGA) | SKY130 (ASIC) |
  |---|---|---|
  | cells reported | | |
  | what the cells are called | | |
  | the "how big" number | | |
  | the denominator, if any | | |
  | the file you hand over | | |
  | size of that file | | |

- **What you should see:** two columns whose rows do not have the same *units*.
  There is no conversion factor between `10/5280` and `110.1056 µm²`.
- **Why an engineer cares:** these are the first two questions anyone asks about a
  design, and answering with the wrong one marks you instantly. "It fits" is an
  FPGA answer. "It costs this much silicon" is an ASIC answer.

### Step 4 — Predict, then be wrong

- **Try this:** synthesize *one* full adder on its own, read its area, multiply by
  four, and write your prediction down **before** you look back at Step 2.

  ```bash
  LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
  yosys -p "read_verilog -sv src/fulladder.sv; synth -top fulladder;
            abc -liberty $LIB; opt_clean; stat -liberty $LIB"
  ```

- **What you should see:**

  ```
  === fulladder ===
          2   33.782 cells
          1    10.01   sky130_fd_sc_hd__maj3_1
          1   23.773   sky130_fd_sc_hd__xor3_1
     Chip area for module '\fulladder': 33.782400
  ```

  So four of them should be $4 \times 33.7824 = 135.1296\ \mu\text{m}^2$.
  Step 2 measured **110.1056 µm²** — **18.5 % smaller than your prediction.**

- **Why an engineer cares:** look at the cell mix. Alone, the sum becomes one
  `xor3_1` (23.773 µm²). In the chain, ABC used **two `xnor2_1` (17.517 µm²)**
  per slice instead, because in context it can share the intermediate $a \oplus b$
  term across the carry path. `flatten` is what let it see across the boundary you
  drew.

  **A block costs less in context than it does alone.** This is why you cannot
  answer "how big is my design?" with a spreadsheet of sub-block areas, and why
  every area figure in a datasheet is for a whole block.

## Expected results

You are done when all of these are true:

| Check | Expected |
|---|---|
| `grep SB_LUT4 results/fpga-synth.log` | `8   SB_LUT4` |
| `grep ICESTORM_LC results/fpga-pnr.log` | `10/   5280     0%` |
| `stat -c %s results/ripple4.bin` | `104090` |
| `grep "Chip area" results/asic.log` | `110.105600` |
| `grep sky130 results/asic.log \| tail -2` | 4 × `maj3_1`, 8 × `xnor2_1` |
| Your filled-in table | six rows, two columns, no shared units |

If you brought your own `ripple4.sv` and wrote the carry differently, your numbers
will differ — and that is a result, not an error. Two adders that simulate
identically can synthesize to different cells. Write down what you got.

> **The bitstream is a red herring, on purpose.** `results/ripple4.bin` is 104,090
> bytes. Delete three of your four full adders and rebuild it: still 104,090 bytes.
> It is not a description of your adder. It is the configuration of every LUT,
> every routing switch, and every I/O buffer on the entire UP5K — including the
> 5,270 logic cells you left empty. A GDSII is the opposite: it describes only
> what you actually built, and it grows when your design does.

## Going further

If you read the `abc` output carefully you will find this line:

```
ABC: Warning: Detected 9 multi-output cells (for example, "sky130_fd_sc_hd__fa_1").
```

SKY130 **ships a full-adder cell.** `sky130_fd_sc_hd__fa_1` is right there in the
liberty file at 20.0192 µm², with `A`, `B`, `CIN` in and `SUM`, `COUT` out. ABC
refused to use it, because ABC maps single-output cells and a full adder has two
outputs.

Which means the netlist you just measured is not the smallest one that exists —
it is the smallest one this particular mapper knows how to find. Nobody hand-picks
cells on a real design, but it is worth knowing that "the tool's answer" and "the
best answer" are different sentences.

## Links

- [Lab package](https://github.com/uoftasic/dd103/tree/main/labs/lab-01-one-adder-two-targets)
- Read next: [The warehouse and the empty lot](guide/warehouse-and-empty-lot.md) — the
  analogy behind everything you just measured, with the same numbers you now own
- Next lab: [Lab 02 — RTL becomes gates](labs/lab-02-rtl-becomes-gates-overview.md), where the
  `maj3_1` and `xnor2_1` you just counted stop being a list and become a picture
