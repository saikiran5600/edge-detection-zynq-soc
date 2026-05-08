`timescale 1 ns / 1 ps

module edge_ip_v1_0 #
(
    parameter integer C_S00_AXI_DATA_WIDTH   = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH   = 4,
    parameter integer C_S00_AXIS_TDATA_WIDTH = 32,
    parameter integer C_M00_AXIS_TDATA_WIDTH = 32,
    parameter integer C_M00_AXIS_START_COUNT = 32,
    parameter integer IMG_WIDTH              = 512
)
(
    // AXI-Lite
    input  wire                                    s00_axi_aclk,
    input  wire                                    s00_axi_aresetn,
    input  wire [C_S00_AXI_ADDR_WIDTH-1:0]          s00_axi_awaddr,
    input  wire [2:0]                              s00_axi_awprot,
    input  wire                                    s00_axi_awvalid,
    output wire                                    s00_axi_awready,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0]          s00_axi_wdata,
    input  wire [(C_S00_AXI_DATA_WIDTH/8)-1:0]      s00_axi_wstrb,
    input  wire                                    s00_axi_wvalid,
    output wire                                    s00_axi_wready,
    output wire [1:0]                              s00_axi_bresp,
    output wire                                    s00_axi_bvalid,
    input  wire                                    s00_axi_bready,
    input  wire [C_S00_AXI_ADDR_WIDTH-1:0]          s00_axi_araddr,
    input  wire [2:0]                              s00_axi_arprot,
    input  wire                                    s00_axi_arvalid,
    output wire                                    s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1:0]          s00_axi_rdata,
    output wire [1:0]                              s00_axi_rresp,
    output wire                                    s00_axi_rvalid,
    input  wire                                    s00_axi_rready,

    // AXI-Stream Slave
    input  wire                                    s00_axis_aclk,
    input  wire                                    s00_axis_aresetn,
    output wire                                    s00_axis_tready,
    input  wire [C_S00_AXIS_TDATA_WIDTH-1:0]        s00_axis_tdata,
    input  wire [(C_S00_AXIS_TDATA_WIDTH/8)-1:0]    s00_axis_tstrb,
    input  wire                                    s00_axis_tlast,
    input  wire                                    s00_axis_tvalid,

    // AXI-Stream Master
    input  wire                                    m00_axis_aclk,
    input  wire                                    m00_axis_aresetn,
    output wire                                    m00_axis_tvalid,
    output wire [C_M00_AXIS_TDATA_WIDTH-1:0]        m00_axis_tdata,
    output wire [(C_M00_AXIS_TDATA_WIDTH/8)-1:0]    m00_axis_tstrb,
    output wire                                    m00_axis_tlast,
    input  wire                                    m00_axis_tready
);

//=============================================================
// AXI-Lite Slave
//=============================================================
edge_ip_v1_0_S00_AXI #(
    .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
) edge_ip_v1_0_S00_AXI_inst (
    .S_AXI_ACLK    (s00_axi_aclk),
    .S_AXI_ARESETN (s00_axi_aresetn),
    .S_AXI_AWADDR  (s00_axi_awaddr),
    .S_AXI_AWPROT  (s00_axi_awprot),
    .S_AXI_AWVALID (s00_axi_awvalid),
    .S_AXI_AWREADY (s00_axi_awready),
    .S_AXI_WDATA   (s00_axi_wdata),
    .S_AXI_WSTRB   (s00_axi_wstrb),
    .S_AXI_WVALID  (s00_axi_wvalid),
    .S_AXI_WREADY  (s00_axi_wready),
    .S_AXI_BRESP   (s00_axi_bresp),
    .S_AXI_BVALID  (s00_axi_bvalid),
    .S_AXI_BREADY  (s00_axi_bready),
    .S_AXI_ARADDR  (s00_axi_araddr),
    .S_AXI_ARPROT  (s00_axi_arprot),
    .S_AXI_ARVALID (s00_axi_arvalid),
    .S_AXI_ARREADY (s00_axi_arready),
    .S_AXI_RDATA   (s00_axi_rdata),
    .S_AXI_RRESP   (s00_axi_rresp),
    .S_AXI_RVALID  (s00_axi_rvalid),
    .S_AXI_RREADY  (s00_axi_rready)
);

//=============================================================
// SOBEL EDGE DETECTION CORE
//=============================================================

// Line buffers
reg [7:0] line_buf0 [0:IMG_WIDTH-1];
reg [7:0] line_buf1 [0:IMG_WIDTH-1];

// Position tracking
reg [15:0] col_cnt;
reg [1:0]  row_cnt;

// 3x3 window
reg [7:0] p00, p01, p02;
reg [7:0] p10, p11, p12;
reg [7:0] p20, p21, p22;

// Output registers
reg [31:0] result_data;
reg        result_valid;
reg        result_last;

// ? FIXED: moved outside always block
reg signed [11:0] Gx;
reg signed [11:0] Gy;
reg        [11:0] abs_Gx;
reg        [11:0] abs_Gy;
reg        [11:0] magnitude;

// AXI ready
assign s00_axis_tready = 1'b1;

// Pixel input
wire [7:0] pixel_in = s00_axis_tdata[7:0];

always @(posedge s00_axis_aclk) begin
    if (!s00_axis_aresetn) begin
        col_cnt      <= 0;
        row_cnt      <= 0;
        result_valid <= 0;
        result_last  <= 0;
        result_data  <= 0;

        p00 <= 0; p01 <= 0; p02 <= 0;
        p10 <= 0; p11 <= 0; p12 <= 0;
        p20 <= 0; p21 <= 0; p22 <= 0;

    end else if (s00_axis_tvalid) begin

        // Shift window
        p00 <= p01;  p01 <= p02;  p02 <= line_buf0[col_cnt];
        p10 <= p11;  p11 <= p12;  p12 <= line_buf1[col_cnt];
        p20 <= p21;  p21 <= p22;  p22 <= pixel_in;

        // Update buffers
        line_buf0[col_cnt] <= line_buf1[col_cnt];
        line_buf1[col_cnt] <= pixel_in;

        // Counters
        if (col_cnt == IMG_WIDTH - 1) begin
            col_cnt <= 0;
            if (row_cnt < 2)
                row_cnt <= row_cnt + 1;
        end else begin
            col_cnt <= col_cnt + 1;
        end

        // Sobel
        if (row_cnt == 2) begin

            Gx = ( {4'b0, p02} + {3'b0, p12, 1'b0} + {4'b0, p22} )
               - ( {4'b0, p00} + {3'b0, p10, 1'b0} + {4'b0, p20} );

            Gy = ( {4'b0, p00} + {3'b0, p01, 1'b0} + {4'b0, p02} )
               - ( {4'b0, p20} + {3'b0, p21, 1'b0} + {4'b0, p22} );

            abs_Gx = Gx[11] ? (~Gx + 1) : Gx;
            abs_Gy = Gy[11] ? (~Gy + 1) : Gy;

            magnitude = abs_Gx + abs_Gy;

            result_data  <= (magnitude > 100) ? 32'hFFFFFFFF
                                              : 32'h00000000;
            result_valid <= 1'b1;
            result_last  <= s00_axis_tlast;

        end else begin
            result_data  <= 32'h00000000;
            result_valid <= 1'b1;
            result_last  <= s00_axis_tlast;
        end

    end else begin
        result_valid <= 1'b0;
        result_last  <= 1'b0;
    end
end

// Output
assign m00_axis_tdata  = result_data;
assign m00_axis_tvalid = result_valid;
assign m00_axis_tstrb  = 4'hF;
assign m00_axis_tlast  = result_last;

endmodule