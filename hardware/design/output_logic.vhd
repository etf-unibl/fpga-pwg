-----------------------------------------------------------------------------
-- Faculty of Electrical Engineering
-- PDS 2024
-- https://github.com/etf-unibl/fpga-pwg
-----------------------------------------------------------------------------
--
-- unit name:     OUTPUT LOGIC
--
-- description:
--
--   This file implements output logic circuit.
--
-----------------------------------------------------------------------------
-- Copyright (c) 2024 Faculty of Electrical Engineering
-----------------------------------------------------------------------------
-- The MIT License
-----------------------------------------------------------------------------
-- Copyright 2024 Faculty of Electrical Engineering
--
-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom
-- the Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
-- THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
-- ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
-- OTHER DEALINGS IN THE SOFTWARE
-----------------------------------------------------------------------------

-------------------------------------------------------
--! @file output_logic.vhd
--! @brief Output logic circuit
-------------------------------------------------------
--! Use standard library
library ieee;
--! Use logic elements
use ieee.std_logic_1164.all;
--! Use numeric types and conversion functions
use ieee.numeric_std.all;

--! @brief Output logic entity description
--! @details Entity is responsible for implementig the output logic circuit.
--! It compares the input counter time with the user specified time and sets
--! the system output accordingly. The output is a single bit indicating the
--! match between the counter time and user time.

--! @structure
--! The entity has the following ports:
--! `clk_i` is the clock input, used to synchronize the circuit.
--! `rst_i` is the reset input, which resets the time signals when asserted.
--! `value_i` is the input signal representing a value to be decoded.
--! `counter_time_i` is the input signal representing the counter time.
--! `user_time_i` is the input signal representing the user-specified time.
--! `system_o` is the output signal indicating the match between counter and user time.

entity output_logic is
  port(
    clk_i          :  in std_logic; --! Clock signal input
    rst_i          :  in std_logic; --! Asynchronous reset signal input
    value_i        :  in std_logic_vector(31 downto 0); --! Input signal representing a value to be decoded
    counter_time_i :  in std_logic_vector(63 downto 0); --! Input signal representing the counter time
    user_time_i    :  in std_logic_vector(63 downto 0); --! Input signal representing the user-specified time
    system_o       : out std_logic                      --! Output signal indicating the match between counter and user time
  );
end output_logic;

--! @brief Output logic architecture
--! The architecture contains the following processes:
--! Comparator logic process for determining the match between counter and user time.
--! D-FF (D Flip-Flop) logic process for storing the current state.
--! VALUE decoder process for decoding a specific value.
--! Next-state logic for updating the state based on the comparator and decoder outputs.
--! Output logic for setting the system output.

architecture arch of output_logic is
  signal q_cmp       : std_logic;
  signal val_decoded : std_logic;
  signal q_reg       : std_logic;
  signal q_next      : std_logic;
begin
  -- comparator logic
  process(counter_time_i, user_time_i)
  begin
    if counter_time_i = user_time_i then
      q_cmp <= '1';
    else
      q_cmp <= '0';
    end if;
  end process;

  -- D-FF logic
  process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      q_reg <= '0';
    elsif rising_edge(clk_i) then
      q_reg <= q_next;
    end if;
  end process;

  -- VALUE decoder
  process(value_i)
  begin
    if value_i = "11111111111111111111111111111111" then
      val_decoded <= '1';
    else
      val_decoded <= '0';
    end if;
  end process;

  -- next-state logic
  q_next <= val_decoded when q_cmp = '1' else q_reg;

  -- output logic
  system_o <= q_next;
end arch;
