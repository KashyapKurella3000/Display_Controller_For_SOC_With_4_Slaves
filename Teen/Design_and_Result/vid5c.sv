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

//where h_count resets to 0 we still take in data
//fifo fills once before outputting
module fifo_rgb (input clk, input reset, input soft_reset, input r_e, input load_p, input [23:0] RGB_in, input o_e, output reg [23:0] RGB_out, output reg [8:0] loc_r, output reg [8:0] loc_p,output reg full, output reg[8:0] space_left) ;
    reg [511:0][23:0] mem ;
    reg[8:0] space_left;
    int i;
    wire [23:0] test0,test1,test2;
    assign test0 = mem[0];
    assign test1 = mem[1];
    assign test2 = loc_p - loc_r;



    always @(negedge clk or posedge reset or posedge soft_reset) begin
        if(reset || soft_reset) begin
            for(i = 0; i < 512; i = i + 1) begin
                mem[i] <= 0;
                loc_r <= 0;
                loc_p <= 0;
                space_left <= 0;
            end
            
            full <= 0;
        end 
        else begin
            space_left = loc_p - loc_r;
            if(load_p) begin
                    RGB_out = mem[loc_p];
                    loc_p = loc_p + 1;
            end
            //check if fifo is full, 17 to account for burst
            if(space_left > 16 || !o_e) begin
                full = 0;
                if(r_e) begin
                    mem[loc_r] = RGB_in;
                    loc_r = loc_r + 1;
                end
                
            end else full = 1;
        end
    end
endmodule

module vid5c (input clk, input reset, input selin, input reg [2:0] cmdin, input reg [1:0] lenin, 
            input reg [63:0] addrdatain, output reg [1:0] reqout, output reg [1:0] lenout, 
            output reg [63:0]addrdataout, output reg [2:0] cmdout, output reg [3:0] reqtar, 
            input ackin, output enable, output reg hsync, output reg hblank, output reg vsync, output reg vblank, 
            output reg [7:0] R, output reg [7:0] G, output reg [7:0] B);

    enum {noreq, dp, rreq, rres, wreq, wres, re, we} cmd_st;
    enum {rw, pixel} states;

    reg [2:0] cur_case;

    reg write, state;
    reg [31:0] addr_w;
    reg [32'h60:0][31:0] c_mem;
    reg [63:0][31:0] mem_cur;

    reg [12:0] h_count_p, v_count_p, h_count_r, v_count_r, p_count, c_count_p, c_count_r;
    reg req_busy;
    reg [5:0] en_count;
    reg soft_reset;

    wire[32:0] mem1;
    wire[32:0] base_addr,lineinc,cursor;
    wire [64:0] cursor_data;
    wire cursor_flag;

    wire [4:0] cxsize, cysize;
    wire [12:0] sub;

    wire [10:0] test;
    wire p_clk;

    reg [23:0] RGB_out, RGB_in;
    reg o_e,load_p, read_p;
    reg [8:0] loc_r, loc_p, space_left;

    reg full, read;
    reg [3:0] burst_count;


    CR0 CR0_1;
    CUR0 CUR0_1;
    CUR1 CUR1_1;
    CURFG CURFG_1;
    CURBG CURBG_1;
    H1 H1_1;
    H2 H2_1;
    V1 V1_1;
    V2 V2_1;

    fifo_rgb f1(clk, reset, soft_reset, read_p, load_p, RGB_in, o_e, RGB_out,loc_r, loc_p, full, space_left);

    assign sub = H1_1.Hsize - h_count_r;
    assign test = CR0_1.CursorEnable;

    assign base_addr = c_mem[32'h48][31:0];
    assign lineinc = c_mem[32'h50][31:0];

    assign CR0_1.Enable = c_mem[0][3];
    assign CR0_1.Pclk = c_mem[0][9:4];
    assign CR0_1.CursorEnable = c_mem[0][2];

    assign p_clk = CR0_1.Pclk;
    assign cxsize = CUR1_1.CurXsize;
    assign cysize = CUR1_1.CurYsize;
    assign cur_case = mem_cur[c_count_p][2*(h_count_p-CUR0_1.Curx)+:2];

    assign cursor = c_mem[32'h0060][31:0];
    assign cursor_flag = ((h_count_p >= CUR0_1.Curx) & (h_count_p <= CUR0_1.Curx + CUR1_1.CurXsize)) 
                            && ((v_count_p >= CUR0_1.Cury) & (v_count_p <= CUR0_1.Cury + CUR1_1.CurYsize)) && (CR0_1.CursorEnable);

    assign cursor_data = {mem_cur[c_count_p + 1], mem_cur[c_count_p]};

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
    
    always @(negedge enable) begin
        if(en_count == 25 && !enable) begin
            soft_reset <= 1;
            en_count <= 0;
        end
    end

    always @(posedge clk or posedge reset or posedge soft_reset) begin
        if (reset) begin

            //output signals
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

            //internal signals
            req_busy <= 0;
            state <= rw;
            write <= 0;
            read <= 0;
            o_e <= 0;            
            //keep track of where we are at
            h_count_p <= 0;
            v_count_p <= 0;
            h_count_r <= 0;
            v_count_r <= 0;
            p_count <= 0;
            c_count_p <= 0;
            c_count_r <= 0;
            c_mem <= 0;
            en_count <= 0;
            soft_reset <= 0;

            //fifo stuff
            RGB_in <= 0;
            load_p <= 0;
            read_p <= 0;
        end
        if(soft_reset) begin          
            req_busy <= 0;
            write <= 0;
            read <= 0;
            o_e <= 0;  
            //keep track of where we are at
            h_count_p <= 0;
            v_count_p <= 0;
            h_count_r <= 0;
            v_count_r <= 0;
            p_count <= 0;
            c_count_p <= 0;
            c_count_r <= 0;
            c_mem <= 0;
            en_count <= 0;
            soft_reset <= 0;

            //fifo stuff
            RGB_in <= 0;
            load_p <= 0;
            read_p <= 0;
        end


       

       else begin
        if(CR0_1.Enable && en_count < 25) en_count <= en_count + 1;
        if  (ackin == 1) begin
            addrdataout <= 0;
            cmdout <= 0;
            reqout <= 0; 
            lenout <= 0;
        end

        if (selin) begin

            case(cmdin) 
                //lenout might work now? 
                noreq: reqout <= 0;
                dp: begin
                        if (write) begin
                            cmdout <= wres;
                            c_mem[addr_w] <= addrdatain;
                            reqout <= 1;
                            reqtar <= 0;
                            req_busy <= 0;
                            addrdataout <= 0;
                        end 
                        if(read && lenin == 3) begin
                            RGB_in <= addrdatain;
                            h_count_r <= h_count_r + 1;
                            if(burst_count == 0) begin
                                read <= 0;
                            end
                            else burst_count <= burst_count - 1;
                        end
                end
                
                rres: begin
                    req_busy <= 0;
                        if((c_count_r < 64)) begin
                            mem_cur[c_count_r] <= addrdatain;
                            c_count_r <= c_count_r + 1;
                        end
                        //--------Originally used blocking, but might need to change something in FIFO module----------------------
                        else begin
                            read_p <= 1;
                            RGB_in <= addrdatain;
                            h_count_r <= h_count_r + 1;
                            read <= 1;
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
        if( en_count >= 25 && !req_busy && ((loc_r == (V1_1.Vend * H1_1.Hend / 2)) || (loc_r == 200)) && !o_e ) begin
                o_e <= 1;
                load_p <= 1;
        end                     
        if ((en_count >= 25) && !req_busy && !selin) begin
            
            //------------------------------------------DO BURST-------------------------------------//
            

            //read cursor data from mem
            if(c_count_r < 64) begin
                cmdout <= rreq;
                addrdataout <= cursor + c_count_r * 4;
                lenout <= 0;
                reqout <= 1;
                write <= 0;
                req_busy <= 1;
            end

            //read rgb data from mem
            else if(!full) begin 
                if ((sub >= 16) && (sub <= H1_1.Hsize) && (space_left > 34 || !o_e))  begin
                    read_p <= 0;
                    cmdout <= rreq;
                    addrdataout <= (h_count_r * 4) + base_addr + (v_count_r * lineinc) ;
                    lenout <= 3;
                    reqout <= 1;
                    write <= 0;
                    req_busy <= 1;
                    burst_count <= 15;
                end   
                else begin
                    read_p <= 0;
                    cmdout <= rreq;
                    if(h_count_r == H1_1.Hsize + 1) addrdataout <=base_addr + ((v_count_r + 1) * lineinc) ;
                    else addrdataout <= (h_count_r * 4) + base_addr + (v_count_r * lineinc) ;
                    lenout <= 0;
                    reqout <= 1;
                    write <= 0;
                    req_busy <= 1;
                end
                if(h_count_r > H1_1.Hsize) begin
                    h_count_r <= 0;
                    read_p <= 0;
                    if(v_count_r == V1_1.Vsize) begin
                        cmdout <= noreq;
                        reqout <= 0;
                        addrdataout <= 0;
                        v_count_r <= 0;
                        c_count_r <= 0;
                        req_busy <= 0;
                    end  
                    if(v_count_r != V1_1.Vsize) v_count_r <= v_count_r + 1;
                end
            end 
        end

        
        if(o_e) begin
            //REMEMBER TO ADD P_COUNT TO CONTROL # OF CLKS THE 
            //PIXELS STAY STATIC FOR
            if (h_count_p <= H1_1.Hend) begin
                if (h_count_p <= H1_1.Hsize) begin
                    hblank <= 0;
                    if (CR0_1.Pclk > p_count ) begin
                        
                        if(!cursor_flag) begin
                            R = RGB_out[23:16];
                            G = RGB_out[17:8];
                            B = RGB_out[7:0];
                        end

                        else begin
                            //cursor_pos_r <= cursor_pos + 1;
                            case(cursor_data[2*(h_count_p-CUR0_1.Curx)+:2])
                                //reg
                                2'b00: begin
                                    R = RGB_out[23:16];
                                    G = RGB_out[17:8];
                                    B = RGB_out[7:0];
                                end
                                //Inv
                                2'b01: begin
                                    R = ~RGB_out[23:16];
                                    G = ~RGB_out[17:8];
                                    B = ~RGB_out[7:0]; 
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
                                default: begin
                                    R = RGB_out[23:16];
                                    G = RGB_out[17:8];
                                    B = RGB_out[7:0];
                                end
                            endcase
                        end

                        p_count <= p_count + 1;
                        load_p <= 0;
                    end else begin
                        if(cursor_flag && h_count_p == CUR0_1.Curx + CUR1_1.CurXsize) c_count_p <= c_count_p + 2;
                        
                        h_count_p <= h_count_p + 1;
                        p_count <= 0;
                        load_p <= 1;
                    end

                end 
                else if (CR0_1.Pclk > p_count) begin
                    hblank <= 1;
                    load_p <= 0;
                    R = 0;
                    G = 0;
                    B = 0;
                    p_count <= p_count + 1;   
                    if(h_count_p > H2_1.HsyncStart && h_count_p <= H2_1.HsyncEnd )
                        hsync <= 1;
                    else hsync <= 0;                                      
                end 
                else begin
                    p_count <= 0;
                    if (h_count_p == H1_1.Hend) 
                        h_count_p <= 0;
                        
                    else begin
                        h_count_p <= h_count_p + 1;
                        if (h_count_p == H2_1.HsyncStart) begin
                            if(v_count_p == V1_1.Vend) begin
                                v_count_p <= 0;
                                c_count_p <= 0;
                            end
                            else
                                v_count_p <= v_count_p + 1;
                        end 
                    end

                end


                if (v_count_p <= V1_1.Vend) begin
                    if (v_count_p <= V1_1.Vsize) begin
                        vblank <= 0;    
                    end  

                    else begin 
                        R = 0;
                        G = 0;
                        B = 0; 
                        
                        vblank <= 1;
                        load_p <= 0;
                    end

                    if(v_count_p > V2_1.VsyncStart && v_count_p <= V2_1.VsyncEnd )
                        vsync <= 1;
                    else vsync <= 0;


                end
                else v_count_p <= 0;

            end
        end
         end
    end

endmodule