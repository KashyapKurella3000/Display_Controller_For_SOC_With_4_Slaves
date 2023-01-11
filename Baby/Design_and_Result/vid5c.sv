typedef enum [1:0] {
	MD24,MD32,MD16,MDText
} VMODE;


typedef struct packed {
	reg [5:0] Pclk;
	reg Enable;
	reg CursorEnable;
	VMODE Mode;
} CR0;

typedef struct packed {
	reg [12:0] Curx;
	reg [12:0] Cury;
} CUR0;

typedef struct packed {
	reg [5:0] BlinkRate;
	reg [4:0] CurXsize;
	reg [4:0] CurYsize;
} CUR1;

typedef struct packed {
    reg [7:0] Red;
    reg [7:0] Green;
    reg [7:0] Blue;
} CURFG;

typedef struct packed {
    reg [7:0] Red;
    reg [7:0] Green;
    reg [7:0] Blue;
} CURBG;

typedef struct packed {
	reg [12:0] Hsize;
	reg [12:0] Hend;
} H1;

typedef struct packed {
	reg [12:0] HsyncStart;
	reg [12:0] HsyncEnd;
} H2;

typedef struct packed {
	reg [12:0] Vsize;
	reg [12:0] Vend;
} V1;

typedef struct packed {
	reg [12:0] VsyncStart;
	reg [12:0] VsyncEnd;
} V2;

module vid5c (input clk, input reset, input selin, input reg [2:0] cmdin, input reg [1:0] lenin, 
            input reg [63:0] addrdatain, output reg [1:0] reqout, output reg [1:0] lenout, 
            output reg [63:0]addrdataout, output reg [2:0] cmdout, output reg [3:0] reqtar, 
            input ackin, output enable, output reg hsync, output reg hblank, output reg vsync, output reg vblank, 
            output reg [7:0] R, output reg [7:0] G, output reg [7:0] B);

    enum {noreq, dp, rreq, rres, wreq, wres, re, we} cmd_st;
    enum {rw, pixel} states;

    reg write, state,cursor_pos_r;
    reg [31:0] addr_w;
    reg [32'h60:0][31:0] c_mem;
    reg [6300:0][23:0] mem;
    reg [63:0][31:0] mem_cur;

    reg [16:0] h_count, v_count, p_count, c_count;
    reg req_busy;
    reg [2:0] en_count;

    wire[32:0] mem1;
    wire[32:0] base_addr,lineinc,cursor, cursor_pos;
    wire cursor_flag;

    wire test;

    CR0 CR0_1;
    CUR0 CUR0_1;
    CUR1 CUR1_1;
    CURFG CURFG_1;
    CURBG CURBG_1;
    H1 H1_1;
    H2 H2_1;
    V1 V1_1;
    V2 V2_1;

    assign test = CR0_1.CursorEnable;


    assign base_addr = c_mem[32'h48][31:0];
    assign lineinc = c_mem[32'h50][31:0];

    assign CR0_1.Enable = c_mem[0][3];
    assign CR0_1.Pclk = c_mem[0][9:4];
    assign CR0_1.CursorEnable = c_mem[0][2];

    assign cursor = c_mem[32'h0060][31:0];
    assign cursor_flag = ((h_count >= CUR0_1.Curx) & (h_count <= CUR0_1.Curx + CUR1_1.CurXsize)) 
                            && ((v_count >= CUR0_1.Cury) & (v_count <= CUR0_1.Cury + CUR1_1.CurYsize)) && (CR0_1.CursorEnable);

    assign cursor_pos = 31-(h_count-CUR0_1.Curx)*2*h_count;

    //Curx = 5, Cury = 5
    assign CUR0_1 = c_mem[32'h8];

    assign CUR1_1 = c_mem[32'h10];
    assign CURFG_1 = c_mem[32'h18];
    assign CURBG_1 = c_mem[32'h20];

    assign H1_1.Hsize = c_mem[32'h0028][25:13];
    assign H1_1.Hend = c_mem[32'h0028][12:0];

    assign V1_1.Vsize = c_mem[32'h0038][25:13];
    assign V1_1.Vend = c_mem[32'h0038][12:0];
    
    assign H2_1.HsyncStart = c_mem[32'h0030][25:13];
    assign H2_1.HsyncEnd = c_mem[32'h0030][12:0];

    assign V2_1.VsyncStart = c_mem[32'h0040][25:13];
    assign V2_1.VsyncEnd = c_mem[32'h0040][12:0];

    assign enable = c_mem[0][3];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reqout <= 0;
            lenout <=0;
            addrdataout <=0;
            cmdout <=0;
            reqtar <=0;
            hsync <=0;
            hblank <=0;
            vsync <=0;
            vblank <=1;
            R =0;
            G =0;
            B =0;

            req_busy <= 0;
            state <= rw;
            write <= 0;
            h_count <= 0;
            v_count <= 0;
            p_count <= 0;
            c_count <= 0;
            mem <= 0;
            c_mem <= 0;
            en_count <= 0;

        end

       else begin
        if(CR0_1.Enable && en_count < 3) en_count <= en_count + 1;

            case(state) 
                rw: begin
                    if  (ackin == 1) begin
                        addrdataout <= 0;
                        cmdout <= 0;
                        reqout <= 0; 
                    end

                    if (selin) begin

                        case(cmdin) 

                            noreq: reqout <= 0;
                            dp: begin
                                    if (write) begin
                                        cmdout <= wres;
                                        c_mem[addr_w] <= addrdatain;
                                        reqout <= 1;
                                        reqtar <= 0;
                                    end 
                            end
                            
                            rres: begin
                                req_busy <= 0;
                                    if((c_count < 64)) begin
                                        mem_cur[c_count] <= addrdatain;
                                        c_count <= c_count + 1;
                                    end
                                    else begin
                                        mem[h_count + (v_count * H1_1.Hend)] <= addrdatain;
                                        h_count <= h_count + 1;
                                    end
                            end
                            wreq: begin
                                    addr_w <= {24'd0, addrdatain[7:0]};
                                    write <= 1;
                                    reqtar <= 0;
                                
                            end

                            default: addrdataout <= 0;

                        endcase

                    end 

                    
                    else if ((en_count >= 3) && !req_busy) begin
                        
                        
                        if(c_count < 64) begin
                            cmdout <= rreq;
                            addrdataout <= cursor + c_count * 4;
                            lenout <= 0;
                            reqout <= 1;
                            write <= 0;
                            req_busy <= 1;
                        end
                        else begin 
                            if (h_count <= H1_1.Hsize)  begin
                                cmdout <= rreq;
                                addrdataout <= (h_count * 4) + base_addr + (v_count * lineinc) ;
                                lenout <= 0;
                                reqout <= 1;
                                write <= 0;
                                req_busy <= 1;
                            end   
                            else begin
                                h_count <= 0;
                                if(v_count == V1_1.Vsize) begin
                                    cmdout <= noreq;
                                    reqout <= 0;
                                    addrdataout <= 0;
                                    v_count <= 0;
                                    c_count <= 0;
                                    state <= pixel;
                                    req_busy <= 0;
                                end  
                                else v_count <= v_count + 1;
                            end
                        end 
                    end
                end

                pixel: begin
                        
                            

                    //REMEMBER TO ADD P_COUNT TO CONTROL # OF CLKS THE 
                    //PIXELS STAY STATIC FOR
                    if (h_count <= H1_1.Hend) begin
                        if (h_count <= H1_1.Hsize) begin
                            hblank <= 0;
                            if (CR0_1.Pclk > p_count ) begin
                                if(!cursor_flag) begin
                                    R = mem[h_count + (v_count * H1_1.Hend)][23:16];
                                    G = mem[h_count + (v_count * H1_1.Hend)][17:8];
                                    B = mem[h_count + (v_count * H1_1.Hend)][7:0];
                                end

                                else begin
                                    cursor_pos_r <= cursor_pos + 1;
                                    case(mem_cur[c_count][2*(h_count-CUR0_1.Curx)+:2])
                                        //FG
                                        2'b00: begin
                                            R = mem[h_count + (v_count * H1_1.Hend)][23:16];
                                            G = mem[h_count + (v_count * H1_1.Hend)][17:8];
                                            B = mem[h_count + (v_count * H1_1.Hend)][7:0];
                                        end
                                        //Inv
                                        2'b01: begin
                                            R = ~mem[h_count + (v_count * H1_1.Hend)][23:16];
                                            G = ~mem[h_count + (v_count * H1_1.Hend)][17:8];
                                            B = ~mem[h_count + (v_count * H1_1.Hend)][7:0]; 
                                        end
                                        //FG
                                        2'b10: begin
                                            R = CURFG_1.Red;
                                            G = CURFG_1.Green;
                                            B = CURFG_1.Blue;
                                        end
                                        //BG
                                        2'b11: begin
                                            R = CURBG_1.Red;
                                            G = CURBG_1.Green;
                                            B = CURBG_1.Blue;
                                        end
                                    endcase
                                    
                                end

                                p_count <= p_count + 1;
                            end else begin
                                if(cursor_flag && h_count == CUR0_1.Curx + CUR1_1.CurXsize) c_count <= c_count + 2;
                                h_count <= h_count + 1;
                                p_count <= 0;
                            end

                        end 
                        else if (CR0_1.Pclk > p_count) begin
                            hblank <= 1;
                            R = 0;
                            G = 0;
                            B = 0;
                            p_count <= p_count + 1;   
                            if(h_count > H2_1.HsyncStart && h_count <= H2_1.HsyncEnd )
                                hsync <= 1;
                            else hsync <= 0;                                      
                        end 
                        else begin
                            p_count <= 0;
                            if (h_count == H1_1.Hend) 
                                h_count <= 0;
                            
                            else begin
                                h_count <= h_count + 1;
                                if (h_count == H2_1.HsyncStart) begin
                                    if(v_count == V1_1.Vend) begin
                                        v_count <= 0;
                                        c_count <= 0;
                                    end
                                    else
                                        v_count <= v_count + 1;
                                end 
                            end

                        end


                        if (v_count <= V1_1.Vend) begin
                            if (v_count <= V1_1.Vsize) begin
                                vblank <= 0;    
                            end  

                            else begin 
                                R = 0;
                                G = 0;
                                B = 0; 
                                
                                vblank <= 1;
                            end

                            if(v_count > V2_1.VsyncStart && v_count <= V2_1.VsyncEnd )
                                vsync <= 1;
                            else vsync <= 0;


                        end
                        else v_count <= 0;

                    end
                end
                default: state <= rw;
            endcase 
         end
    end

endmodule