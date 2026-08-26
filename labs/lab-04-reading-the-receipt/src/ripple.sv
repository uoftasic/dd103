// ripple.sv — the adder from DD102 with its width made a parameter.
//
// Used by the guide page "The carry has to walk". The only change from
// src/ripple4.sv is `parameter int N`; the generate loop is the same one.
// Set the width before elaboration and one file gives you every width:
//
//   yosys -q -p "read_verilog -sv src/ripple.sv src/fulladder.sv;
//                chparam -set N 8 ripple; synth -top ripple; flatten;
//                abc -liberty $LIB; opt_clean; write_verilog -noattr gates8.v"
//   NETLIST=gates8.v sta -exit scripts/timing.tcl
//
// `make` does not build this file.

module ripple #(
    parameter int N = 4
) (
    input  logic [N-1:0] a, b,
    input  logic         cin,
    output logic [N-1:0] sum,
    output logic         cout
);
    logic [N:0] c;
    assign c[0] = cin;
    genvar i;
    generate
        for (i = 0; i < N; i++) begin : slice
            fulladder fa (.a(a[i]), .b(b[i]), .cin(c[i]),
                          .sum(sum[i]), .cout(c[i+1]));
        end
    endgenerate
    assign cout = c[N];
endmodule
