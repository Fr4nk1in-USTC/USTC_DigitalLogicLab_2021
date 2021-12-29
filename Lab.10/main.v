`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/12/21 17:37:43
// Design Name: 
// Module Name: main
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module main(
    input clk_100mhz, btn,
    input [3:0] sw,
    output reg [1:0] hexplay_an,
    output reg [3:0] hexplay_data
    );
// Control LC-3 clock
reg run;
initial run <= 1'b1;
// MEMORY
reg [15:0] MAR, MDR_in;
wire [15:0] MDR_out;
wire [11:0] MAR12;
reg mem_we;
initial mem_we <= 1'b0;
assign MAR12 = MAR[11:0];
memory mem(.a(MAR12), 
           .d(MDR_in), 
           .spo(MDR_out), 
           .we(mem_we), 
           .clk(clk_100mhz));
// Finite State Machine
    // control unit
    reg [15:0] PC, IR;
    initial begin
        PC <= 16'h0000;
        IR <= 16'h0000;
    end
    // states
        reg [4:0] curr_state, next_state;
        // instruction code
        parameter ADD  = 5'b00001;
        parameter AND  = 5'b00101;
        parameter BR   = 5'b00000;
        parameter JMP  = 5'b01100;
        parameter JSR  = 5'b00100;
        parameter LD   = 5'b00010;
        parameter LDI  = 5'b01010;
        parameter LDR  = 5'b00110;
        parameter LEA  = 5'b01110;
        parameter NOT  = 5'b01001;
        parameter RTI  = 5'b01000;
        parameter ST   = 5'b00011;
        parameter STI  = 5'b01011;
        parameter STR  = 5'b00111;
        parameter TRAP = 5'b01111;
        parameter ERR  = 5'b01101;
        // instruction cycle phrases
        parameter off         = 5'h10;
        parameter fetch_0     = 5'h11;
        parameter fetch_1     = 5'h12;
        parameter decode      = 5'h13;
        parameter read_mem    = 5'h14;
        parameter write_mem   = 5'h15;
        parameter read_mem_i  = 5'h16;
        parameter write_mem_i = 5'h17;
        parameter jsr_1       = 5'h18;
        parameter rti_1       = 5'h19;
        
        initial curr_state <= fetch_0;
    // FSM Part 1
    always @(posedge clk_100mhz) begin
        case (curr_state)
            fetch_0:     next_state <= fetch_1;
            fetch_1:     next_state <= decode;
            decode:      next_state <= {1'b0, IR[15:12]};
            ADD:         next_state <= fetch_0;
            AND:         next_state <= fetch_0;
            BR:          next_state <= fetch_0;
            JMP:         next_state <= fetch_0;
            JSR:         next_state <= jsr_1;
            LD:          next_state <= read_mem;
            LDI:         next_state <= read_mem_i;
            LDR:         next_state <= read_mem;
            LEA:         next_state <= fetch_0;
            NOT:         next_state <= fetch_0;
            RTI:         next_state <= rti_1;
            ST:          next_state <= write_mem;
            STI:         next_state <= write_mem_i;
            STR:         next_state <= write_mem;
            TRAP:        next_state <= off;
            ERR:         next_state <= off;
            read_mem:    next_state <= fetch_0;
            write_mem:   next_state <= fetch_0;
            read_mem_i:  next_state <= read_mem;
            write_mem_i: next_state <= write_mem;
            jsr_1:       next_state <= fetch_0;
            rti_1:       next_state <= fetch_0;
            off:         next_state <= off;
            default:     next_state <= off;
        endcase
    end
    // FSM Part 2 (Processing Unit)
    reg  [15:0] R [7:0], result, temp;
    wire [2:0]  cc, dr, sr1, sr2, baseR;
    wire [15:0] imm5, PCoffset9, PCoffset11, offset6;
    assign cc         = (result == 16'h0000) ? 3'b010 : ((result[15] == 1'b0) ? 3'b001 : 3'b100); // setCC
    assign dr         = IR[11:9];
    assign sr1        = IR[8:6];
    assign sr2        = IR[2:0];
    assign baseR      = IR[8:6];
    assign imm5       = {{11{IR[4]}}, IR[4:0]};
    assign PCoffset9  = {{7{IR[8]}} , IR[8:0]};
    assign PCoffset11 = {{5{IR[10]}}, IR[10:0]};
    assign offset6    = {{10{IR[5]}}, IR[5:0]};
    initial begin
        R[0]   <= 16'h000A;
        R[1]   <= 16'h0000;
        R[2]   <= 16'h0000;
        R[3]   <= 16'h0000;
        R[4]   <= 16'h0000;
        R[5]   <= 16'h0000;
        R[6]   <= 16'h0000;
        R[7]   <= 16'h0000;
        result <= 16'h0000;
        temp   <= 16'h0000;
    end
    always @(posedge clk_100mhz) begin
        if (run) begin
            case (curr_state)
                fetch_0:        begin
                                    MAR <= PC;
                                    PC  <= PC + 16'h0001;
                                    curr_state <= fetch_1;
                                end
                fetch_1:        begin
                                    IR   <= MDR_out;
                                    temp <= PC;
                                    curr_state <= decode;
                                end
                decode:         curr_state <= {1'b0, IR[15:12]};
                ADD:            begin
                                    if (IR[5]) begin
                                        R[dr]  <= R[sr1] + imm5;
                                        result <= R[sr1] + imm5;
                                    end else begin
                                        R[dr]  <= R[sr1] + R[sr2];
                                        result <= R[sr1] + R[sr2];
                                    end
                                    curr_state <= fetch_0;
                                end
                AND:            begin
                                    if (IR[5]) begin
                                        R[dr]  <= R[sr1] & imm5;
                                        result <= R[sr1] & imm5;
                                    end else begin
                                        R[dr]  <= R[sr1] & R[sr2];
                                        result <= R[sr1] & R[sr2];
                                    end
                                    curr_state <= fetch_0;
                                end
                BR:             begin
                                    if (cc & IR[11:9]) PC <= PC + PCoffset9;
                                    curr_state <= fetch_0;
                                end
                JMP:            begin
                                    PC <= R[baseR];
                                    curr_state <= fetch_0;
                                end
                JSR:            begin 
                                    temp <= PC;
                                    if (IR[11]) PC <= PC + PCoffset11;
                                    else        PC <= R[baseR];
                                    curr_state <= jsr_1;
                                end
                LD:             begin
                                    MAR <= PC + PCoffset9;
                                    curr_state <= read_mem;
                                end
                LDI:            begin
                                    MAR <= PC + PCoffset9;
                                    curr_state <= read_mem_i;
                                end
                LDR:            begin
                                    MAR <= R[baseR] + offset6;
                                    curr_state <= read_mem;
                                end
                LEA:            begin
                                    R[dr] <= PC + PCoffset9;
                                    curr_state <= fetch_0;
                                end
                NOT:            begin
                                    R[dr]  <= ~R[sr1];
                                    result <= ~R[sr1];
                                    curr_state <= fetch_0;
                                end
                RTI:            begin
                                    MAR  <= R[6];
                                    R[6] <= R[6] + 16'h0002;
                                    curr_state <= rti_1;
                                end
                ST:             begin
                                    MAR    <= PC + PCoffset9;
                                    MDR_in <= R[dr];
                                    mem_we <= 1'b1;
                                    curr_state <= write_mem;
                                end
                STI:            begin
                                    MAR    <= PC + PCoffset9;
                                    mem_we <= 1'b0;
                                    curr_state <= write_mem_i;
                                end
                STR:            begin
                                    MAR    <= R[baseR] + offset6;
                                    MDR_in <= R[dr];
                                    mem_we <= 1'b1;
                                    curr_state <= write_mem;
                                end
                TRAP:           curr_state <= off;
                ERR:            curr_state <= off;
                read_mem:       begin
                                    R[dr]  <= MDR_out;
                                    result <= MDR_out;
                                    curr_state <= fetch_0;
                                end
                write_mem:      begin  
                                    mem_we <= 1'b0;
                                    curr_state <= fetch_0;
                                end
                read_mem_i:     begin
                                    MAR <= MDR_out; 
                                    curr_state <= read_mem;
                                end
                write_mem_i:    begin
                                    MAR    <= MDR_out;
                                    MDR_in <= R[dr];
                                    mem_we <= 1'b1;
                                    curr_state <= write_mem;
                                end
                jsr_1:          begin
                                    R[7] <= temp;
                                    curr_state <= fetch_0;
                                end
                rti_1:          begin
                                    PC  <= MDR_out;
                                    curr_state <= fetch_0;
                                end
                off:            begin
                                    mem_we <= 1'b0;
                                    curr_state <= off;
                                end
                default:        curr_state <= off;
            endcase 
        end
    end
    // FSM Part 3 (Hexplay)
    reg [18:0] pluse_cnt;
    reg [16:0] data;
    wire pluse_200hz;
    assign pluse_200hz = pluse_cnt == 1'b1;
    always @(posedge clk_100mhz) begin
        if (pluse_cnt >= 19'h7A120) pluse_cnt <= 19'h00000;
        else                        pluse_cnt <= pluse_cnt + 19'h0001;
    end
    always @(posedge clk_100mhz) begin
        if (pluse_200hz) hexplay_an <= hexplay_an + 2'b01;
    end
    always @(posedge clk_100mhz) begin
        case(sw)
            4'h0: data <= R[0];
            4'h1: data <= R[1];
            4'h2: data <= R[2];
            4'h3: data <= R[3];
            4'h4: data <= R[4];
            4'h5: data <= R[5];
            4'h6: data <= R[6];
            4'h7: data <= R[7];
            4'h8: data <= {7'h00, cc[2], 3'h0, cc[1], 3'h0, cc[0]};
            4'h9: data <= PC;
            4'hA: data <= IR;
            4'hB: data <= MAR;
            4'hC: data <= MDR_out;
            default: data <= 16'h0000;
        endcase
    end
    always @(posedge clk_100mhz) begin
        case(hexplay_an)
            2'b00:   hexplay_data <= data[3:0];
            2'b01:   hexplay_data <= data[7:4];
            2'b10:   hexplay_data <= data[11:8];
            2'b11:   hexplay_data <= data[15:12];
            default: hexplay_data <= 4'h0;
        endcase
    end
endmodule
