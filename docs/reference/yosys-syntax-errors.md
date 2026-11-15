# When Yosys says syntax error

Use this page when Yosys reports `syntax error` on code that looks fine. Often the code is fine.

## Reading the message

```
ERROR: syntax error, unexpected TOK_IMPORT, expecting '#' or '(' or ';'
```

The message has three parts:

| Part | Means |
|---|---|
| `TOK_IMPORT` | the token Yosys was reading: the keyword it choked on |
| `expecting '#' or '(' or ';'` | what its grammar allowed there instead |
| the line number | where the token is, which is not always where your mistake is |

`TOK_` is short for "token", and the name after it is the parser's internal name for the keyword.
So `TOK_IMPORT` is `import` and `TOK_REAL` is `real`. `TOK_ID`, the most confusing one, means "some
identifier", which is what `return` looks like to a parser that has never heard of `return`.

## Why it happens

Yosys has its own hand-written Verilog front end. It grew out of a Verilog-2005 parser, and
SystemVerilog support was added to it one construct at a time. Some constructs were never added.

Two very different problems produce the same red text:

- A physics limit. `#5` will never synthesize, in any tool, at any price, because there is no gate
  whose function is "be late". No workaround helps, and none should.
- A parser gap. `return` inside a function and `import pkg::*` inside a module are synthesizable
  ideas, and commercial tools accept both. Yosys's built-in front end never learned the grammar.
  This is fixable, and your container already has two fixes installed.

Telling the two apart is the skill. The next step settles it in three seconds.

## Step 1: ask Verilator

Verilator is a complete SystemVerilog parser, and it is already in your image. If Verilator lints
your file clean, your SystemVerilog is valid and the problem is Yosys's front end.

```bash
verilator --lint-only --top alu alu.sv
```

```
- V e r i l a t i o n   R e p o r t: Verilator 5.050 2026-07-01 rev v5.050
- Verilator: Built from 0.031 MB sources in 3 modules, into 0.012 MB in 3 C++ files needing 0.000 MB
```

No errors, so the file is legal. Yosys has the gap, and Step 2 applies.

If Verilator errors too, fix your code: find the row in
[The synthesizable subset](../reference/synthesizable-subset.md). This happens more often than
students expect:

```
%Error: p_range.sv:2:20: First value of [a:b] isn't a constant, maybe you want +: or -:
    2 |     assign y = d[lo+3 : lo];
      |                    ^
```

> Verilator is stricter than Yosys in both directions. It rejects things Yosys builds (that
> variable range select) and accepts things Yosys refuses (`return`). Neither tool is the
> language, but when they disagree, Verilator is the one following the standard.

## Worked example

Here is an ALU written the way a textbook writes one: an enum in a package, a function with
`return`, and a header import.

```systemverilog
package alu_pkg;
    typedef enum logic [1:0] { OP_ADD, OP_SUB, OP_AND, OP_XOR } op_e;
    localparam int WIDTH = 8;
endpackage

module alu
    import alu_pkg::*;
(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  op_e              op,
    output logic [WIDTH-1:0] y,
    output logic             zero
);
    function automatic logic [WIDTH-1:0] apply (input op_e o,
                                                input logic [WIDTH-1:0] x,
                                                input logic [WIDTH-1:0] z);
        case (o)
            OP_ADD: return x + z;
            OP_SUB: return x - z;
            OP_AND: return x & z;
            OP_XOR: return x ^ z;
        endcase
        return '0;
    endfunction

    always_comb begin
        y    = apply(op, a, b);
        zero = (y == '0);
    end
endmodule
```

The full source ships as `src/alu.sv` in
[Lab 02](https://github.com/uoftasic/dd103/tree/main/labs/lab-02-rtl-becomes-gates/src/alu.sv), so
you can reproduce every line below.

Verilator lints it clean. Yosys:

```bash
yosys -p "read_verilog -sv alu.sv; synth -top alu; stat"
```

```
Parsing SystemVerilog input from `alu.sv' to AST representation.
alu.sv:7: ERROR: syntax error, unexpected TOK_IMPORT, expecting '#' or '(' or ';'
```

It never reaches the `return` on line 19, because the parser stops at the first thing it doesn't
know. Fixing one syntax error often reveals the next, so don't conclude your file has one problem
because Yosys reported one.

## Step 2, option one: `read_slang`

The image ships a second, complete SystemVerilog front end for Yosys as a plugin. It is here:

```bash
ls -l /foss/tools/yosys/share/yosys/plugins/slang.so
```

```
lrwxrwxrwx 1 root root 39 Apr 17 13:39 /foss/tools/yosys/share/yosys/plugins/slang.so
    -> /foss/tools/slang-yosys-plugin/slang.so
```

Load it with `-m slang` and replace `read_verilog -sv` with `read_slang`:

```bash
yosys -m slang -p "read_slang --top alu alu.sv; synth -top alu; stat"
```

```
Build succeeded: 0 errors, 0 warnings

=== alu ===

      108 cells
        2   $_ANDNOT_
       18   $_AND_
        7   $_MUX_
       30   $_NAND_
        1   $_NOR_
        1   $_ORNOT_
       27   $_OR_
       16   $_XNOR_
        6   $_XOR_
```

The file that could not get past line 7 is now 108 cells.

Two notes on invocation:

- `-m slang` on the `yosys` command line and `plugin -i slang;` as the first command inside `-p`
  do the same thing. Use whichever fits your script.
- `--top NAME` is optional, but you want it. Slang elaborates the whole design at once, so naming
  the top module stops it from elaborating modules you did not mean.

## Step 2, option two: `sv2v`

`sv2v` is a separate program that rewrites SystemVerilog into plain Verilog-2005, which Yosys's own
front end has always handled well.

```bash
sv2v --version
```

```
sv2v v0.0.13-11-g6662fa5
```

```bash
sv2v alu.sv > alu.v
yosys -p "read_verilog alu.v; synth -top alu; stat"
```

Note `read_verilog` with no `-sv` on the second line: `alu.v` is no longer SystemVerilog. Here is
what `sv2v` produced:

```verilog
module alu (
	a,
	b,
	op,
	y,
	zero
);
	reg _sv2v_0;
	localparam signed [31:0] alu_pkg_WIDTH = 8;
	input wire [7:0] a;
	input wire [7:0] b;
	input wire [1:0] op;
	output reg [7:0] y;
	output reg zero;
	function automatic [7:0] apply;
		input reg [1:0] o;
		input reg [7:0] x;
		input reg [7:0] z;
		reg [1:0] _sv2v_jump;
		begin
```

The package is gone: `WIDTH` became a `localparam` named `alu_pkg_WIDTH`, flattened into the
module. `logic` became `wire` and `reg`, and the enum became a plain `[1:0]`. The `_sv2v_jump`
variable is how `sv2v` emulates `return` in a language that has no `return`. It is ugly and
entirely mechanical, and it works.

## Hardware from each option

This is the reason you can trust either one, so it is worth checking yourself. Map both through
to SKY130:

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# via slang
yosys -m slang -p "read_slang --top alu alu.sv; synth -top alu;
                   abc -liberty $LIB; opt_clean; stat -liberty $LIB"

# via sv2v
sv2v alu.sv > alu.v
yosys -p "read_verilog alu.v; synth -top alu;
          abc -liberty $LIB; opt_clean; stat -liberty $LIB"
```

Both print:

```
       79  509.238 cells
   Chip area for module '\alu': 509.238400
```

That is 79 cells and 509.2384 µm² from both paths, identical to four decimal places. The two front
ends disagree about grammar and agree completely about hardware, which is what you want from a
front end.

> `abc -liberty` prints roughly a hundred lines of
> `Scl_LibertyReadGenlib() skipped sequential cell ...` before it does anything useful. That is
> normal output and does not mean anything is wrong.

## Which option to use

| | `read_slang` | `sv2v` |
|---|---|---|
| how it works | a real SV front end inside Yosys | rewrites your file to Verilog-2005 first |
| SV coverage | broad; it is the `slang` compiler | broad, occasionally different corners |
| debugging | the netlist maps to your source | you get a second file to read, which is sometimes useful |
| extra artifact | none | a `.v` you have to keep in sync |
| in LibreLane | one config line, see below | you must run `sv2v` yourself first |

Use `read_slang` by default. Use `sv2v` when you want to see what your SystemVerilog means, which
is useful the first time you meet an interface or a parameterized package.

## In the LibreLane flow

Slang works in the LibreLane flow too. Older write-ups say otherwise, so it is worth checking for
yourself. LibreLane 3.1.0.dev3 has a config variable for it:

```
Variable(
    "USE_SLANG",
    bool,
    "Use the Slang frontend to process files, which has better SystemVerilog
     parsing capabilities but is not as battle-tested as the default Yosys friend.",
    default=False,
    deprecated_names=["USE_SYNLIG"],
),
```

Two things matter there. The default is `False`, so you get Yosys's built-in parser unless you ask.
And `USE_SYNLIG`, the name older documentation tells you to set, is a deprecated alias for it.
Synlig is not installed in this image; slang is.

Here is the same ALU with its output registered, run through the real flow. `alu_reg.sv` is a
one-off wrapper made for this page (`src/alu.sv` with its outputs flopped), so it is not in the lab
packages. Reproduce the flag on a SystemVerilog design of your own; the areas below belong to that
wrapper. Without the flag:

```json
{
  "DESIGN_NAME": "alu_reg",
  "VERILOG_FILES": ["dir::src/*.sv"],
  "PDK": "sky130A",
  "STD_CELL_LIBRARY": "sky130_fd_sc_hd",
  "USE_SLANG": false,
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": 20
}
```

```
───────────────────────── Lint Errors Checker ─────────────────────────
[00:14:54] INFO     Check for Lint errors clear.
[00:14:54] VERBOSE  Running 'Yosys.JsonHeader' at ...
/work/src/alu_reg.sv:7: ERROR: syntax error, unexpected TOK_IMPORT, expecting
[00:14:54] ERROR    Subprocess had a non-zero exit.
```

Read those lines together. `Check for Lint errors clear.` is Verilator, the full SystemVerilog
parser, accepting your file. One step later Yosys stops at line 7. That sequence is this whole page
in four lines of log, and it is why "my code looks fine" is usually a correct observation.

Now change one value:

```json
  "USE_SLANG": true,
```

```
real	1m3.624s
```

| Metric | Value |
|---|---|
| die area | 3641.21 µm² |
| core area | 1921.84 µm² |
| utilization | 69.9 % |
| setup worst slack | +10.92 ns (20 ns clock) |
| antenna violations | 0 |
| total violations | 0 |
| GDS | 435,700 bytes |

That is a finished, clean chip layout from the file that could not get past line 7, in 64 seconds.

## Triage, in order

1. Read the token. `TOK_IMPORT` means an `import` in the wrong place. `TOK_ID` after a `return`
   means the function. `TOK_REAL` means delete the `real`.
2. Run Verilator: `verilator --lint-only --top NAME f.sv`. Clean means the problem is the Yosys
   parser; errors mean the problem is your code.
3. Look up the construct in [The synthesizable subset](../reference/synthesizable-subset.md). Some
   have a one-line fix worth taking, such as `pkg::NAME` instead of `import pkg::*`, or assigning
   to the function's own name instead of `return`.
4. Otherwise, use `-m slang` with `read_slang`, or `sv2v f.sv > f.v`. Both are installed and both
   produce the same gates.
5. Set `"USE_SLANG": true` in your LibreLane `config.json` so the flow reads the file the same way
   your Yosys lab did.

## Physics limits and the workarounds

Don't reach for slang or `sv2v` before you have read the token. They fix parser gaps and do
nothing for physics limits. `read_slang` will happily parse `#5`, and Yosys will still throw it
away without a word, because there is still no gate that waits.

If the construct is in the "never in anything you will synthesize" list in
[The synthesizable subset](../reference/synthesizable-subset.md), no front end will help. Move it to
your testbench.

## Related

- [Synthesizable SystemVerilog](../guide/the-hardware-dialect.md): physics limits and parser gaps, at
  length
- [The synthesizable subset](../reference/synthesizable-subset.md): which of the two you are looking
  at, per construct
- [From netlist to layout](../guide/from-gates-to-geometry.md): the LibreLane `config.json` format,
  which is where you would add `USE_SLANG`
