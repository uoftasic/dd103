# A state machine is a table with a memory

**Question this page answers:** *I have a state diagram. How do I actually turn it into

> The full `vending.sv` ships at
> [`labs/lab-05-elevator/examples/vending.sv`](https://github.com/uoftasic/dd103/blob/main/labs/lab-05-elevator/examples/vending.sv)
> so every command on this page is copy-pasteable.

SystemVerilog?*

Somebody hands you a drawing: circles with names in them, arrows between the circles, a
condition written on each arrow. Everyone calls this "the state machine" and nods.

Then you open an empty `.sv` file and nothing happens, because a drawing is not a syntax.

Here is the whole trick. **A finite state machine is a lookup table plus one register.** The
table says *given where I am and what I see, where do I go and what do I output*. The register
remembers the answer until the next clock edge. Every FSM you will ever write is those two
things, and SystemVerilog gives you exactly one construct for each: an `always_comb` for the
table, an `always_ff` for the register.

The rest of this page is a recipe. Follow it literally.

## The machine we are building

A vending machine. One item, **20 cents**. It takes nickels and dimes, one coin per clock
cycle. If you overpay it gives you a nickel back.

That is enough to need memory: the machine has to remember how much you have put in so far,
and "how much so far" is the state.

## Step 0 — write the table before you write any code

Not the drawing. The **table**. One row per (state, input) pair you care about:

| State | means | `dime` | `nickel` | neither | `dispense` | `refund` |
|---|---|---|---|---|---|---|
| `IDLE` | 0¢ in | → `GOT10` | → `GOT5` | stay | 0 | 0 |
| `GOT5` | 5¢ in | → `GOT15` | → `GOT10` | stay | 0 | 0 |
| `GOT10` | 10¢ in | → `VEND` | → `GOT15` | stay | 0 | 0 |
| `GOT15` | 15¢ in | → `VEND_CHANGE` | → `VEND` | stay | 0 | 0 |
| `VEND` | paid 20¢ | → `IDLE` | → `IDLE` | → `IDLE` | **1** | 0 |
| `VEND_CHANGE` | paid 25¢ | → `IDLE` | → `IDLE` | → `IDLE` | **1** | **1** |

Two things to notice, because they are decisions and not facts.

**`dime` beats `nickel`.** Physically you cannot insert both coins in one cycle, but the
hardware has no idea that is true. Every input combination reaches some arm of your code
whether you thought about it or not, so pick a winner on purpose.

**The last two columns depend only on the state, never on the input.** That makes this a
**Moore** machine, and it is why `dispense` needs its own state (`VEND`) instead of being
asserted from `GOT15`. Moore outputs are the ones you want: they change once per clock edge
and they cannot glitch. The alternative — outputs that also depend on the inputs, called
**Mealy** — is legal, sometimes saves a state, and is a much better fight to pick in second
year.

Six states. That is 3 bits, which encodes 8 things, so **two encodings are not states at
all**. Remember that; step 4 is about those two.

## Step 1 — the states, as a `typedef enum`, module-local

```systemverilog
typedef enum logic [2:0] {
    IDLE        = 3'd0,
    GOT5        = 3'd1,
    GOT10       = 3'd2,
    GOT15       = 3'd3,
    VEND        = 3'd4,
    VEND_CHANGE = 3'd5
} state_t;

state_t state, next;
```

The `logic [2:0]` is the part that matters: it says these names are **three real wires**, and
after synthesis they will be three real flip-flops holding one of six patterns. `state_t` is a
type, not a variable, and it lives inside the module — a `typedef` at file scope leaks into
every other module the compiler reads and starts a fight later.

Declare **two** signals of that type. `state` is what the register currently holds. `next` is
what you want it to hold after the next edge. Keeping them separate is what makes the two
`always` blocks independent of each other, and it is the single habit that prevents most
beginner FSM bugs.

## Step 2 — one `always_comb`, and it assigns a default to everything on entry

```systemverilog
always_comb begin
    next     = state;      // default: stay put
    dispense = 1'b0;       // default: every output, every time
    refund   = 1'b0;

    case (state)
        IDLE: begin
            if      (dime)   next = GOT10;
            else if (nickel) next = GOT5;
        end
        GOT5: begin
            if      (dime)   next = GOT15;
            else if (nickel) next = GOT10;
        end
        GOT10: begin
            if      (dime)   next = VEND;
            else if (nickel) next = GOT15;
        end
        GOT15: begin
            if      (dime)   next = VEND_CHANGE;
            else if (nickel) next = VEND;
        end
        VEND: begin
            dispense = 1'b1;
            next     = IDLE;
        end
        VEND_CHANGE: begin
            dispense = 1'b1;
            refund   = 1'b1;
            next     = IDLE;
        end
        default: next = IDLE;   // 3'd6 and 3'd7 are not states
    endcase
end
```

Read the first three lines again. **Every signal this block drives gets a value before the
`case` runs.** `next = state` means "stay where you are unless something below says
otherwise", which is why the `IDLE` arm has no `else` — it does not need one.

That is not style advice. It is the difference between combinational logic and a latch, and
[The latch you didn't ask for](guide/the-latch-you-didnt-ask-for.md) covers what happens when
you skip it. There is a demonstration at the bottom of this page.

Compare the `case` arms against the table above, line by line. The arms are the rows. If you
cannot point at the row a line of code came from, you transcribed something wrong.

## Step 3 — one `always_ff`, non-blocking only

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next;
end
```

Three lines. That is the entire register, and it is the same three lines in every FSM you will
ever write — only the reset state changes.

- `negedge rst_n` in the sensitivity list makes the reset **asynchronous**: the machine snaps
  to `IDLE` the moment `rst_n` drops, without waiting for a clock edge. This is the shape
  LibreLane's default flow expects, and it is what the SKY130 cell
  `sky130_fd_sc_hd__dfrtp_1` — *d flip-flop, reset, true output, positive edge* — physically
  does.
- `<=`, never `=`. [Blocking vs non-blocking](guide/blocking-vs-nonblocking.md) settles that
  argument by counting flip-flops.
- Nothing else goes in here. No output logic, no `if (dime)`. If you are tempted to add a
  line, it belongs in step 2.

## Step 4 — the `default:` arm, and why it is not paranoia

You have six states in a 3-bit register. `3'd6` and `3'd7` exist in the hardware and are not
in your `typedef`. On power-up before reset, or after a cosmic-ray bit flip that a real chip
in a real satellite really does experience, the register can hold one of them.

Without a `default:` arm, your `case` has nothing to say about those two patterns, so the
synthesizer is free to do whatever is cheapest — including leaving the machine stuck there
forever. `default: next = IDLE;` costs almost nothing and guarantees the machine walks itself
back to a state you named.

> You may see `unique case` recommended online as a way to say "I have covered everything".
> Do not use it in this course. It tells the tool to *assume* full coverage instead of
> *checking* it, which switches off the one safety net Yosys gives you for free.

## Does it work? Ask Icarus before you ask Yosys

Simulate first. Synthesis is slow to tell you your logic is wrong; a testbench is fast.

You write `tb_vending.sv` yourself and it does nothing clever: hold `rst_n` low for two cycles,
pulse `nickel` or `dime` for one cycle at a time, and `$display` whenever `dispense` goes high.

```bash
iverilog -g2012 -o tb.vvp tb_vending.sv vending.sv
vvp tb.vvp
```

```
case 1: two dimes
  t=26000  inserted 10
  t=36000  inserted 10
  t=45000  DISPENSE  refund=0
case 2: four nickels
  t=66000  inserted 5
  t=76000  inserted 5
  t=86000  inserted 5
  t=96000  inserted 5
  t=105000  DISPENSE  refund=0
case 3: nickel then two dimes
  t=126000  inserted 5
  t=136000  inserted 10
  t=146000  inserted 10
  t=155000  DISPENSE  refund=1
```

20¢ dispenses. 25¢ dispenses and hands a nickel back. The table transcribed correctly.

## Now synthesize it, and find the state register

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
yosys -p "read_verilog -sv vending.sv; synth -top vending;
          dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB"
```

```
=== vending ===

       17  231.472 cells
        1    7.507   sky130_fd_sc_hd__a21o_1
        2   20.019   sky130_fd_sc_hd__a221o_1
        2   17.517   sky130_fd_sc_hd__a22o_1
        3   18.768   sky130_fd_sc_hd__and2_0
        5   125.12   sky130_fd_sc_hd__dfrtp_1
        1   26.275   sky130_fd_sc_hd__dfstp_2
        1    6.256   sky130_fd_sc_hd__lpflow_inputiso1p_1
        1    6.256   sky130_fd_sc_hd__lpflow_isobufsrc_1
        1    3.754   sky130_fd_sc_hd__nor2_1

   Chip area for module '\vending': 231.472000
     of which used for sequential elements: 151.395200 (65.41%)
```

**Seventeen cells, 231.47 µm².** The flip-flops are the two `df*` lines: five `dfrtp_1` plus
one `dfstp_2`, so **six flip-flops** — and they are **65.41% of the area**. Two-thirds of this
chip is remembering where it is, not deciding where to go.

Look closely at those two names. `dfrtp` is *d flip-flop, **r**eset, true output, positive
edge*; `dfstp` is the same cell with a **s**et instead. Five of your state bits have to come
out of reset holding 0 and one has to come out holding 1 — and that one is `IDLE`, exactly as
step 3 asked for. Your reset line is visible in the cell list.

Six flip-flops. You declared a **three**-bit state register. Something re-encoded your machine
behind your back.

## Yosys found your FSM and rewrote it

Scroll back up the log to section 2.7:

```
2.7.1. Executing FSM_DETECT pass (finding FSMs in design).
Found FSM state register vending.state.

2.7.2. Executing FSM_EXTRACT pass (extracting FSM from design).
Extracting FSM `\state' from module `\vending'.
  found $adff cell for state register: $procdff$111
  root of input selection tree: \next
  found reset state: 3'000 (from async reset)
  ...
  ctrl inputs: { \dime \nickel }
  ctrl outputs: { $procmux$106_CMP $procmux$102_CMP ... \next }
  transition:      3'000 2'00 ->      3'000 9'001000000
  transition:      3'000 2'01 ->      3'001 9'001000001
  transition:      3'000 2'1- ->      3'010 9'001000010
  transition:      3'100 2'-- ->      3'000 9'100000000
  ...
```

That transition list **is your table**, read back to you. Read the first three columns and
ignore the fourth — `state_in`, `ctrl_in`, `state_out`, then the output bits Yosys packed
into one vector. `ctrl inputs: { \dime \nickel }` says the two input bits are `dime` first,
so `3'000 2'01 -> 3'001` is the row "`IDLE`, no dime, a nickel → `GOT5`". Yosys recovered
the whole thing from your `case` statement, which is the strongest evidence you will get that
the recipe produced what you meant. If a row you expect is missing, your code and your table
disagree.

> Fourteen transitions come out, not eighteen. `VEND` and `VEND_CHANGE` each contribute one
> `2'--` row, because their arm of the `case` ignores the coins entirely.

Then it changed the encoding:

```
2.7.6. Executing FSM_RECODE pass (re-assigning FSM state encoding).
Recoding FSM `$fsm$\state$114' from module `\vending' using `auto' encoding:
  mapping auto encoding to `one-hot` for this FSM.
  000 -> -----1
  100 -> ----1-
  010 -> ---1--
  001 -> --1---
  101 -> -1----
  011 -> 1-----
```

## Binary vs one-hot, with the actual numbers

You met this pass in [Reading `stat` like a receipt](guide/reading-stat.md), where it turned a
2-bit state register into four flip-flops. Six states makes the trade easier to price.

**Binary encoding** is what you wrote: 6 states packed into $\lceil \log_2 6 \rceil = 3$ bits.
Three flip-flops, but every arm of the `case` needs a 3-input comparator to ask "am I in state
4?". **One-hot encoding** gives each state its own flip-flop, exactly one of which is high —
six states, six flip-flops, and "am I in state 4?" becomes *a single wire*.

More memory, less logic. That is the entire trade, and here it is measured — same source file,
three runs:

| Run | flip-flops | total cells | area | sequential share |
|---|---|---|---|---|
| `synth` (default — `auto` chose one-hot) | 6 | 17 | **231.47 µm²** | 65.41% |
| `fsm -encoding binary` | 3 | 23 | **185.18 µm²** | 40.54% |
| `synth -nofsm` (register left alone) | 3 | 13 | **137.63 µm²** | 54.55% |

Row 3 is one word added to the command you already ran. Row 2 needs the coarse passes spelled
out, because `synth` has no encoding flag of its own — `fsm` runs inside it:

```bash
yosys -p "read_verilog -sv vending.sv; hierarchy -top vending; proc;
          opt_expr; opt_clean; opt -nodffe -nosdff;
          fsm -encoding binary;
          opt; wreduce; peepopt; opt_clean; alumacc; share; opt;
          memory -nomap; opt_clean; techmap; opt -fast;
          dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB"
```

> That `opt -nodffe -nosdff` is load-bearing, and it is the one place this experiment will
> bite you. A plain `opt` folds the enable into the register and leaves you an `$adffe` cell —
> which `fsm_detect` does not recognise as a state register, so the `fsm` pass silently finds
> nothing and your `-encoding` flag does nothing at all. If your log has no
> `Found FSM state register` line, that is what happened.

Read the middle two columns. One-hot: 6 flops and **11** logic cells. Binary: 3 flops and
**20** logic cells. The trade is exactly what the theory promised — nine fewer gates of
decode, three more registers.

And on SKY130 the trade **loses**, because a `dfrtp_1` flip-flop costs 25.02 µm² and a
two-input gate costs between 3.75 and 6.26. One-hot is the standard **FPGA** answer, where a
flip-flop sits unused next to every LUT and is therefore free. It is not automatically the
ASIC answer.

> Do not go and pin `-encoding binary` into your scripts because of this table. Six states is
> tiny, and the third row shows that the interesting comparison is not even binary-vs-one-hot
> — it is whether the `fsm` pass should touch a machine this small at all. Let the default run.
> The point of this experiment is that **you can now check**, on your own design, instead of
> repeating what a forum told you.

## The trap: delete the defaults, watch it stop being combinational

Take out the three default assignments at the top of the `always_comb` and the `default:` arm,
and run `synth` again. Expect to hit this at least once:

```
2.2.8. Executing PROC_DLATCH pass (convert process syncs to latches).
ERROR: Latch inferred for signal `\vending.\dispense' from always_comb process `\vending.$proc$vending.sv:24$1'.
```

Line 24 is where the `always_comb` starts. The tool is telling you that on some path through
your `case`, `dispense` never gets assigned — so it has to *remember* its old value, so it
cannot be a gate, so it must be a latch, and you wrote `always_comb`, so it refuses.

Verilator names all of it before you ever start Yosys:

```
$ verilator --lint-only -Wall vending.sv
%Warning-CASEINCOMPLETE: vending.sv:29:9: Case values incompletely covered (example pattern 0x6)
%Warning-LATCH: vending.sv:24:5: Latch inferred for signal 'vending.next' (not all control paths of combinational always assign a value)
                               : ... Suggest use of always_latch for intentional latches
%Warning-LATCH: vending.sv:24:5: Latch inferred for signal 'dispense' (not all control paths of combinational always assign a value)
```

`example pattern 0x6` is `3'd6` — the exact unused encoding step 4 was about. Lint first,
every time; it is the fastest tool in the container and it is the only one that quotes your
own source back at you.

## The recipe, on one card

| Step | What | Rule |
|---|---|---|
| 0 | The table | Write it before the code. One row per (state, input). |
| 1 | `typedef enum logic [N:0]` | Module-local. Declare `state` **and** `next`. |
| 2 | **One** `always_comb` | Default every output and `next` on entry, then `case (state)`. |
| 3 | **One** `always_ff` | `@(posedge clk or negedge rst_n)`, `<=` only, nothing else in it. |
| 4 | `default:` arm | Unused encodings exist. Send them home. |

Four blocks of code, no cleverness, and it works for six states or sixty.

Next: [From gates to geometry](guide/from-gates-to-geometry.md). You now have a design worth
231 µm² and a `stat` receipt to prove it — the next page runs it through all the stages that
turn that receipt into an actual rectangle of silicon, and shows you how to tell a chip that
passed from a chip that merely exited zero.

Then [Lab 05 — Elevator to GDSII](labs/lab-05-elevator.md) hands you this recipe and a
four-floor elevator, and does not hand you a blank file.
