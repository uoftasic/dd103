# The synthesizable subset

This page is a lookup table for one question: can you use a given construct in code you mean to
synthesize, and if you can't, what happens when you try? Find your construct, read the result, and
get back to your design.

We ran every row ourselves, with this command unless the row says otherwise:

```bash
yosys -p "read_verilog -sv f.sv; synth -top f; stat"
```

The runs used Yosys 0.68 (`git sha1 38e001a6f`) in `hpretl/iic-osic-tools:2026.08`. The cell
counts are generic Yosys gates from `synth`, before any technology mapping; the `initial` and
`$display` rows also quote what was left after mapping to SKY130. We give the counts so that
you can check your own run against them, and so that you can see when a construct costs more
hardware than you expected.

If `yosys -V` prints a version other than `0.68`, the numbers on this page don't apply to your
runs, so check it before you compare anything:

```bash
yosys -V
```

```
Yosys 0.68 (git sha1 38e001a6f, Release, GNU /usr/bin/c++ 13.3.0)
```

## Result column

| Result | Meaning |
|---|---|
| **Builds** | synthesizes, and the hardware is what you meant |
| **Builds, read the fine print** | synthesizes, and the hardware may not be what you meant |
| **Hard error** | Yosys stops with exit code 1, and the row quotes the error text |
| **Vanishes** | Yosys accepts it and throws it away, with zero warnings |

The fine-print and vanishing results are the ones that cost people days, because in both cases
the run finishes without an error.

## The table

| Construct | Result | What actually happens |
|---|---|---|
| `logic` | **Builds** | It's the only signal type you need, because Yosys decides whether a signal becomes a wire or a flop from how you drive it, not from the keyword. A two-input AND gives `1 $_AND_` |
| `always_ff @(posedge clk)` | **Builds** | A flop with synchronous reset gives `1 $_SDFF_PP0_`. The `_ff` suffix makes Yosys check that the block really describes a flop |
| `always_comb` | **Builds** | A 2-bit `case` gives `1 $_ANDNOT_`. Yosys stops with an error if a branch is missing, and that check is the reason to prefer it over `always @*` |
| `always @*` | **Builds, read the fine print** | Yosys doesn't check that every branch is covered, so an `if` with no `else` gives you a latch, `1 $_DLATCH_P_`, with zero warnings. Use `always_comb` instead |
| `typedef enum logic [1:0]`, module-local | **Builds** | A 3-state FSM lowers to `5 cells`: `2 $_DFF_P_` plus `1 $_AND_`, `1 $_ANDNOT_` and `1 $_NOR_`. The enum names don't survive synthesis; only the bit encoding does |
| packed `struct` | **Builds** | Zero cells, because a packed struct is only a naming scheme for bits you already had. You get `20 wire bits` and no gates |
| struct literal `'{high: h, low: l}` | **Hard error** | `ERROR: syntax error, unexpected OP_CAST`. Assign the fields one at a time instead, or build the value with a concatenation |
| `generate` / `genvar` / `endgenerate` | **Builds** | A `for (i=0;i<4;i++)` loop that produces four inverters gives exactly `4 $_NOT_`. The loop runs at elaboration, when Yosys builds the netlist, so nothing is left looping in the silicon |
| `for` inside `always_comb` | **Builds** | An 8-bit XOR reduction gives `7 cells` (`6 $_XNOR_ + 1 $_XOR_`), because Yosys unrolls the loop into a tree of gates |
| `interface` + `modport` | **Builds, read the fine print** | It elaborates, the netlist gains a module named `dev_m$interfaces$bus_if`, and the connectivity is correct. The catch is that Yosys emits `Warning: Identifier '\p.req' is implicitly declared` for every interface signal, and a misspelled signal name produces the identical warning, so the warnings can no longer tell you about typos |
| `initial` | **Vanishes**, see below | Yosys raises no error. It turns the `initial` into an attribute, `(* init = 4'h0 *)`, in the final SKY130 netlist, and builds zero gates of reset logic. An FPGA honours the attribute, but on an ASIC it means nothing |
| `function`, assigning to its own name | **Builds** | `4 $_NOT_`. This is the form of `function` that works (compare the `return` row below) |
| `return` inside a `function` | **Hard error** | `ERROR: syntax error, unexpected TOK_ID` (or `unexpected '~'`, or whichever token follows `return`). Textbooks use `return` everywhere, but Yosys's built-in parser doesn't implement it |
| `task` | **Builds** | A task called from `always_ff` gives `4 $_DFF_P_`, the same as writing the body inline. A task with timing controls inside it doesn't synthesize |
| `import pkg::*` at file scope | **Builds** | `4 $_NOT_`. The import works when you put it outside the module, above it |
| `import pkg::*` in the module header | **Hard error** | `ERROR: syntax error, unexpected TOK_IMPORT, expecting '#' or '(' or ';'` |
| `import pkg::*` in the module body | **Hard error** | `ERROR: syntax error, unexpected TOK_IMPORT` |
| `pkg::NAME` fully qualified | **Builds** | `4 $_NOT_`. This form always works, which makes it the portable way to use a package |
| `unique case` | **Builds, read the fine print** | `unique` turns off the missing-branch check. The same code without `unique` stops with a hard `ERROR: Latch inferred`, but with `unique` it builds don't-care logic without a warning. See below |
| `priority if` / `priority case` | **Builds** | A 3-input priority encoder gives `3 cells`. `priority` matches the semantics that a plain `if`/`else if` already had, so adding it changes nothing |
| `d[sel*4 +: 4]`, indexed part-select | **Builds** | `12 $_MUX_`. This is the legal way to select a slice at a variable position |
| `d[i]`, variable bit-select | **Builds** | `19 cells`, which is the 16-to-1 mux you would expect |
| `d[lo+3 : lo]`, variable range | **Builds, read the fine print** | This isn't legal SystemVerilog, but Yosys accepts it and builds `74 cells`, six times as many as the `+:` form. Verilator rejects the same line (see below) |
| `$display` / `$write` | **Builds, read the fine print** | It survives into the mapped netlist as a `$print` cell, and `stat -liberty` reports `Area for cell type $print is unknown!` |
| `real`, `shortreal` | **Hard error** | `ERROR: syntax error, unexpected TOK_REAL` |
| `#5` and other delays | **Vanishes** | Yosys turns `#5 q = d;` into `assign q = d;` with zero warnings. In hardware, delay is something your transistors cause, not something you can ask for |

## Four rows in detail

### `unique case`

If a plain `case` in an `always_comb` block is missing a branch, Yosys refuses to build it:

```
ERROR: Latch inferred for signal `\u_case_nodefault.\y' from always_comb process
       `\u_case_nodefault.$proc$u_case_nodefault.sv:2$1'.
```

Add `unique` to the same code and it synthesizes to `2 cells`, which do this:

```verilog
assign y[0] = s[1] | ~(s[0]);
assign y[1] = s[1] ^ s[0];
```

For `s = 2'b11` that logic gives `y = 2'b01`, a value you never wrote. `unique` told
Yosys that the case was full, so Yosys treated the missing branch as don't-care, and the optimizer
chose whatever output was cheapest.

Always write a `default:` branch, because it does the opposite of what `unique` does: `default:` says what
the output should be when nothing else matches, and `unique` tells Yosys that it doesn't matter.

> `unique` means different things in the two halves of SystemVerilog. In simulation it is a
> runtime assertion that fires if no branch matches. In synthesis it is a promise to the
> optimizer, and nothing checks that the promise is true.

### `initial`

```systemverilog
initial count = 4'd0;
always_ff @(posedge clk) count <= count + 1;
```

Yosys does tell you what it did with the `initial`, but only in the log:

```
2.2.4. Executing PROC_INIT pass (extract init attributes).
Found init rule in `\t_initial.$proc$t_initial.sv:18$3'.
  Set init value: \count = 4'0000
```

That module ships as
[`labs/lab-03-three-ways-to-lose-a-latch/examples/t_initial.sv`](https://github.com/uoftasic/dd103/blob/main/labs/lab-03-three-ways-to-lose-a-latch/examples/t_initial.sv);
the `18` in the log is the line number of the `initial` in that file. In the SKY130 netlist, all
that's left of it is this attribute:

```verilog
  (* init = 4'h0 *)
  output [3:0] count;
```

The design is `10 cells`, `4 $_DFF_P_` plus the increment logic, and none of them resets
anything. On an FPGA the attribute does something, because the bitstream can load the flops with
their initial values at configuration time. An ASIC can't do that, so if you want a known starting
value you have to build a reset:

```systemverilog
always_ff @(posedge clk) begin
    if (rst) count <= 4'd0;
    else     count <= count + 1;
end
```

### Variable-range part-selects

`d[lo+3 : lo]` with a non-constant `lo` isn't legal SystemVerilog, and Verilator says so:

```
%Error: p_range.sv:2:20: First value of [a:b] isn't a constant, maybe you want +: or -:
    2 |     assign y = d[lo+3 : lo];
      |                    ^
```

Yosys 0.68 builds it anyway, into 74 cells, against 12 for the legal `d[sel*4 +: 4]` form doing
the same job. So you end up with code that isn't portable to other tools, and with six times the hardware.

Use `+:` and `-:` for slices at a variable position. More generally, if Verilator lints your code
clean and Yosys gives an error, suspect Yosys's parser, and if Verilator gives an error and Yosys
is happy, believe Verilator.

### `$display`

This is the `stat -liberty` report for `t_display`, a module with four flops and a `$display`:

```
        5   80.077 cells
        1        -   $print
        4   80.077   sky130_fd_sc_hd__dfxtp_1

   Area for cell type $print is unknown!

   Chip area for module '\t_display': 80.076800
```

The four flops mapped to four real SKY130 cells (`sky130_fd_sc_hd__dfxtp_1`), but the `$print`
stayed unmapped, so the chip area counts only the flops. Keep `$display` in the testbench, where
it works, and out of anything you intend to synthesize.

## One-screen version

This part fits on one screen, and it's worth printing.

These are safe to use without thinking about it:

```systemverilog
logic                                   // every signal, every time
always_ff @(posedge clk)                // flops
always_comb                             // gates, with the completeness check
assign                                  // gates
typedef enum logic [1:0] { ... }        // module-local
struct packed { ... }                   // free naming for bits
generate / genvar / for                 // unrolled at elaboration
localparam, pkg::NAME                   // numbers
function f(...); f = ...; endfunction   // assign to the function's own name
default:                                // in EVERY case statement
```

Never put these in anything you will synthesize:

```systemverilog
#5, wait, @(negedge clk) in a body      // vanishes silently
$display, $monitor, $finish             // becomes a $print cell with no area
initial                                 // becomes an (* init *) attribute, not a reset
real, time, string, class, fork/join    // hard error or nonsense
unique without default:                 // disables the latch check
always @*                               // no completeness check — use always_comb
d[hi:lo] with variable bounds           // illegal SV that Yosys builds anyway, 6x the cells
```

These are legal SystemVerilog, but Yosys's built-in parser rejects them anyway:

```systemverilog
return inside a function                // TOK_ID
import pkg::* in a module header/body   // TOK_IMPORT
'{field: value} struct literals         // OP_CAST
```

The trouble with that last group is in Yosys's parser, not in the hardware. The constructs
describe synthesizable logic and commercial tools accept them, and your container ships two ways
around the parser, described in
[When Yosys says syntax error](../reference/yosys-syntax-errors.md).

## Related

- [Synthesizable SystemVerilog](../guide/the-hardware-dialect.md): why this boundary exists
- [Inferred latches](../guide/the-latch-you-didnt-ask-for.md): the `unique` / `always @*` trap, with
  a lab
- [Reading the `stat` report](../guide/reading-stat.md): how to check any of these numbers against
  your own run
