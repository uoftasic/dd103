# The synthesizable subset

**Question this page answers:** *Can I use this construct, and what happens if I can't?*

A lookup table, not a reading assignment. Find your construct, read the verdict, move on.

Every row was run. The method, for every entry:

```bash
yosys -p "read_verilog -sv f.sv; synth -top f; stat"
```

on **Yosys 0.68** (`git sha1 38e001a6f`) in `hpretl/iic-osic-tools:2026.08`. The cell counts
are generic Yosys gates from `synth`, before any technology mapping — they are there so you
can check your own run against them, and so you can see when a construct costs more than you
thought.

Check your tool first. If `yosys -V` does not say `0.64`, these numbers are not yours:

```bash
yosys -V
```

```
Yosys 0.68 (git sha1 38e001a6f, Release, GNU /usr/bin/c++ 13.3.0)
```

## How to read the verdict column

| | meaning |
|---|---|
| **Builds** | synthesizes, and the hardware is what you meant |
| **Builds — read the fine print** | synthesizes, and the hardware may not be what you meant |
| **Hard error** | Yosys stops. Exit code 1. You will see the error text quoted in the row |
| **Vanishes** | accepted, silently discarded, zero warnings |

The middle two rows are the ones that cost people days.

## The table

| Construct | Verdict | What actually happens |
|---|---|---|
| `logic` | **Builds** | The only type you need. `1 $_AND_` for a two-input AND. Yosys decides wire-or-flop from how you drive it, not from the keyword |
| `always_ff @(posedge clk)` | **Builds** | `1 $_SDFF_PP0_` for a flop with synchronous reset. The `_ff` suffix makes Yosys check that you really made a flop |
| `always_comb` | **Builds** | `1 $_ANDNOT_` for a 2-bit case. Yosys **errors** if a branch is missing — that check is the reason to prefer it over `always @*` |
| `always @*` | **Builds — read the fine print** | No completeness check at all. An `if` with no `else` gives you `1 $_DLATCH_P_` and **zero warnings**. Use `always_comb` |
| `typedef enum logic [1:0]`, module-local | **Builds** | A 3-state FSM lowers to `5 cells`: `2 $_DFF_P_` plus `1 $_AND_`, `1 $_ANDNOT_`, `1 $_NOR_`. Enum names disappear; only the encoding survives |
| packed `struct` | **Builds** | **Zero cells.** A packed struct is a naming scheme for bits you already had. `20 wire bits`, no gates. Free |
| struct literal `'{high: h, low: l}` | **Hard error** | `ERROR: syntax error, unexpected OP_CAST`. Assign fields one at a time, or concatenate |
| `generate` / `genvar` / `endgenerate` | **Builds** | `for (i=0;i<4;i++)` producing four inverters gives exactly `4 $_NOT_`. The loop runs at elaboration; nothing loops in silicon |
| `for` inside `always_comb` | **Builds** | An 8-bit XOR reduction gives `7 cells` — `6 $_XNOR_ + 1 $_XOR_`. Unrolled into a tree, not a loop |
| `interface` + `modport` | **Builds — read the fine print** | Genuinely elaborates: the netlist gains a module named `dev_m$interfaces$bus_if` and the connectivity is correct. But Yosys emits `Warning: Identifier '\p.req' is implicitly declared` for **every** interface signal. The warnings are noise; a typo'd signal name produces the identical warning, so you lose your typo detector |
| `initial` | **Vanishes — see below** | Not an error. Becomes `(* init = 4'h0 *)`, an attribute, in the final SKY130 netlist. **Zero gates of reset logic.** Honoured on FPGA, meaningless on ASIC |
| `function`, assigning to its own name | **Builds** | `4 $_NOT_`. This is the form that works |
| `return` inside a `function` | **Hard error** | `ERROR: syntax error, unexpected TOK_ID` (or `unexpected '~'`, or whatever token follows `return`). Every textbook uses this. Yosys's built-in parser does not implement it |
| `task` | **Builds** | A task called from `always_ff` gives `4 $_DFF_P_` — identical to writing the body inline. Tasks with timing controls inside are a different story and do not synthesize |
| `import pkg::*` at **file scope** | **Builds** | `4 $_NOT_`. Outside and above the module, this works |
| `import pkg::*` in the **module header** | **Hard error** | `ERROR: syntax error, unexpected TOK_IMPORT, expecting '#' or '(' or ';'` |
| `import pkg::*` in the **module body** | **Hard error** | `ERROR: syntax error, unexpected TOK_IMPORT` |
| `pkg::NAME` fully qualified | **Builds** | `4 $_NOT_`. Always works. This is the portable way to use a package |
| `unique case` | **Builds — read the fine print** | It **disables the missing-branch check**. Identical code without `unique` is a hard `ERROR: Latch inferred`; with `unique` it silently builds don't-care logic. See below |
| `priority if` / `priority case` | **Builds** | A 3-input priority encoder gives `3 cells`. `priority` matches the plain `if`/`else if` semantics you already had, so it changes nothing |
| `d[sel*4 +: 4]` — indexed part-select | **Builds** | `12 $_MUX_`. The legal way to select a variable slice |
| `d[i]` — variable bit-select | **Builds** | `19 cells`. A 16-to-1 mux, as you would expect |
| `d[lo+3 : lo]` — variable range | **Builds — read the fine print** | **Yosys accepts illegal SystemVerilog here.** `74 cells` — six times the `+:` form. Verilator refuses the same line (see below) |
| `$display` / `$write` | **Builds — read the fine print** | Survives to the mapped netlist as a `$print` cell. `stat -liberty` reports `Area for cell type $print is unknown!` |
| `real`, `shortreal` | **Hard error** | `ERROR: syntax error, unexpected TOK_REAL` |
| `#5` and other delays | **Vanishes** | `#5 q = d;` becomes `assign q = d;`. **Zero warnings.** Delay is a consequence of your transistors, never a request |

## The four rows worth expanding

### `unique case` switches off your safety net

Plain `case` with a branch missing — Yosys refuses:

```
ERROR: Latch inferred for signal `\u_case_nodefault.\y' from always_comb process
       `\u_case_nodefault.$proc$u_case_nodefault.sv:2$1'.
```

Add `unique` to the identical code and it synthesizes to `2 cells`:

```verilog
assign y[0] = s[1] | ~(s[0]);
assign y[1] = s[1] ^ s[0];
```

For `s = 2'b11` that returns `y = 2'b01`, a value you never wrote. `unique` told Yosys the
case was full, so the missing branch became don't-care and the optimizer chose whatever was
cheapest.

**Rule: always write `default:`. `unique` is not a substitute for it — it is the opposite of
one.**

> `unique` means different things in the two halves of SystemVerilog. In simulation it is a
> runtime assertion that fires if no branch matches. In synthesis it is a promise you are
> making to the optimizer. Nothing checks that the promise is true.

### `initial` is an attribute, not a reset

```systemverilog
initial count = 4'd0;
always_ff @(posedge clk) count <= count + 1;
```

Yosys tells you what it did, if you read the log:

```
2.2.4. Executing PROC_INIT pass (extract init attributes).
Found init rule in `\t_initial.$proc$t_initial.sv:18$3'.
  Set init value: \count = 4'0000
```

(That module ships as
[`labs/lab-03-three-ways-to-lose-a-latch/examples/t_initial.sv`](https://github.com/uoftasic/dd103/blob/main/labs/lab-03-three-ways-to-lose-a-latch/examples/t_initial.sv);
the `18` is the line the `initial` sits on in that file.)

and the SKY130 netlist ends up holding this:

```verilog
  (* init = 4'h0 *)
  output [3:0] count;
```

The design is `10 cells` — `4 $_DFF_P_` plus the increment logic — and not one of them
resets anything. An FPGA bitstream can load flops at configuration time, so the attribute is
real there. An ASIC cannot. Build a reset:

```systemverilog
always_ff @(posedge clk) begin
    if (rst) count <= 4'd0;
    else     count <= count + 1;
end
```

### Yosys is *more* permissive than SystemVerilog on part-selects

`d[lo+3 : lo]` with a non-constant `lo` is not legal SystemVerilog. Verilator says so:

```
%Error: p_range.sv:2:20: First value of [a:b] isn't a constant, maybe you want +: or -:
    2 |     assign y = d[lo+3 : lo];
      |                    ^
```

Yosys 0.68 builds it anyway — **74 cells**, versus **12** for the legal `d[sel*4 +: 4]` form
doing the same job. You get non-portable code and six times the hardware.

**Rule: use `+:` and `-:`. If Verilator lints clean and Yosys errors, suspect the parser. If
Verilator errors and Yosys is happy, believe Verilator.**

### `$display` becomes a cell that has no area

```
        5   80.077 cells
        1        -   $print
        4   80.077   sky130_fd_sc_hd__dfxtp_1

   Area for cell type $print is unknown!

   Chip area for module '\t_display': 80.076800
```

Four flops mapped to four real cells. The `$print` did not. Strip `$display` out of anything
you intend to synthesize and keep it in the testbench, where it belongs and where it works.

## The one-screen version

Print this half.

**Use, without thinking about it:**

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

**Never, in anything you will synthesize:**

```systemverilog
#5, wait, @(negedge clk) in a body      // vanishes silently
$display, $monitor, $finish             // becomes a $print cell with no area
initial                                 // becomes a comment, not a reset
real, time, string, class, fork/join    // hard error or nonsense
unique without default:                 // disables the latch check
always @*                               // no completeness check — use always_comb
d[hi:lo] with variable bounds           // illegal SV that Yosys builds anyway, 6x the cells
```

**Legal SystemVerilog that Yosys's built-in parser rejects anyway:**

```systemverilog
return inside a function                // TOK_ID
import pkg::* in a module header/body   // TOK_IMPORT
'{field: value} struct literals         // OP_CAST
```

That last group is a parser limitation, not a hardware one — the ideas are perfectly
synthesizable and commercial tools accept them. Your container ships two ways around it:
[When Yosys says syntax error](reference/yosys-syntax-errors.md).

## Related

- [The hardware dialect](guide/the-hardware-dialect.md) — *why* this boundary exists
- [The latch you didn't ask for](guide/the-latch-you-didnt-ask-for.md) — the `unique` /
  `always @*` trap, at length, with a lab
- [Reading `stat` like a receipt](guide/reading-stat.md) — how to check any of these numbers
  against your own run
