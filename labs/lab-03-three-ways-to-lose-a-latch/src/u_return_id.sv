module u_return_id (input logic [3:0] x, output logic [3:0] y);
    function automatic logic [3:0] passthru (input logic [3:0] a);
        logic [3:0] t;
        t = a;
        return t;
    endfunction
    assign y = passthru(x);
endmodule
