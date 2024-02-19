-----------------------------------------------------------------------------
-- Faculty of Electrical Engineering
-- PDS 2024
-- https://github.com/etf-unibl/fpga-pwg
-----------------------------------------------------------------------------
--
-- unit name:     REGISTER FILE
--
-- description:
--
--   This file implements register file as Avalon-MM slave device.
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

------------------------------------------------------------------
--! @file register_file.vhd
--! @brief Register file implemented as an Avalon-MM slave device
------------------------------------------------------------------

--! Use standard library
library ieee;
--! Use logic elements
use ieee.std_logic_1164.all;
--! Use numeric types and conversion functions
use ieee.numeric_std.all;

--! @brief Register file entity with Avalon-MM slave interface
--! @details This entity is designed as an Avalon-MM slave device and it has
--! the purpose of creating a register file. Registers from the register file
--! have to be accessed by the Avalon-MM master so that the user can configure
--! the current system time, timestamps, to control the device and to check
--! the status signals. Register file contains the following registers:
--! 'SYS_TIME' - Holds the current system time in unix time format,
--! 'STATUS' - Holds status signals from FIFO buffer and ERROR flag,
--! 'CONTROL' - Holds control signals and flags used to configure the device,
--! 'FALL_TS_H' - Holds unix time timestamp for logic LOW output,
--! 'FALL_TS_L' - Holds nanosecond time timestamp for logic LOW output,
--! 'RISE_TS_H' - Holds unix time timestamp for logic HIGH output,
--! 'RISE_TS_L' - Holds nanosecond time timestamp for logic HIGH output.
--! The entity itself has ports which are compatible with basic Avalon-MM interface.

entity register_file is
  port(
    clk_i            : in  std_logic; --! Clock signal input
    av_read_i        : in  std_logic; --! Avalon-MM read indicator
    av_write_i       : in  std_logic; --! Avalon-MM write indicator
    av_address_i     : in  std_logic_vector(31 downto 0); --! Avalon-MM address signal
    av_writedata_i   : in  std_logic_vector(31 downto 0); --! Avalon-MM data input
    av_readdata_o    : out std_logic_vector(31 downto 0); --! Avalon-MM data output
    av_waitrequest_o : out std_logic --! Avalon-MM wait-state signal for response control
  );
end register_file;

--! @brief Architecture definition of the register file
--! @details Architecture implements register file by defining a new data type.
--! New data type is an array of seven 32-bit long bit vectors, which correspond
--! to the previously described registers. Architecture contains one process
--! which is sensitive to the reset signal and clock signal. Inside the process
--! the decoded adress is used to read/write from the register file when the
--! av_read_i/av_write_i flags are asserted. These operations are synchronous to the
--! clk_i clock signal. First three registers are write-only, while the rest are
--! both read and write compatible. The av_waitrequest_o is asserted for every idle
--! clock cycle (both av_read_i/av_write_i are deasserted) and it deasserts for
--! one clock cycle when read/write operation is executed.

architecture arch of register_file is
  type reg_file_t is array(0 to 6) of std_logic_vector(31 downto 0);
  signal reg_file : reg_file_t := (others => (others => '0'));

  signal address_index : integer := 0;
  signal rst : std_logic := '0';
begin
  -- Main process for asynch reset and synch actions
  process(clk_i, rst) is
  begin
    if rst = '1' then
      for i in 0 to 6 loop
        reg_file(i) <= (others => '0');
      end loop;
    elsif rising_edge(clk_i) then
      if av_write_i = '1' and address_index < 7 then
        reg_file(address_index) <= av_writedata_i;
        av_waitrequest_o <= '0';
      elsif av_read_i = '1' and address_index < 3 then
        av_readdata_o <= reg_file(address_index);
        av_waitrequest_o <= '0';
      else
        av_waitrequest_o <= '1';
      end if;
    end if;
  end process;

  address_index <= to_integer(unsigned(av_address_i))/4;
  rst <= reg_file(2)(2);
end arch;
