// -----------------------------------------------------------------------------
// elevator.sv  --  DD103 Lab 05 SKELETON
//
// A 4-floor elevator controller. Three states. It works, it lints clean, and it
// synthesizes -- but it is a bad elevator, on purpose:
//
//   * it forgets a call the instant you let go of the button   (no call queue)
//   * the doors open and shut in the same clock cycle          (no dwell timer)
//
// Your job is the two TODO blocks below. Everything else -- ports, the 7-segment
// decoder, the reset, the file layout -- is already done and should stay done.
//
// One clock tick = one "step" of the machine. In a real elevator clk would come
// from a divider so a step is ~0.5 s; here it is whatever your testbench says.
// -----------------------------------------------------------------------------

module elevator (
    input  logic       clk,
    input  logic       rst_n,      // asynchronous, active low
    input  logic [3:0] call,       // call[i] = someone wants floor i (0..3)

    output logic [1:0] floor,      // where the car is right now
    output logic       moving_up,
    output logic       moving_dn,
    output logic       door_open,
    output logic [6:0] seg         // 7-segment digit for floor+1, segments g..a
);

    // -------------------------------------------------------------------------
    // Step 1 of the recipe: the states, as a module-local typedef enum.
    //
    // TODO(2): the reference machine has FIVE states. You will need somewhere to
    // wait with the doors open. Add it here, and give it an encoding.
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE   = 3'd0,   // parked, doors shut, nothing to do
        MOVING = 3'd1,   // travelling one floor per tick toward `target`
        DOORS  = 3'd2    // at the target, doors open (for exactly one tick)
    } state_t;

    state_t state, next;

    logic [1:0] target;      // floor we are currently driving toward
    logic [1:0] next_target;

    // TODO(1): the call queue.
    //   logic [3:0] pending;
    // A held button works today. A tap does not. `pending` is the register that
    // remembers a tap until the car actually gets there.

    // TODO(3): the door-dwell timer.
    //   logic [3:0] dwell;
    // Counts ticks while the doors are open, so they stay open long enough for a
    // person to walk through.

    // -------------------------------------------------------------------------
    // Which floor do we serve next? Lowest pending floor wins.
    //
    // This reads `call` directly -- that is the bug in TODO(1). Once you have a
    // `pending` register, this priority encoder should read `pending` instead.
    // -------------------------------------------------------------------------
    logic       any_call;
    logic [1:0] first_call;

    always_comb begin
        any_call = |call;
        casez (call)                       // a priority encoder: lowest bit wins
            4'b???1: first_call = 2'd0;
            4'b??10: first_call = 2'd1;
            4'b?100: first_call = 2'd2;
            4'b1000: first_call = 2'd3;
            default: first_call = 2'd0;
        endcase
    end

    // -------------------------------------------------------------------------
    // Step 2 of the recipe: ONE always_comb. Every output and `next` gets a
    // default on entry, before the case runs. Do not delete these defaults.
    // -------------------------------------------------------------------------
    always_comb begin
        next        = state;
        next_target = target;
        moving_up   = 1'b0;
        moving_dn   = 1'b0;
        door_open   = 1'b0;

        case (state)
            IDLE: begin
                if (any_call) begin
                    next_target = first_call;
                    if (first_call == floor) next = DOORS;
                    else                     next = MOVING;
                end
            end

            MOVING: begin
                if (floor == target) begin
                    next = DOORS;
                end else begin
                    moving_up = (target > floor);
                    moving_dn = (target < floor);
                end
            end

            DOORS: begin
                door_open = 1'b1;
                // TODO(3): do not leave after one tick. Load the dwell counter
                // when you arrive, count it down here, and only go home when it
                // hits zero.
                next = IDLE;
            end

            default: next = IDLE;   // 3'd3..3'd7 are not states. Send them home.
        endcase
    end

    // -------------------------------------------------------------------------
    // Step 3 of the recipe: ONE always_ff. Non-blocking only. No decisions here.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state  <= IDLE;
            target <= 2'd0;
            floor  <= 2'd0;
            // TODO(1): pending <= 4'd0;
            // TODO(3): dwell   <= 4'd0;
        end else begin
            state  <= next;
            target <= next_target;

            if (moving_up) floor <= floor + 2'd1;
            if (moving_dn) floor <= floor - 2'd1;

            // TODO(1): pending <= (pending | call) & ~(serviced mask);
            //          Set a bit whenever its button is pressed -- every cycle,
            //          in every state. Clear the bit for `floor` when the doors
            //          finish. Both in this one statement, or the two effects
            //          will fight over the same register.

            // TODO(3): load and decrement the dwell counter.
        end
    end

    // -------------------------------------------------------------------------
    // 7-segment decoder. Floor 0 shows "1". Already done; leave it alone.
    // Segment order is {g,f,e,d,c,b,a} = seg[6:0], active high.
    // -------------------------------------------------------------------------
    always_comb begin
        case (floor)
            2'd0:    seg = 7'b0000110;   // "1"
            2'd1:    seg = 7'b1011011;   // "2"
            2'd2:    seg = 7'b1001111;   // "3"
            2'd3:    seg = 7'b1100110;   // "4"
            default: seg = 7'b0000000;   // blank
        endcase
    end

endmodule
