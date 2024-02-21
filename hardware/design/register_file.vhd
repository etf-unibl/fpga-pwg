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
    rst_i            : in  std_logic; --! Asynchronous reset input
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

  signal address_index : integer   := 0;
  signal global_reset  : std_logic := '0';
  signal fifo_write_en : std_logic := '0';
  signal fifo_read_en : std_logic := '0';
  signal fifo_buf_full : std_logic := '0';
  signal fifo_buf_empty : std_logic := '0';
  signal fifo_write_data : std_logic_vector(95 downto 0) := (others => '0');
  signal fifo_read_data : std_logic_vector(95 downto 0) := (others => '0');
  signal counter_rise : integer := 0;
  signal counter_fall : integer := 0;

  component fifo_buffer is
    generic(
      g_DEPTH : natural
    );
    port(
      clk_i        : in  std_logic;
      rst_i        : in  std_logic;
      write_en_i   : in  std_logic;
      read_en_i    : in  std_logic;
      write_data_i : in  std_logic_vector(95 downto 0);
      read_data_o  : out std_logic_vector(95 downto 0);
      buf_full_o   : out std_logic;
      buf_empty_o  : out std_logic
    );
  end component;

begin
  -- Main process for asynch reset and synch actions
  process(clk_i, global_reset) is
  begin
    if global_reset = '1' then
      for i in 0 to 6 loop
        reg_file(i) <= (others => '0');
      end loop;
    elsif rising_edge(clk_i) then
      if fifo_buf_full = '1' then
        reg_file(1)(2) <= '1';
      elsif fifo_buf_empty = '1' then
        reg_file(1)(1) <= '1';
      end if;

      if av_write_i = '1' and address_index < 7 then
        reg_file(address_index) <= av_writedata_i;
        av_waitrequest_o <= '0';
        if address_index = 3 or address_index = 4 then
          counter_fall <= counter_fall + 1;
        end if;
        if address_index = 5 or address_index = 6 then
          counter_rise <= counter_rise + 1;
        end if;
      elsif av_read_i = '1' and address_index < 3 then
        av_readdata_o <= reg_file(address_index);
        av_waitrequest_o <= '0';
      else
        av_waitrequest_o <= '1';
      end if;

      if counter_fall = 2 then
        counter_fall <= 0;
        if reg_file(3) < reg_file(0) then
		  reg_file(1)(0) <= '1';
		else
		  fifo_write_data(95 downto 64) <= reg_file(3);
          fifo_write_data(63 downto 32) <= reg_file(4);
          fifo_write_data(31 downto 0)  <= (others => '0');
          fifo_write_en <= '1';
		  reg_file(1)(0) <= '0';
		 end if;
      elsif counter_rise = 2 then
        counter_rise <= 0;
		if reg_file(5) < reg_file(0) then
		  reg_file(1)(0) <= '1';
        else
		  fifo_write_data(95 downto 64) <= reg_file(5);
          fifo_write_data(63 downto 32) <= reg_file(6);
          fifo_write_data(31 downto 0)  <= (others => '1');
          fifo_write_en <= '1';
		  reg_file(1)(0) <= '0';
		 end if;
      else
        fifo_write_data <= (others => '0');
        fifo_write_en   <= '0';
      end if;
    end if;
  end process;

  address_index <= to_integer(unsigned(av_address_i));
  global_reset <= reg_file(2)(2) or rst_i;

  fifo : fifo_buffer
  generic map(
    g_DEPTH => 8
  )
  port map(
    clk_i        => clk_i,
    rst_i        => global_reset,
    write_en_i   => fifo_write_en,
    read_en_i    => fifo_read_en,
    write_data_i => fifo_write_data,
    read_data_o  => fifo_read_data,
    buf_full_o   => fifo_buf_full,
    buf_empty_o  => fifo_buf_empty
  );
end arch;
