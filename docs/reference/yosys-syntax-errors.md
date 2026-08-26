# When Yosys says syntax error

**Question this page answers:** *Yosys says `syntax error` and my code looks fine. Now what?*

Your code probably **is** fine. Expect to hit this at least once.

## The shape of the message

```
ERROR: syntax error, unexpected TOK_IMPORT, expecting '#' or '(' or ';'
```

Three parts, and each one tells you something:

| Part | Means |
|---|---|
| `TOK_IMPORT` | the token Yosys was reading — this is the keyword it choked on |
| `expecting '#' or '(' or ';'` | what its grammar allowed there instead |
| the line number | where the token is — but **not always where your mistake is** |

`TOK_` is short for "token". The name after it is the internal name for the keyword. So
`TOK_IMPORT` is `import`, `TOK_REAL` is `real`, and `TOK_ID` — the most confusing one — just
means "some identifier", which is what `return` looks like to a parser that has never heard of
`return`.

## Why this happens at all

Yosys has its own hand-written Verilog front end. It grew out of a **Verilog-2005** parser,
and SystemVerilog support was added to it construct by construct over the years. Some
constructs never got added.

This is worth being precise about, because two very different things produce the same red
text:

**A physics limit.** `#5` will never synthesize, in any tool, at any price. There is no gate
whose function is "be late". No escape hatch helps and none should.

**A parser gap.** `return` inside a function and `import pkg::*` inside a module are perfectly
synthesizable ideas. Commercial tools accept both. Yosys's built-in front end simply never
learned the grammar. This *is* fixable, and your container already has two fixes installed.

**Telling the two apart is the whole skill.** Here is the test that settles it in three
seconds.

## Step 1 — ask Verilator

Verilator is a complete SystemVerilog parser and it is already in your image. If Verilator
lints your file clean, your SystemVerilog is valid and the problem is Yosys's front end.

```bash
verilator --lint-only --top alu alu.sv
```

```
- V e r i l a t i o n   R e p o r t: Verilator 5.046 2026-02-28 rev v5.046
- Verilator: Built from 0.031 MB sources in 3 modules, into 0.012 MB in 3 C++ files needing 0.000 MB
```

No errors. So the file is legal. Yosys is the one with the gap, and Step 2 applies.

If Verilator errors too, **fix your code** — go back to
[The synthesizable subset](reference/synthesizable-subset.md) and find the row. This happens
more often than students expect:

```
%Error: p_range.sv:2:20: First value of [a:b] isn't a constant, maybe you want +: or -:
    2 |     assign y = d[lo+3 : lo];
      |                    ^
```

> Verilator is stricter than Yosys in both directions. It rejects things Yosys builds (that
> variable range select) and accepts things Yosys refuses (`return`). Neither tool is the
> language. When they disagree, Verilator is the one following the standard.

## The worked example

Here is an ALU written the way a textbook writes one. Nothing exotic — an enum in a package,
a function with `return`, a header import:

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

Full source ships as `src/alu.sv` in
[Lab 02](https://github.com/uoftasic/dd103/tree/main/labs/lab-02-rtl-becomes-gates/src/alu.sv),
so you can reproduce every line below.

Verilator lints it clean. Yosys:

```bash
yosys -p "read_verilog -sv alu.sv; synth -top alu; stat"
```

```
Parsing SystemVerilog input from `alu.sv' to AST representation.
alu.sv:7: ERROR: syntax error, unexpected TOK_IMPORT, expecting '#' or '(' or ';'
```

It never even reaches the `return` on line 19 — the parser dies at the first thing it does not
know. **Fixing one syntax error often just reveals the next one.** Do not conclude your file
has one problem because Yosys reported one.

## Step 2 — escape hatch one: `read_slang`

The image ships a second, complete SystemVerilog front end for Yosys as a plugin. Confirm it
is there:

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

The same file that could not get past line 7 is now **108 cells**.

Two notes on invocation:

- `-m slang` on the `yosys` command line and `plugin -i slang;` as the first command inside
  `-p` do the same thing. Use whichever fits your script.
- `--top NAME` is optional but you want it. Slang elaborates the whole design at once, so
  telling it the top module up front avoids it elaborating modules you did not mean.

## Step 2 — escape hatch two: `sv2v`

`sv2v` is a separate program that rewrites SystemVerilog down into plain Verilog-2005, which
Yosys's own front end has always handled well.

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

Note `read_verilog` with **no `-sv`** on the second line — the whole point is that `alu.v` is
no longer SystemVerilog. Look at what `sv2v` produced:

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

The package is gone — `WIDTH` became a `localparam` named `alu_pkg_WIDTH`, flattened into the
module. `logic` became `wire` and `reg`. The enum became a plain `[1:0]`. And that
`_sv2v_jump` variable is how `sv2v` emulates `return` in a language that has no `return`.

Ugly, and completely mechanical, and it works.

## The two hatches give identical hardware

This is the part worth checking yourself, because it is the reason you can trust either one.
Map both through to SKY130:

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

Both:

```
       79  509.238 cells
   Chip area for module '\alu': 509.238400
```

**79 cells, 509.2384 µm², from both paths.** Not close — identical, to four decimal places.
The two front ends disagree about grammar and agree completely about hardware, which is
exactly what you want from a front end.

> `abc -liberty` prints roughly a hundred lines of
> `Scl_LibertyReadGenlib() skipped sequential cell ...` before it does anything useful. That
> wall of warnings is normal and means nothing is wrong.

## Which hatch to use

| | `read_slang` | `sv2v` |
|---|---|---|
| how it works | a real SV front end inside Yosys | rewrites your file to Verilog-2005 first |
| SV coverage | broad — it is the `slang` compiler | broad, occasionally different corners |
| debugging | the netlist maps to your source | you get a second file to read, which is sometimes a gift |
| extra artifact | none | a `.v` you have to keep in sync |
| in LibreLane | one config line — see below | you must run `sv2v` yourself first |

Reach for `read_slang` by default. Reach for `sv2v` when you want to *see* what your
SystemVerilog means, which is genuinely useful the first time you meet an interface or a
parameterized package.

## Does this survive into the LibreLane flow?

Yes — and check this yourself, because older write-ups say otherwise.

LibreLane 3.0.2 has a config variable for exactly this:

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

Two things in there matter. The default is **`False`**, so you get Yosys's built-in parser
unless you ask. And `USE_SYNLIG` — the name older documentation tells you to set — is a
**deprecated alias** for it. Synlig is not installed in this image; slang is.

Take the same ALU, register its output, and run the real flow. Without the flag:

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

Read those two lines together. **`Check for Lint errors clear.`** — that is Verilator, the
full SystemVerilog parser, signing off on your file. One step later Yosys chokes on line 7.
That sequence is this entire page in four lines of log, and it is why "my code looks fine" is
usually a correct observation.

Now flip one character:

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
| setup worst slack | **+10.92 ns** (20 ns clock) |
| antenna violations | **0** |
| total violations | **0** |
| GDS | 435,700 bytes |

A finished, clean chip layout, from the file that could not get past line 7, in **64 seconds**.

## Triage, in order

1. **Read the token.** `TOK_IMPORT` → an `import` in the wrong place. `TOK_ID` after a
   `return` → the function. `TOK_REAL` → delete the `real`.
2. **Run Verilator.** `verilator --lint-only --top NAME f.sv`. Clean means the problem is the
   Yosys parser; errors mean the problem is your code.
3. **Look up the construct** in [The synthesizable subset](reference/synthesizable-subset.md).
   Some of these have a one-line fix worth taking — `pkg::NAME` instead of `import pkg::*`,
   or assigning to the function's own name instead of `return`.
4. **Otherwise take a hatch.** `-m slang` + `read_slang`, or `sv2v f.sv > f.v`. Both are
   installed; both produce the same gates.
5. **Set `"USE_SLANG": true`** in your LibreLane `config.json` so the finale reads the same
   file the same way your Yosys lab did.

## The trap in step 3

Do not reach for a hatch before you have read the token. The hatches fix **parser gaps** and
they do nothing at all for **physics limits**. `read_slang` will happily parse `#5` and Yosys
will still throw it away without a word, because there is still no gate that waits.

If the construct is in the "never becomes hardware" list on
[The synthesizable subset](reference/synthesizable-subset.md), no front end will save it. Move
it to your testbench.

## Related

- [The hardware dialect](guide/the-hardware-dialect.md) — the physics limit versus the parser
  gap, at length
- [The synthesizable subset](reference/synthesizable-subset.md) — which of the two you are
  looking at, per construct
- [From gates to geometry](guide/from-gates-to-geometry.md) — where `USE_SLANG` goes in the
  `config.json` you write for the capstone
