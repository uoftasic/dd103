# Writing a state machine

This page gives you a recipe for turning a state diagram into SystemVerilog, and works through it
on a vending machine. In
[Lab 05, Part 1](../labs/lab-05-elevator-overview.md#part-1-warm-up-on-the-vending-machine) you'll
synthesize the same vending machine and then break it on purpose. The full source ships as
[`labs/lab-05-elevator/examples/vending.sv`](https://github.com/uoftasic/dd103/blob/main/labs/lab-05-elevator/examples/vending.sv).

Usually somebody hands you a drawing: circles with names in them, arrows between the circles, and
a condition written on each arrow. Everyone calls it "the state machine". Then you open an empty
`.sv` file and get stuck, because there's no way to type a drawing into SystemVerilog.

It helps to think of a finite state machine as a lookup table plus one register. The table
answers the question "given where I am and what I see, where do I go next and what do I output?",
and the register remembers the answer until the next clock edge. Every FSM you write is made of
those two things, and SystemVerilog gives you one construct for each: an `always_comb` block for
the table and an `always_ff` block for the register.

The rest of this page is a recipe for writing those two blocks, and we suggest you follow it
literally.

## The example machine

A vending machine sells one item for 20 cents. It takes nickels and dimes, one coin per clock
cycle, and if you overpay it gives you a nickel back.

That needs memory, because the machine has to remember how much you've put in so far, and "how
much so far" is the state.

## Step 0: write the table before any code

Before you write any code, write the machine down as a table rather than a drawing, with one row
per state:

| State | means | `dime` | `nickel` | neither | `dispense` | `refund` |
|---|---|---|---|---|---|---|
| `IDLE` | 0¢ in | → `GOT10` | → `GOT5` | stay | 0 | 0 |
| `GOT5` | 5¢ in | → `GOT15` | → `GOT10` | stay | 0 | 0 |
| `GOT10` | 10¢ in | → `VEND` | → `GOT15` | stay | 0 | 0 |
| `GOT15` | 15¢ in | → `VEND_CHANGE` | → `VEND` | stay | 0 | 0 |
| `VEND` | paid 20¢ | → `IDLE` | → `IDLE` | → `IDLE` | 1 | 0 |
| `VEND_CHANGE` | paid 25¢ | → `IDLE` | → `IDLE` | → `IDLE` | 1 | 1 |

Two things in the table are decisions we made, rather than facts about vending machines.

The first is that `dime` beats `nickel` when both are high. Physically you can't insert both
coins in one cycle, but the hardware doesn't know that. Every input combination reaches some
branch of your code whether you thought about it or not, so it's better to pick the winner on
purpose.

The second is that the last two columns depend only on the state, never on the inputs. That makes
this a **Moore machine**, and it's why `dispense` needs a state of its own (`VEND`) instead of
being asserted from `GOT15`. Moore outputs change only once per clock edge, so they can't
glitch. The alternative, where the outputs also depend on the inputs, is called a **Mealy
machine**. Mealy machines are legal and sometimes save a state, but they're a
better topic for second year.

Six states need 3 bits, and 3 bits can encode 8 values, so two of the encodings don't correspond
to any state. Step 4 deals with those two.

## Step 1: the states, as a module-local `typedef enum`

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

`logic [2:0]` says that these names stand for patterns on three real wires, and after synthesis
those wires will come out of flip-flops holding one of the six patterns. `state_t` is a type
rather than a variable, and it belongs inside the module: a `typedef` at file scope leaks into
every other module the compiler reads, and sooner or later it conflicts with something.

Then declare two signals of that type. `state` is what the register holds now, and `next` is what
you want it to hold after the next clock edge. Keeping the two separate makes the two `always`
blocks independent of each other, and that one habit prevents most beginner FSM bugs.

## Step 2: one `always_comb` that defaults everything on entry

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

Every signal this block drives gets a value before the `case` runs. `next = state` means "stay
where you are unless something below says otherwise", which is why the `IDLE` branch doesn't need
an `else`.

Giving every signal a default is what keeps this block combinational logic rather than a latch.
[Inferred latches](../guide/the-latch-you-didnt-ask-for.md) covers what happens when you skip the
defaults, and the end of this page shows it happening on this machine.

Then compare the `case` branches against the table, line by line, because each branch is one row
of the table. If you can't point at the row a line of code came from, you've transcribed
something wrong.

## Step 3: one `always_ff`, non-blocking only

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next;
end
```

Those three lines are the entire register. They're the same in every FSM you write, and only the
reset state changes from one machine to the next.

- `negedge rst_n` in the sensitivity list makes the reset asynchronous, so the machine goes to
  `IDLE` the moment `rst_n` drops, without waiting for a clock edge. This is the shape LibreLane's
  default flow expects, and it's what the SKY130 cell `sky130_fd_sc_hd__dfrtp_1` (D flip-flop,
  reset, true output, positive edge) physically does.
- Use `<=`, never `=`. [Blocking and non-blocking assignments](../guide/blocking-vs-nonblocking.md)
  explains why by counting the flip-flops each version produces.
- Nothing else goes in this block: no output logic, and no `if (dime)`. If you find yourself
  wanting to add a line here, it belongs in step 2 instead.

## Step 4: the `default:` branch

You have six states in a 3-bit register, so `3'd6` and `3'd7` exist in the hardware even though
they aren't in your `typedef`. At power-up before reset, or after a cosmic-ray bit flip (which
real chips in real satellites do experience), the register can hold one of them.

Without a `default:` branch, your `case` says nothing about those two patterns, so the
synthesizer is free to do whatever is cheapest, and that includes leaving the machine stuck in one
of them forever. `default: next = IDLE;` costs almost nothing, and it guarantees that the machine
walks back to a state you named.

> You may see `unique case` recommended online as a way of saying "I have covered everything".
> Don't use it in this course. It tells the tool to assume full coverage instead of checking for
> it, and that switches off the safety net Yosys otherwise gives you for free.

## Simulation

A testbench tells you that your logic is wrong much faster than synthesis does. Here is the
output of a `tb_vending.sv` that holds `rst_n` low for two cycles, pulses `nickel` or `dime` for
one cycle at a time, and uses `$display` whenever `dispense` goes high:

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

Paying 20¢ dispenses the item, and paying 25¢ dispenses it and returns a nickel, so the table was
transcribed correctly. We don't ship this testbench; writing it yourself is an optional step in
Lab 05.

## The synthesized machine

This is the `stat` report for the vending machine, mapped to SKY130 with the usual `synth` /
`dfflibmap` / `abc` / `stat -liberty` flow:

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

That's seventeen cells and 231.47 µm². The flip-flops are the two `df*` lines, five `dfrtp_1`
plus one `dfstp_2`, which makes six flip-flops, and together they take 65.41 % of the area, so
two thirds of this chip is spent remembering where it is.

`dfrtp` stands for D flip-flop, reset, true output, positive edge, and `dfstp` is the same cell
with a set instead of a reset. So five of the state bits come out of reset holding 0 and one comes
out holding 1, and that one is the bit for `IDLE`, as step 3 asked. You can read your reset state
straight off the cell list.

You declared a three-bit state register, though, and the netlist has six flip-flops because
Yosys re-encoded the machine.

## FSM extraction and recoding

Section 2.7 of the synthesis log shows how:

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

That transition list is your table, read back to you by Yosys. Each line gives `state_in`,
`ctrl_in` and `state_out`, followed by the output bits Yosys has packed into one vector; read the
first three fields and ignore the fourth. `ctrl inputs: { \dime \nickel }` says that the first
input bit is `dime`, so `3'000 2'01 -> 3'001` is the row "`IDLE`, no dime, a nickel → `GOT5`".
Yosys recovered the whole table from your `case` statement, which is strong evidence that the
recipe produced what you meant. If a row you expect is missing, your code and your table
disagree somewhere.

> You might expect eighteen transitions (six states times three input cases), but there are
> fourteen. `VEND` and `VEND_CHANGE` each contribute a single `2'--` row, because their branch of
> the `case` ignores the coins.

Then Yosys changed the encoding:

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

## Binary and one-hot encoding

You met this pass in [Reading the `stat` report](../guide/reading-stat.md), where it turned a 2-bit
state register into four flip-flops. With six states it's easier to see what the trade costs.

Binary encoding is what you wrote: 6 states packed into $\lceil \log_2 6 \rceil = 3$ bits. That
needs only three flip-flops, but every branch of the `case` needs a 3-input comparison to ask "am
I in state 4?". One-hot encoding gives each state its own flip-flop, and exactly one of them is
high at a time, so six states take six flip-flops and "am I in state 4?" becomes a single wire.
One-hot uses more memory and less logic.

Here is that trade measured three ways on the same source file:

| Run | flip-flops | total cells | area | sequential share |
|---|---|---|---|---|
| `synth` (default: `auto` chose one-hot) | 6 | 17 | 231.47 µm² | 65.41% |
| `fsm -encoding binary` | 3 | 23 | 185.18 µm² | 40.54% |
| `synth -nofsm` (register left alone) | 3 | 13 | 137.63 µm² | 54.55% |

Row 3 adds one word to the usual command. Row 2 needs the coarse passes spelled out, because
`synth` has no encoding flag of its own and `fsm` runs inside it.

> When you spell the passes out, use `opt -nodffe -nosdff` before `fsm`, not plain `opt`. A plain
> `opt` folds the enable into the register and leaves an `$adffe` cell, which `fsm_detect` doesn't
> recognise as a state register. The `fsm` pass then finds no state machine, so your `-encoding`
> flag has no effect. If your log has no `Found FSM state register` line, that's what happened.

Now compare the flip-flop and cell counts in the first two rows. Subtracting the flip-flops from
the total, one-hot has 6 flops and 11 logic cells, and binary has 3 flops and 20 logic cells. That's the trade the theory predicts: one-hot
spends three more registers to save nine decode gates.

On SKY130 one-hot comes out behind, because a `dfrtp_1` costs 25.02 µm² and a two-input gate
costs between 3.75 and 6.26. One-hot is the standard answer on an FPGA, where a flip-flop sits
unused next to every LUT and is effectively free, but that doesn't make it automatically the
right answer for an ASIC.

> Don't pin `-encoding binary` into your scripts because of this table. Six states is tiny, and
> the third row shows that the more interesting question is whether the `fsm` pass should touch a
> machine this small at all. Let the default run. What matters is that you can now check this on
> your own design instead of repeating what a forum told you.

## Deleting the defaults

If you take out the three default assignments at the top of the `always_comb` and the `default:`
branch and run `synth` again, Yosys stops (you'll do this in Lab 05, Part 1, step 6):

```
2.2.8. Executing PROC_DLATCH pass (convert process syncs to latches).
ERROR: Latch inferred for signal `\vending.\dispense' from always_comb process `\vending.$proc$vending.sv:32$1'.
```

Line 32 is where the `always_comb` starts. On some path through your `case`, `dispense` is never
assigned, so on that path it has to keep its old value. A gate can't remember anything, so the
only hardware that fits is a latch, and because you wrote `always_comb`, Yosys refuses to build
one.

Verilator reports all of these problems, and you don't need to start Yosys to see them:

```
$ verilator --lint-only -Wall vending.sv
%Warning-CASEINCOMPLETE: vending.sv:34:9: Case values incompletely covered (example pattern 0x6)
%Warning-LATCH: vending.sv:32:5: Latch inferred for signal 'vending.next' (not all control paths of combinational always assign a value)
                               : ... Suggest use of always_latch for intentional latches
%Warning-LATCH: vending.sv:32:5: Latch inferred for signal 'dispense' (not all control paths of combinational always assign a value)
```

`example pattern 0x6` is `3'd6`, the unused encoding from step 4. Run the linter first, every
time: it's the fastest tool in the container, and the only one that quotes your own source back
at you.

## The recipe

| Step | What | Rule |
|---|---|---|
| 0 | The table | Write it before the code. One row per state, one column per input. |
| 1 | `typedef enum logic [N:0]` | Module-local. Declare `state` and `next`. |
| 2 | One `always_comb` | Default every output and `next` on entry, then `case (state)`. |
| 3 | One `always_ff` | `@(posedge clk or negedge rst_n)`, `<=` only, nothing else in it. |
| 4 | `default:` branch | The unused encodings exist in hardware, so send them back to a named state. |

The same four blocks work whether the machine has six states or sixty.

Next: [From netlist to layout](../guide/from-gates-to-geometry.md), which takes this 231 µm²
design through the stages that turn the cell list in a `stat` report into a rectangle of silicon.
