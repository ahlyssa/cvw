///////////////////////////////////////////
// lrsc.sv
//
// Written: David_Harris@hmc.edu 17 July 2021
// Modified: 
//
// Purpose: Load Reserved / Store Conditional unit
//          Track the reservation and squash the store if it fails
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT 
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

`include "wally-config.vh"

module lrsc
  (
    input  logic                clk, reset,
    input  logic                FlushW, StallWtoDCache,
    input  logic                MemReadM,
    input  logic [1:0]          MemRWMtoLRSC,
    output logic [1:0]          MemRWMtoDCache,
    input  logic [1:0] 	        AtomicMtoDCache,
    input  logic [`PA_BITS-1:0] MemPAdrM,  // from mmu to dcache
    output logic                SquashSCM,
    output logic                SquashSCW
);
  // Handle atomic load reserved / store conditional
  generate
    if (`A_SUPPORTED) begin // atomic instructions supported
      logic [`PA_BITS-1:2]  ReservationPAdrW;
      logic 		            ReservationValidM, ReservationValidW; 
      logic 		            lrM, scM, WriteAdrMatchM;

      assign lrM = MemReadM && AtomicMtoDCache[0];
      assign scM = MemRWMtoLRSC[0] && AtomicMtoDCache[0]; 
      assign WriteAdrMatchM = MemRWMtoLRSC[0] && (MemPAdrM[`PA_BITS-1:2] == ReservationPAdrW) && ReservationValidW;
      assign SquashSCM = scM && ~WriteAdrMatchM;
      assign MemRWMtoDCache = SquashSCM ? 2'b00 : MemRWMtoLRSC;
      always_comb begin // ReservationValidM (next value of valid reservation)
        if (lrM) ReservationValidM = 1;  // set valid on load reserve
        else if (scM || WriteAdrMatchM) ReservationValidM = 0; // clear valid on store to same address or any sc
        else ReservationValidM = ReservationValidW; // otherwise don't change valid
      end
      flopenrc #(`PA_BITS-2) resadrreg(clk, reset, FlushW, lrM, MemPAdrM[`PA_BITS-1:2], ReservationPAdrW); // could drop clear on this one but not valid
      flopenrc #(1) resvldreg(clk, reset, FlushW, lrM, ReservationValidM, ReservationValidW);
      flopenrc #(1) squashreg(clk, reset, FlushW, ~StallWtoDCache, SquashSCM, SquashSCW);
    end else begin // Atomic operations not supported
      assign SquashSCM = 0;
      assign SquashSCW = 0;
      assign MemRWMtoDCache = MemRWMtoLRSC;
    end
  endgenerate
endmodule
