# Real-Time Edge Detection Using Zynq SoC

**PS-PL Co-Design on ZedBoard (Zynq-7020)**

---

## Student Details
- **Name:** Kethavath Sai Kiran
- **Course:** System on Chip (SoC) Design

---

## Project Overview
This project implements real-time edge detection on a Xilinx Zynq-7020 SoC 
using PS-PL co-design. The Sobel edge detection algorithm runs in custom 
Verilog hardware (PL) while the ARM Cortex-A9 (PS) handles control via AXI DMA.

---

## Tools Used
| Tool | Version |
|------|---------|
| Vivado | 2023.1 |
| Vitis | 2023.1 |
| Board | ZedBoard (Zynq-7020) |
| Language (PL) | Verilog |
| Language (PS) | C |

---

## Results
- Image size: 512 x 512 pixels
- Edge pixels detected: 7,974
- Edge percentage: 3%
- Transfer size: 1 MB via AXI DMA
- Clock: 50 MHz

---

## Result Images

### Input vs Output
![Comparison](images/comparison.png)

---

## Project Structure
