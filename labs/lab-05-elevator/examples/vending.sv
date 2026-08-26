// The worked example from guide/state-machine-is-a-table.md.
//
// One item, 20 cents. Nickels and dimes, one coin per clock. Overpay by five and
// you get your nickel back. Shipped so the commands on that page are copy-pasteable:
//
//   iverilog -g2012 -o tb.vvp tb_vending.sv vending.sv && vvp tb.vvp
//   yosys -p "read_verilog -sv vending.sv; synth -top vending; \
//             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB"
//
// The elevator in ../src is the same four-step recipe, one size up.
module vending (
    input  logic clk,
    input  logic rst_n,
    input  logic nickel,
    input  logic dime,
    output logic dispense,
    output logic refund
);

    typedef enum logic [2:0] {
        IDLE        = 3'd0,
        GOT5        = 3'd1,
        GOT10       = 3'd2,
        GOT15       = 3'd3,
        VEND        = 3'd4,
        VEND_CHANGE = 3'd5
    } state_t;

    state_t state, next;

    // One always_comb: next state and every Moore output, each defaulted on entry.
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

    // One always_ff: the register, non-blocking only.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next;
    end

endmodule
