module sample_project_G(in, out);
  parameter n = 4;

  input [n - 1 : 0]in;
  output out;

  wire not0;
  wire and0, and1, and2;

  not not_0(not0, in[3]);

  and and_0(and0, in[0], in[2], not0);
  and and_1(and1, in[1], in[2], in[3]);
  and and_2(and2, in[0], in[1], in[2]);

  or or_0(out, and0, and1, and2);
endmodule

module sample_project_D(in, out);
  parameter n = 4;

  input [n - 1 : 0]in;
  output out;

  assign out = in[0] & in[2] & !in[3] |
               in[1] & in[2] & in[3] |
               in[0] & in[1] & in[2];
endmodule

module sample_project_B(in, out);
  parameter n = 4;

  input [n - 1 : 0]in;
  output out;
  reg out;

  always@(*)begin
    case(in)
      5, 7, 14, 15 : begin
        out = 1'b1;
      end
      default : begin
        out = 1'b0;
      end
    endcase
  end
endmodule
