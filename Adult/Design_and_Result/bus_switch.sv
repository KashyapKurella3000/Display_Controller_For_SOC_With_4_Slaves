// A place holder for the bus switch
// reqtar 0 is the tb memory, reqtar 3 is all graphics devices
// All responses are to reqtar F
// graphics devices D0 - D3 are decodes as:
//      0xF000_0000 D0
//      0xF000_0100 D1
//      0xF000_0200 D2
//      0xF000_0300 D3
function [2:0] decoder(input [31:0] code);
    casex (code)
        32'hF000_00xx: decoder = 0;
        32'hF000_01xx: decoder = 1;
        32'hF000_02xx: decoder = 2;
        32'hF000_03xx: decoder = 3;
        default: decoder = 5;
    endcase
endfunction

module bus_switch(BUSI.swporti mbi, BUSI.swporto mbo,BUSI.swporti tbi,BUSI.swporto tbo,BUSI.swporti d0i,BUSI.swporto d0o,
    BUSI.swporti d1i,BUSI.swporto d1o, BUSI.swporti d2i, BUSI.swporto d2o,
    BUSI.swporti d3i,BUSI.swporto d3o
    );

    typedef enum  [2:0] {IDLE, BUS_REQ, BUS_RESP} states;

    states state;

    // Signals from Device
    wire [31:0] addrdataout_bus [5:0];
    wire [1:0] lenout_bus [5:0];
    wire [1:0] reqout_bus [5:0];
    wire [3:0] reqtar_bus [5:0];
    wire [2:0] cmdout_bus [5:0];

    //to Device
    reg ackin_bus [5:0];
    reg [31:0] addrdatain_bus [5:0];
    reg [2:0] cmdin_bus [5:0];
    reg selin_bus [5:0];
    reg [1:0] lenin_bus [5:0];
    reg [4:0] burst_count;
    reg ackflag_resp;

    int i,j;
    reg [2:0] slv_id, w_master, arb_w_master;
        
    wire reqout_flag;


    arbiter arb(tbo.clk, tbo.reset, state, tbi.reqout, d0i.reqout, d1i.reqout, d2i.reqout, d3i.reqout, arb_w_master);

    assign reqout_flag = (tbi.reqout || d0i.reqout || d1i.reqout || d2i.reqout || d3i.reqout) ? 1:0;

    assign addrdataout_bus[0] = d0i.addrdataout;
    assign addrdataout_bus[1] = d1i.addrdataout;
    assign addrdataout_bus[2] = d2i.addrdataout;
    assign addrdataout_bus[3] = d3i.addrdataout;
    assign addrdataout_bus[4] = tbi.addrdataout;
    assign addrdataout_bus[5] = mbi.addrdataout;


    assign lenout_bus[0] = d0i.lenout;
    assign lenout_bus[1] = d1i.lenout;
    assign lenout_bus[2] = d2i.lenout;
    assign lenout_bus[3] = d3i.lenout;
    assign lenout_bus[4] = tbi.lenout;
    assign lenout_bus[5] = mbi.lenout;   

    assign reqout_bus[0] = d0i.reqout;
    assign reqout_bus[1] = d1i.reqout;
    assign reqout_bus[2] = d2i.reqout;
    assign reqout_bus[3] = d3i.reqout;
    assign reqout_bus[4] = tbi.reqout;
    assign reqout_bus[5] = mbi.reqout;

    assign reqtar_bus[0] = d0i.reqtar;
    assign reqtar_bus[1] = d1i.reqtar;
    assign reqtar_bus[2] = d2i.reqtar;
    assign reqtar_bus[3] = d3i.reqtar;
    assign reqtar_bus[4] = tbi.reqtar;
    assign reqtar_bus[5] = mbi.reqtar;

    assign cmdout_bus[0] = d0i.cmdout;
    assign cmdout_bus[1] = d1i.cmdout;
    assign cmdout_bus[2] = d2i.cmdout;
    assign cmdout_bus[3] = d3i.cmdout;
    assign cmdout_bus[4] = tbi.cmdout;
    assign cmdout_bus[5] = mbi.cmdout;

    assign d0i.ackin = ackin_bus[0];
    assign d1i.ackin = ackin_bus[1];
    assign d2i.ackin = ackin_bus[2];
    assign d3i.ackin = ackin_bus[3];
    assign tbi.ackin = ackin_bus[4];
    assign mbi.ackin = ackin_bus[5];

    assign d0o.addrdatain = addrdatain_bus[0];
    assign d1o.addrdatain = addrdatain_bus[1];
    assign d2o.addrdatain = addrdatain_bus[2];
    assign d3o.addrdatain = addrdatain_bus[3];
    assign tbo.addrdatain = addrdatain_bus[4];
    assign mbo.addrdatain = addrdatain_bus[5];

    assign d0o.cmdin = cmdin_bus[0];
    assign d1o.cmdin = cmdin_bus[1];
    assign d2o.cmdin = cmdin_bus[2];
    assign d3o.cmdin = cmdin_bus[3];
    assign tbo.cmdin = cmdin_bus[4];
    assign mbo.cmdin = cmdin_bus[5];

    assign d0o.selin = selin_bus[0];
    assign d1o.selin = selin_bus[1];
    assign d2o.selin = selin_bus[2];
    assign d3o.selin = selin_bus[3];
    assign tbo.selin = selin_bus[4];
    assign mbo.selin = selin_bus[5];

    assign d0o.lenin = lenin_bus[0];
    assign d1o.lenin = lenin_bus[1];
    assign d2o.lenin = lenin_bus[2];
    assign d3o.lenin = lenin_bus[3];
    assign tbo.lenin = lenin_bus[4];
    assign mbo.lenin = lenin_bus[5];

    always @(posedge tbo.clk or posedge d0o.reset) begin
        if (d0o.reset) begin
            state <= IDLE;
            w_master <= 0;
            slv_id <= 0;
            burst_count <= 1;
            ackflag_resp <= 0;
            
            for (int i = 0; i < 6; i = i + 1) begin
                addrdatain_bus[i] <= 0;
                cmdin_bus[i] <= 0;
                selin_bus[i] <= 0;
                lenin_bus[i] <= 0;
                ackin_bus[i] <= 0;
            end
            ackin_bus[4] <= 1;
        end else begin
            case (state)
                IDLE: begin
                    for (int i = 0; i < 6; i = i + 1) begin
                        addrdatain_bus[i] <= 0;
                        cmdin_bus[i] <= 0;
                        selin_bus[i] <= 0;
                        lenin_bus[i] <= 0;
                        ackin_bus[i] <= 0;
                    end
                    if(reqout_flag) begin
                        w_master <= arb_w_master;
                        slv_id <= decoder(addrdataout_bus[arb_w_master]);
                        state <= BUS_REQ;
                    end
                
                end
                BUS_REQ: begin
                    addrdatain_bus[slv_id] <= addrdataout_bus[w_master];
                    cmdin_bus[slv_id] <= cmdout_bus[w_master];
                    selin_bus[slv_id] <= 1;
                    lenin_bus[slv_id] <= lenout_bus[w_master];
                    if(ackin_bus[w_master] != 1) ackin_bus[w_master] <= 1;
                    else begin
                        if(lenout_bus[w_master] == 3) 
                            burst_count <= 16;
                        else burst_count <= 1;
                        ackin_bus[w_master] <= 0;
                        ackflag_resp <= 0;
                        state <= BUS_RESP;
                    end
                end

                BUS_RESP: begin
                    addrdatain_bus[slv_id] <= 0;
                    cmdin_bus[slv_id] <= 0;
                    selin_bus[slv_id] <= 0;
                    lenin_bus[slv_id] <= 0;

                    if (reqout_bus[slv_id] && !ackflag_resp) begin
                        ackin_bus[slv_id] <= 1;
                        ackflag_resp <= 1;
                    end 

                    else if(ackflag_resp) begin
                        if (ackin_bus[slv_id] == 1)
                            ackin_bus[slv_id] <= 0;
                        cmdin_bus[w_master] <= cmdout_bus[slv_id];
                        addrdatain_bus[w_master] <= addrdataout_bus[slv_id];
                        selin_bus[w_master] <= 1;
                        lenin_bus[w_master] <= lenout_bus[slv_id];
                        burst_count <= burst_count - 1;
                        if(burst_count == 1)  
                            state <= IDLE;
                    end
                end

            endcase
        end
    end

endmodule : bus_switch

//add in testbench stuff for write request issue
module arbiter(input clk, input reset, input [2:0] state, input [1:0] tb0_req, input [1:0] d0_req, input [1:0] d1_req, 
                input [1:0] d2_req, input [1:0] d3_req, output [2:0] grant, output prio0, output prio1,output prio2);

    reg prio [5:0]; // d0 - d3, tb0, mem0
    reg [2:0] grant_1;
    integer i;

    assign grant = grant_1;
    assign prio0 = prio[0];
    assign prio1 = prio[1];
    assign prio2 = prio[2];


    always @(negedge clk or posedge reset) begin
        if (reset) begin
            for ( i = 0; i < 6; i = i + 1)
                prio[i] = 0;
            prio[4] = 1;
            grant_1 = 0;
        end
        else begin
            if(state == 0) begin
                if (d0_req || d1_req || d2_req || d3_req || tb0_req) begin
                    if (tb0_req && prio[4] == 1) begin
                        grant_1 = 3'd4;
                        prio[0] = 0;
                        prio[1] = 0;
                        prio[2] = 0;
                        prio[3] = 1;
                        prio[4] = 0;
                    end
                    else if (d3_req && prio[3] == 1) begin
                        grant_1 = 3'd3;
                        prio[0] = 0;
                        prio[1] = 0;
                        prio[2] = 1;
                        prio[3] = 0;
                        prio[4] = 0;
                    end
                    if (d2_req && prio[2] == 1) begin
                        grant_1 = 3'd2;
                        prio[0] = 0;
                        prio[1] = 1;
                        prio[2] = 0;
                        prio[3] = 0;
                        prio[4] = 0;
                    end
                    else if (d1_req && prio[1] == 1) begin
                        grant_1 = 3'd1;
                        prio[0] = 1;
                        prio[1] = 0;
                        prio[2] = 0;
                        prio[3] = 0;
                        prio[4] = 0;
                    end
                    else if (d0_req && prio[0] == 1) begin
                        grant_1 = 3'd0;
                        prio[0] = 0;
                        prio[1] = 0;
                        prio[2] = 0;
                        prio[3] = 0;
                        prio[4] = 1;
                    end
                    else if (tb0_req) begin
                        grant_1 = 3'd4;
                        prio[0] = 0;
                        prio[1] = 0;
                        prio[2] = 0;
                        prio[3] = 1;
                        prio[4] = 0;
                    end
                    else if (d3_req) begin
                        grant_1 = 3'd3;
                        prio[0] = 0;
                        prio[1] = 0;
                        prio[2] = 1;
                        prio[3] = 0;
                        prio[4] = 0;
                    end
                    else if (d2_req) begin
                        grant_1 = 3'd2;
                        prio[0] = 0;
                        prio[1] = 1;
                        prio[2] = 0;
                        prio[3] = 0;
                        prio[4] = 0;
                    end
                    else if (d1_req) begin
                        grant_1 = 3'd1;
                        prio[0] = 1;
                        prio[1] = 0;
                        prio[2] = 0;
                        prio[3] = 0;
                        prio[4] = 0;
                    end
                    else if(d0_req) begin
                        grant_1 = 3'd0;
                        prio[0] = 0;
                        prio[1] = 0;
                        prio[2] = 0;
                        prio[3] = 0;
                        prio[4] = 1;
                    end
                    
                end
            end
        end
    end

endmodule
