#include "xaxidma.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "image_data.h"    // your real image!

// Must match image_data.h
#define IMG_SIZE    (IMG_WIDTH * IMG_HEIGHT)

XAxiDma AxiDma;

// Buffers in DDR
u32 InputImage[IMG_SIZE]  __attribute__((aligned(32)));
u32 OutputImage[IMG_SIZE] __attribute__((aligned(32)));

// Load grayscale bytes from image_data.h into u32 buffer
void load_image() {
    int i;
    for (i = 0; i < IMG_SIZE; i++) {
        InputImage[i] = (u32)(image_data[i]);
    }
    xil_printf("Image loaded: %dx%d = %d pixels\r\n",
               IMG_WIDTH, IMG_HEIGHT, IMG_SIZE);
}

int init_dma() {
    XAxiDma_Config *CfgPtr;
    int Status;

    CfgPtr = XAxiDma_LookupConfig(XPAR_AXIDMA_0_DEVICE_ID);
    if (!CfgPtr) {
        xil_printf("ERROR: DMA config not found\r\n");
        return XST_FAILURE;
    }

    Status = XAxiDma_CfgInitialize(&AxiDma, CfgPtr);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: DMA init failed\r\n");
        return XST_FAILURE;
    }

    XAxiDma_Reset(&AxiDma);
    while (!XAxiDma_ResetIsDone(&AxiDma));
    xil_printf("DMA reset done.\r\n");

    XAxiDma_IntrDisable(&AxiDma,
                        XAXIDMA_IRQ_ALL_MASK,
                        XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&AxiDma,
                        XAXIDMA_IRQ_ALL_MASK,
                        XAXIDMA_DMA_TO_DEVICE);

    return XST_SUCCESS;
}

int run_edge_detection() {
    int Status;
    u32 transfer_size = IMG_SIZE * sizeof(u32);

    xil_printf("Transfer size: %d bytes\r\n", transfer_size);

    Xil_DCacheFlushRange((UINTPTR)InputImage, transfer_size);
    Xil_DCacheInvalidateRange((UINTPTR)OutputImage, transfer_size);

    xil_printf("Starting RX...\r\n");
    Status = XAxiDma_SimpleTransfer(&AxiDma,
                                    (UINTPTR)OutputImage,
                                    transfer_size,
                                    XAXIDMA_DEVICE_TO_DMA);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: RX failed. Status=%d\r\n", Status);
        return XST_FAILURE;
    }
    xil_printf("RX started OK.\r\n");

    xil_printf("Starting TX...\r\n");
    Status = XAxiDma_SimpleTransfer(&AxiDma,
                                    (UINTPTR)InputImage,
                                    transfer_size,
                                    XAXIDMA_DMA_TO_DEVICE);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: TX failed. Status=%d\r\n", Status);
        return XST_FAILURE;
    }
    xil_printf("TX started OK.\r\n");

    xil_printf("Waiting for DMA...\r\n");

    int timeout = 10000000;
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE)) {
        if (--timeout == 0) {
            xil_printf("ERROR: TX timeout!\r\n");
            return XST_FAILURE;
        }
    }
    xil_printf("TX done.\r\n");

    timeout = 10000000;
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA)) {
        if (--timeout == 0) {
            xil_printf("ERROR: RX timeout!\r\n");
            return XST_FAILURE;
        }
    }
    xil_printf("RX done.\r\n");

    return XST_SUCCESS;
}

void print_results() {
    int edge_count = 0;
    int i, x, y;

    for (i = 0; i < IMG_SIZE; i++) {
        // ✅ FIXED HERE
        if (OutputImage[i] != 0)
            edge_count++;
    }

    xil_printf("\r\n=== RESULTS ===\r\n");
    xil_printf("Total pixels    : %d\r\n", IMG_SIZE);
    xil_printf("Edge pixels     : %d\r\n", edge_count);
    xil_printf("Edge percentage : %d%%\r\n",
               (edge_count * 100) / IMG_SIZE);

    xil_printf("\r\nEdge map preview (every 8th pixel = 64x64):\r\n");
    for (y = 0; y < IMG_HEIGHT; y += 8) {
        for (x = 0; x < IMG_WIDTH; x += 8) {
            xil_printf(OutputImage[y * IMG_WIDTH + x]
                       ? "#" : ".");
        }
        xil_printf("\r\n");
    }
}

/* ===========================
   UPDATED FUNCTION
=========================== */
void send_output_image() {
    int i;

    xil_printf("\r\n===IMAGE_START===\r\n");

    for (i = 0; i < IMG_SIZE; i++) {

        // ✅ FIXED HERE
        if (OutputImage[i] != 0)
            xil_printf("1");
        else
            xil_printf("0");

        if ((i + 1) % IMG_WIDTH == 0)
            xil_printf("\n");
    }

    xil_printf("===IMAGE_END===\r\n");
}

int main() {
    xil_printf("\r\n=== Edge Detection - Zynq ZedBoard ===\r\n");
    xil_printf("Image: hand.jpg (512x512 grayscale)\r\n\r\n");

    xil_printf("Step 1: Loading image...\r\n");
    load_image();

    xil_printf("Step 2: Initialising DMA...\r\n");
    if (init_dma() != XST_SUCCESS) {
        xil_printf("FAILED at DMA init\r\n");
        return -1;
    }
    xil_printf("DMA ready.\r\n");

    xil_printf("Step 3: Running edge detection...\r\n");
    if (run_edge_detection() != XST_SUCCESS) {
        xil_printf("FAILED at edge detection\r\n");
        return -1;
    }

    xil_printf("Step 4: Printing results...\r\n");
    print_results();

    send_output_image();

    xil_printf("\r\n=== DONE ===\r\n");
    return 0;
}
