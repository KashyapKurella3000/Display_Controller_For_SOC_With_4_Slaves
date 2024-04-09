• Led a team of three to implement a display controller and a bus in SystemVerilog
• Final design had 4 virtual display devices connected to a testbench and memory module via a bus
• Each display controller handles write requests and sends out read requests
• Each write request is followed up by a write response and an acknowledge signal
• Display controller will send out read requests and supports bursting of lengths 1, 4, 8, and 16
• Implemented a 64MB FIFO to read from the memory and output the decoded RGB data to testbench simultaneously
• Debugged and tested the controller and bus by looking at VCD files with GTKWave
• Device only bursts based on how much memory the FIFO has left
• Created a priority round robin arbitrator to decide which device wins the bus
• Bus design moved through 3 states: 
 1. IDLE: nothing happens, wait for request
 2. BUS_REQ: request detected, if there are multiple, arbiter decides who wins the bus. Connect the 
 master signals to slave signals
 3. BUS_RESP: request is handled and correct master signals are connected to slave signals. Handle bursts 
 and connects appropriate signals together for a cycle, then resets signals and returns bus to idle state
