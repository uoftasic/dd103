// blinker.sv — DD103 Lab 04.
//
// A four-state controller with a 4-bit countdown timer. `go` starts it, it
// loads 9, counts down, emits one `pulse`, and returns to IDLE.
//
// Six bits are assigned with `<=` inside the always_ff below: 2 for `state`,
// 4 for `count`. Count them yourself and write the number down BEFORE you run
// `make predict`. The receipt will disagree with you, and the reason it
// disagrees is the whole first experiment.

module blinker (
    input  logic clk,
    input  logic rst_n,
    input  logic go,
    output logic busy,      // high whenever the machine is not IDLE
    output logic pulse,     // one cycle high in DONE_S
    output logic load_en    // high in LOAD, when the timer is written
);

    typedef enum logic [1:0] {IDLE, LOAD, RUN, DONE_S} state_t;

    state_t     state;      // 2 bits
    logic [3:0] count;      // 4 bits

    // ---- state and timer: one always_ff, non-blocking only ----------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
        end else begin
            case (state)
                IDLE:   if (go) state <= LOAD;
                LOAD:   begin count <= 4'd9; state <= RUN; end
                RUN:    if (count == 4'd0) state <= DONE_S;
                        else count <= count - 4'd1;
                DONE_S: state <= IDLE;
            endcase
        end
    end

    // ---- Moore outputs: a function of `state` and nothing else ------------
    always_comb begin
        busy    = 1'b0;
        pulse   = 1'b0;
        load_en = 1'b0;
        case (state)
            IDLE:   ;
            LOAD:   begin busy = 1'b1; load_en = 1'b1; end
            RUN:    busy = 1'b1;
            DONE_S: begin busy = 1'b1; pulse = 1'b1; end
        endcase
    end

endmodule
