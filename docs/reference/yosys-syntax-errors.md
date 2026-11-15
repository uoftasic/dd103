# When Yosys says syntax error

Use this page when Yosys reports `syntax error` on code that looks fine to you. Quite often
the code really is fine, and the problem is that Yosys can't parse it.

## Reading the message

```
ERROR: syntax error, unexpected TOK_IMPORT, expecting '#' or '(' or ';'
```

The message has three parts:

| Part | Means |
|---|---|
| `TOK_IMPORT` | the token Yosys was reading when it stopped, here the keyword it couldn't handle |
| `expecting '#' or '(' or ';'` | what its grammar allowed there instead |
| the line number | where the token is, which is not always where your mistake is |

`TOK_` is short for "token", and the name after it is the parser's internal name for the keyword.
So `TOK_IMPORT` is `import` and `TOK_REAL` is `real`. `TOK_ID`, the most confusing one, means "some
identifier", which is what `return` looks like to a parser that has never heard of `return`.

## Why it happens

Yosys has its own hand-written Verilog front end, which grew out of a Verilog-2005 parser.
SystemVerilog support was added to it one construct at a time, and some constructs were never
added.

Two very different problems produce the same red text:

- A physics limit: `#5` will never synthesize, in any tool, at any price, because there is no gate
  whose function is "be late". No workaround helps with that, and none should.
- A parser gap: `return` inside a function and `import pkg::*` inside a module are synthesizable
  ideas, and commercial tools accept both, but Yosys's built-in front end never learned the
  grammar for them. A parser gap is fixable, and your container already has two fixes installed.

So the skill to learn is telling the two apart, and the next step does that in about three
seconds.

## Step 1: ask Verilator

Verilator is a complete SystemVerilog parser, and it is already in your image. If Verilator lints
your file without errors, your SystemVerilog is valid and the problem is in Yosys's front end.

```bash
verilator --lint-only --top alu alu.sv
```

```
- V e r i l a t i o n   R e p o r t: Verilator 5.050 2026-07-01 rev v5.050
- Verilator: Built from 0.031 MB sources in 3 modules, into 0.012 MB in 3 C++ files needing 0.000 MB
```

Verilator reports no errors, so the file is legal SystemVerilog. The gap is in Yosys, and Step 2
is what you need.

If Verilator reports errors too, your code needs fixing: find the construct's row in
[The synthesizable subset](../reference/synthesizable-subset.md). This happens more often than
students expect, as in this example:

```
%Error: p_range.sv:2:20: First value of [a:b] isn't a constant, maybe you want +: or -:
    2 |     assign y = d[lo+3 : lo];
      |                    ^
```

> Verilator and Yosys disagree in both directions. Verilator rejects some things Yosys builds
> (that variable range select) and accepts some things Yosys refuses (`return`). Neither tool
> defines the language, but when they disagree, Verilator is the one following the standard.

## Worked example

Here is an ALU written the way a textbook would write it, with an enum in a package, a function
that uses `return`, and a package import in the module header.

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

Verilator lints it without errors. Here is what Yosys does with it:

```bash
yosys -p "read_verilog -sv alu.sv; synth -top alu; stat"
```

```
Parsing SystemVerilog input from `alu.sv' to AST representation.
alu.sv:7: ERROR: syntax error, unexpected TOK_IMPORT, expecting '#' or '(' or ';'
```

Yosys never reaches the `return` on line 19, because its parser stops at the first thing it
doesn't know. Fixing one syntax error often just reveals the next one, so don't conclude that your
file has only one problem because Yosys reported only one.

## Step 2, option one: `read_slang`

The image ships a second, complete SystemVerilog front end for Yosys as a plugin, which you can find
here:

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

So the same file that couldn't get past line 7 now synthesizes to 108 cells.

Two things are worth knowing about how you invoke it:

- `-m slang` on the `yosys` command line and `plugin -i slang;` as the first command inside `-p`
  do the same thing, so use whichever fits your script.
- `--top NAME` is optional, but you'll want it. Slang elaborates the whole design at once, so
  naming the top module stops it from elaborating modules you didn't mean it to.

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

Notice that the second line uses `read_verilog` without `-sv`, because `alu.v` is no longer
SystemVerilog. Here is the start of what `sv2v` produced:

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

The package is gone, and `WIDTH` has become a `localparam` named `alu_pkg_WIDTH`, flattened into
the module. `logic` has become `wire` and `reg`, and the enum is now a plain `[1:0]`. The
`_sv2v_jump` variable is how `sv2v` emulates `return` in a language that has no `return`. The
result is ugly and entirely mechanical, but it works.

## Hardware from each option

The reason you can trust either option is that both give you the same hardware, and it's worth
checking that for yourself. Map both through to SKY130:

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

Both paths give 79 cells and 509.2384 µm², identical to four decimal places. The two front ends
disagree about grammar but agree completely about the hardware, which is what you want from a
front end.

> `abc -liberty` prints roughly a hundred lines of
> `Scl_LibertyReadGenlib() skipped sequential cell ...` before it does anything useful. That's
> normal output, and it doesn't mean anything is wrong.

## Which option to use

| | `read_slang` | `sv2v` |
|---|---|---|
| how it works | a real SV front end inside Yosys | rewrites your file to Verilog-2005 first |
| SV coverage | broad, since it is the `slang` compiler | broad, though it occasionally handles corner cases differently |
| debugging | the netlist maps back to your own source | you get a second file to read, which is sometimes useful |
| extra artifact | none | a `.v` you have to keep in sync |
| in LibreLane | one config line, see below | you must run `sv2v` yourself first |

Use `read_slang` by default, and use `sv2v` when you want to see what your SystemVerilog means,
which is useful the first time you meet an interface or a parameterized package.

## In the LibreLane flow

Slang works in the LibreLane flow too. Older write-ups say it doesn't, so it's worth checking for
yourself: LibreLane 3.1.0.dev3 has a config variable for it.

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

Two things in that definition matter. The default is `False`, so you get Yosys's built-in parser
unless you ask for slang. And `USE_SYNLIG`, the name older documentation tells you to set, is a
deprecated alias for `USE_SLANG`. Synlig itself isn't installed in this image, but slang is.

Here is the same ALU with its output registered, run through the real flow. `alu_reg.sv` is a
one-off wrapper we made for this page (`src/alu.sv` with its outputs flopped), so you won't find it
in the lab packages. To reproduce the result, try the flag on a SystemVerilog design of your own,
and keep in mind that the areas below belong to our wrapper. This is the run without the flag:

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

It's worth reading those lines together. `Check for Lint errors clear.` means Verilator, the
full SystemVerilog parser, has accepted your file, and one step later Yosys stops at line 7. Those four
lines of log show the whole problem this page is about, and they're why "my code looks fine" is
usually a correct observation.

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

With the flag on, the file that couldn't get past line 7 becomes a finished chip layout with no
violations, in 64 seconds.

## Triage, in order

1. Read the token. `TOK_IMPORT` means an `import` in the wrong place. `TOK_ID` after a `return`
   points at the function. `TOK_REAL` means you should delete the `real`.
2. Run Verilator: `verilator --lint-only --top NAME f.sv`. If it's clean, the Yosys parser is at
   fault, and if it reports errors, your code is.
3. Look up the construct in [The synthesizable subset](../reference/synthesizable-subset.md). Some
   have a one-line fix worth taking, such as `pkg::NAME` instead of `import pkg::*`, or assigning
   to the function's own name instead of `return`.
4. Otherwise, use `-m slang` with `read_slang`, or `sv2v f.sv > f.v`. Both are installed, and both
   produce the same gates.
5. Set `"USE_SLANG": true` in your LibreLane `config.json` so the flow reads the file the same way
   your `read_slang` run did.

## Physics limits and the workarounds

Don't reach for slang or `sv2v` before you've read the token, because they fix parser gaps and
do nothing for physics limits. `read_slang` will happily parse `#5`, and Yosys will still throw the
delay away without a word, because there is still no gate that waits.

If the construct is in the "never in anything you will synthesize" list in
[The synthesizable subset](../reference/synthesizable-subset.md), no front end will help, and the
construct belongs in your testbench instead.

## Related

- [Synthesizable SystemVerilog](../guide/the-hardware-dialect.md): physics limits and parser gaps, at
  length
- [The synthesizable subset](../reference/synthesizable-subset.md): which of the two you are looking
  at, per construct
- [From netlist to layout](../guide/from-gates-to-geometry.md): the LibreLane `config.json` format,
  which is where you would add `USE_SLANG`
