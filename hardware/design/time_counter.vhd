-----------------------------------------------------------------------------
-- Faculty of Electrical Engineering
-- PDS 2024
-- https://github.com/etf-unibl/fpga-pwg
-----------------------------------------------------------------------------
--
-- unit name:     TIME COUNTER
--
-- description:
--
--   This file implements time counter circuit.
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
--! @file time_counter.vhd
--! @brief Time counter circuit
-------------------------------------------------------

--! Use standard library
library ieee;
--! Use logic elements
use ieee.std_logic_1164.all;
--! Use numeric types and conversion functions
use ieee.numeric_std.all;

--! @brief Time counter entity description
--! @details Entity is responsible for counting time with 20 ns resolution.
--! It takes a clock signal, a reset signal, a set signal and the preset time in unix time format.
--! It outputs 64-bit vector which shows the passed time in unix format plus the nanoseconds.

--! @structure
--! The entity has the following ports:
--! `clk_i` is the clock input, used to synchronize the circuit.
--! `rst_i` is the reset input, which resets the time signals when asserted.
--! `set_i` is a signal that initializes higher 32 bits of time output to
--! the current unix time specified by user, when asserted.
--! `time_i` is the input signal which holds the value of the current
--! unix time that is initializing time output when set_i is asserted.
--! `time_o` is the 64-bit output signal representing the passed time.
--! Higher 32 bits represent passed time in unix time format and the
--! lower 32 bits represent higher precision improvement in nanoseconds.

entity time_counter is
  port(
    clk_i  : in  std_logic; --! Clock signal input
    rst_i  : in  std_logic; --! Asynchronous reset signal input
    set_i  : in  std_logic; --! Synchronous set signal input
    time_i : in  std_logic_vector(31 downto 0); --! Current time to be set in unix time format
    time_o : out std_logic_vector(63 downto 0) --! Passed time in unix format + nanoseconds
  );
end time_counter;

--! @brief Architecture definition of the time counter
--! @details Architecture implemented using methodology of regular
--! structured sequential circuits with two registers for unix time
--! and nanoseconds time. Unix time counter increments when nanoseconds
--! coutner counts to 10^9 (1 second). Nanoseconds counter then resets.
--! Asserting rst_i signal resets all counters to zeros. Asserting set_i
--! signal sets value of unix time register to the time_i input value.

architecture arch of time_counter is
  signal unix_time_reg  : unsigned(31 downto 0);
  signal nano_time_reg  : unsigned(31 downto 0);
  signal unix_time_next : unsigned(31 downto 0);
  signal nano_time_next : unsigned(31 downto 0);
begin
  -- state registers
  process(clk_i, rst_i, set_i)
  begin
    if rst_i = '1' then
      unix_time_reg <= (others => '0');
      nano_time_reg <= (others => '0');
    elsif rising_edge(clk_i) then
      if set_i = '1' then
        unix_time_reg <= unsigned(time_i);
        nano_time_reg <= (others => '0');
      else
        unix_time_reg <= unix_time_next;
        nano_time_reg <= nano_time_next;
      end if;
    end if;
  end process;
  -- next state logic
  process(unix_time_reg, nano_time_reg)
  begin
    if nano_time_reg = "00111011100110101100100111101100" then
      nano_time_next <= (others => '0');
      unix_time_next <= unix_time_reg + 1;
    else
      nano_time_next <= nano_time_reg + 20;
      unix_time_next <= unix_time_reg;
    end if;
  end process;
  -- output logic
  time_o(63 downto 32) <= std_logic_vector(unix_time_reg);
  time_o(31 downto 0)  <= std_logic_vector(nano_time_reg);
end arch;
