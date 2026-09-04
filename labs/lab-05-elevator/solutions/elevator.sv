// -----------------------------------------------------------------------------
// elevator.sv  --  DD103 Lab 05 REFERENCE IMPLEMENTATION
//
// Five states, three state elements (state, pending, dwell), one call queue and
// one door-dwell timer. This is what the skeleton in ../src/ becomes once both
// TODO blocks are filled in.
//
// Do not read this until you have your own version simulating. Then read it and
// argue with it -- there is more than one correct elevator.
//
// Verified in hpretl/iic-osic-tools:2026.08 -- lint clean under
// -Wall, and mapped to SKY130 standard cells. The numbers are in the writeup.
// -----------------------------------------------------------------------------

module elevator #(
    parameter int DWELL_TICKS = 4      // how many ticks the doors stay open
) (
    input  logic       clk,
    input  logic       rst_n,          // asynchronous, active low
    input  logic [3:0] call,           // call[i] = someone wants floor i (0..3)

    output logic [1:0] floor,
    output logic       moving_up,
    output logic       moving_dn,
    output logic       door_open,
    output logic [6:0] seg
);

    // --- step 1: the states -------------------------------------------------
    typedef enum logic [2:0] {
        IDLE      = 3'd0,   // parked, doors shut, queue empty
        MOVING    = 3'd1,   // one floor per tick toward `target`
        DOOR_OPEN = 3'd2,   // arrived: doors open, this call is served
        DWELL     = 3'd3,   // doors held open, counting down
        DOOR_SHUT = 3'd4    // doors closing, go home
    } state_t;

    state_t state, next;

    logic [1:0] target, next_target;
    logic [3:0] pending;           // the call queue -- one bit per floor
    logic [3:0] dwell;             // the door-dwell timer

    // comb control lines for the register block (step 3 makes no decisions)
    logic serve;                   // clear pending[floor] this cycle
    logic dwell_load;
    logic dwell_dec;

    // --- who is next? lowest pending floor wins -----------------------------
    logic       any_pending;
    logic [1:0] first_pending;

    always_comb begin
        any_pending = |pending;
        casez (pending)                    // a priority encoder: lowest bit wins
            4'b???1: first_pending = 2'd0;
            4'b??10: first_pending = 2'd1;
            4'b?100: first_pending = 2'd2;
            4'b1000: first_pending = 2'd3;
            default: first_pending = 2'd0;
        endcase
    end

    // --- step 2: ONE always_comb, everything defaulted on entry -------------
    always_comb begin
        next        = state;
        next_target = target;
        moving_up   = 1'b0;
        moving_dn   = 1'b0;
        door_open   = 1'b0;
        serve       = 1'b0;
        dwell_load  = 1'b0;
        dwell_dec   = 1'b0;

        case (state)
            IDLE: begin
                if (any_pending) begin
                    next_target = first_pending;
                    if (first_pending == floor) next = DOOR_OPEN;
                    else                        next = MOVING;
                end
            end

            MOVING: begin
                if (floor == target) begin
                    next = DOOR_OPEN;
                end else begin
                    moving_up = (target > floor);
                    moving_dn = (target < floor);
                end
            end

            DOOR_OPEN: begin
                door_open  = 1'b1;
                serve      = 1'b1;       // this floor's call is now answered
                dwell_load = 1'b1;
                next       = DWELL;
            end

            DWELL: begin
                door_open = 1'b1;
                if (dwell == 4'd0) next = DOOR_SHUT;
                else               dwell_dec = 1'b1;
            end

            DOOR_SHUT: begin
                next = IDLE;
            end

            default: next = IDLE;        // 3'd5..3'd7 are not states
        endcase
    end

    // --- step 3: ONE always_ff, non-blocking only ---------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            target  <= 2'd0;
            floor   <= 2'd0;
            pending <= 4'd0;
            dwell   <= 4'd0;
        end else begin
            state  <= next;
            target <= next_target;

            if (moving_up) floor <= floor + 2'd1;
            if (moving_dn) floor <= floor - 2'd1;

            // One statement owns `pending`: new presses OR in, the served floor
            // masks out. A press in the same cycle as the clear still lands.
            pending <= (pending | call) & ~(serve ? (4'd1 << floor) : 4'd0);

            if      (dwell_load) dwell <= DWELL_TICKS[3:0];
            else if (dwell_dec)  dwell <= dwell - 4'd1;
        end
    end

    // --- 7-segment decoder: floor 0 shows "1" -------------------------------
    always_comb begin
        case (floor)
            2'd0:    seg = 7'b0000110;   // "1"
            2'd1:    seg = 7'b1011011;   // "2"
            2'd2:    seg = 7'b1001111;   // "3"
            2'd3:    seg = 7'b1100110;   // "4"
            default: seg = 7'b0000000;
        endcase
    end

endmodule
