// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * CLIC Wrapper for Ibex Core
 *
 * This module provides a simple wrapper to connect CLIC signals to the
 * existing Ibex interrupt interface. It maps CLIC interrupts to the
 * fast interrupt inputs of Ibex.
 */

module ibex_clic_wrapper (
  // Clock and Reset
  input  logic        clk_i,
  input  logic        rst_ni,

  // CLIC Interface
  input  logic        clic_irq_i,         // CLIC interrupt request
  input  logic [11:0] clic_irq_id_i,      // CLIC interrupt ID
  input  logic [7:0]  clic_irq_priority_i,// CLIC interrupt priority
  output logic        clic_claim_o,       // CLIC claim output
  output logic [7:0]  clic_threshold_o,   // CLIC threshold output

  // Existing Ibex interrupt interface
  output logic [14:0] irq_fast_o          // Fast interrupts to Ibex
);

  // Internal registers
  logic        clic_irq_pending_q;
  logic [11:0] clic_irq_id_q;
  logic [7:0]  clic_irq_priority_q;
  logic [7:0]  clic_threshold_q;

  // Default threshold value (0 = all interrupts enabled)
  localparam logic [7:0] DEFAULT_THRESHOLD = 8'h00;

  // Capture CLIC interrupt request
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      clic_irq_pending_q  <= 1'b0;
      clic_irq_id_q       <= 12'b0;
      clic_irq_priority_q <= 8'b0;
      clic_threshold_q    <= DEFAULT_THRESHOLD;
    end else begin
      if (clic_irq_i && (clic_irq_priority_i > clic_threshold_q)) begin
        clic_irq_pending_q  <= 1'b1;
        clic_irq_id_q       <= clic_irq_id_i;
        clic_irq_priority_q <= clic_irq_priority_i;
      end else if (!clic_irq_i) begin
        // Clear pending when CLIC interrupt is deasserted
        clic_irq_pending_q <= 1'b0;
      end
    end
  end

  // Map CLIC interrupt to fast interrupt lines
  // For simplicity, we use the lower 4 bits of CLIC ID to select which fast IRQ
  always_comb begin
    irq_fast_o = 15'b0;
    if (clic_irq_pending_q) begin
      // Map to one of the 15 fast interrupt lines based on CLIC ID
      irq_fast_o[clic_irq_id_q[3:0]] = 1'b1;
    end
  end

  // Generate claim signal when interrupt is taken
  // For now, generate a pulse when the interrupt transitions from pending to not pending
  logic clic_irq_pending_d;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      clic_claim_o <= 1'b0;
      clic_irq_pending_d <= 1'b0;
    end else begin
      clic_irq_pending_d <= clic_irq_pending_q;
      // Pulse claim when interrupt was pending and is now cleared
      clic_claim_o <= clic_irq_pending_d && !clic_irq_pending_q;
    end
  end

  // Output current threshold
  assign clic_threshold_o = clic_threshold_q;

  // TODO: Add CSR interface to allow software to update threshold
  // For now, it remains at the default value

endmodule