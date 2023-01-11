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
        default: decoder = 4;
    endcase
endfunction

module bus_switch(BUSI.swporti tbi,BUSI.swporto tbo,BUSI.swporti d0i,BUSI.swporto d0o,
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

    int i,j;
    reg [2:0] slv_id, w_master, arb_w_master;
        
    wire reqout_flag;


    arbiter arb(tbo.clk, tbo.reset, current_state, tbi.reqout, 0, d0i.reqout, d1i.reqout, d2i.reqout, d3i.reqout, arb_w_master);

    assign reqout_flag = (tbi.reqout || d0i.reqout || d1i.reqout || d2i.reqout || d3i.reqout);

    assign addrdataout_bus[0] = d0i.addrdataout;
    assign addrdataout_bus[1] = d1i.addrdataout;
    assign addrdataout_bus[2] = d2i.addrdataout;
    assign addrdataout_bus[3] = d3i.addrdataout;
    assign addrdataout_bus[4] = tbi.addrdataout;

    assign lenout_bus[0] = d0i.lenout;
    assign lenout_bus[1] = d1i.lenout;
    assign lenout_bus[2] = d2i.lenout;
    assign lenout_bus[3] = d3i.lenout;
    assign lenout_bus[4] = tbi.lenout;   

    assign reqout_bus[0] = d0i.reqout;
    assign reqout_bus[1] = d1i.reqout;
    assign reqout_bus[2] = d2i.reqout;
    assign reqout_bus[3] = d3i.reqout;
    assign reqout_bus[4] = tbi.reqout;

    assign reqtar_bus[0] = d0i.reqtar;
    assign reqtar_bus[1] = d1i.reqtar;
    assign reqtar_bus[2] = d2i.reqtar;
    assign reqtar_bus[3] = d3i.reqtar;
    assign reqtar_bus[4] = tbi.reqtar;

    assign cmdout_bus[0] = d0i.cmdout;
    assign cmdout_bus[1] = d1i.cmdout;
    assign cmdout_bus[2] = d2i.cmdout;
    assign cmdout_bus[3] = d3i.cmdout;
    assign cmdout_bus[4] = tbi.cmdout;

    assign d0i.ackin = ackin_bus[0];
    assign d1i.ackin = ackin_bus[1];
    assign d2i.ackin = ackin_bus[2];
    assign d3i.ackin = ackin_bus[3];
    assign tbi.ackin = ackin_bus[4];

    assign d0o.addrdatain = addrdatain_bus[0];
    assign d1o.addrdatain = addrdatain_bus[1];
    assign d2o.addrdatain = addrdatain_bus[2];
    assign d3o.addrdatain = addrdatain_bus[3];
    assign tbo.addrdatain = addrdatain_bus[4];

    assign d0o.cmdin = cmdin_bus[0];
    assign d1o.cmdin = cmdin_bus[1];
    assign d2o.cmdin = cmdin_bus[2];
    assign d3o.cmdin = cmdin_bus[3];
    assign tbo.cmdin = cmdin_bus[4];

    assign d0o.selin = selin_bus[0];
    assign d1o.selin = selin_bus[1];
    assign d2o.selin = selin_bus[2];
    assign d3o.selin = selin_bus[3];
    assign tbo.selin = selin_bus[4];

    assign d0o.lenin = lenin_bus[0];
    assign d1o.lenin = lenin_bus[1];
    assign d2o.lenin = lenin_bus[2];
    assign d3o.lenin = lenin_bus[3];
    assign tbo.lenin = lenin_bus[4];

    always @(posedge tbo.clk or posedge d0o.reset) begin
        if (d0o.reset) begin
            state <= IDLE;
            w_master <= 0;
            slv_id <= 0;
            
            for (int i = 0; i < 6; i = i + 1) begin
                addrdatain_bus[i] <= 0;
                cmdin_bus[i] <= 0;
                selin_bus[i] <= 0;
                lenin_bus[i] <= 0;
                ackin_bus[i] <= 0;
            end
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
                    
                    if(ackin_bus[w_master] != 1) ackin_bus[w_master] <= 1;
                    addrdatain_bus[slv_id] <= addrdataout_bus[w_master];
                    cmdin_bus[slv_id] <= cmdout_bus[w_master];
                    selin_bus[slv_id] <= 1;
                    lenin_bus[slv_id] <= lenout_bus[w_master];
                    if(ackin_bus[w_master] == 1) begin
                        ackin_bus[w_master] <= 0;
                        state <= BUS_RESP;
                    end
                end

                BUS_RESP: begin
                    addrdatain_bus[slv_id] <= 0;
                    cmdin_bus[slv_id] <= 0;
                    selin_bus[slv_id] <= 0;
                    lenin_bus[slv_id] <= 0;
                    if (ackin_bus[slv_id] == 1) begin
                        ackin_bus[slv_id] <= 0;
                        cmdin_bus[w_master] <= cmdout_bus[slv_id];
                        state <= IDLE;
                    end
                    else if (reqout_bus[slv_id]) begin
                        ackin_bus[slv_id] <= 1;
                        addrdatain_bus[w_master] <= addrdataout_bus[slv_id];
                        selin_bus[w_master] <= 1;
                        lenin_bus[w_master] <= lenout_bus[slv_id];
                    end
                    
                end

            endcase
        end
    end

endmodule : bus_switch

module arbiter(input clk, input rst, input [2:0] current_state, input [1:0] tb0_req, input [1:0] tb1_req, input [1:0] d0_req, input [1:0] d1_req, 
                input [1:0] d2_req, input [1:0] d3_req, output [2:0] w_master);

    reg [1:0] max_array [5:0];
    assign max_array[0] = d0_req;
    assign max_array[1] = d1_req;
    assign max_array[2] = d2_req;
    assign max_array[3] = d3_req;
    assign max_array[4] = tb0_req;
    assign max_array[5] = tb1_req;

    reg [2:0] prio [5:0]; // d0 - d3, tb0, tb1
    reg [2:0] prio_d [5:0];
    reg [2:0] grant_d;

    assign w_master = grant_d;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (reg [2:0] i = 0; i < 6; i = i + 1)
                prio[i] <= i;
        end
        else begin
            for (int i = 0; i < 6; i = i + 1)
                prio[i] <= prio_d[i];
        end
    end

    always @(*) begin
        for (int i = 0; i < 6; i = i + 1)
            prio_d[i] = prio[i];

        if (d0_req)
            grant_d = 0;
        else
            grant_d = 4;
    end
endmodule