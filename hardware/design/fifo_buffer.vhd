-----------------------------------------------------------------------------
-- Faculty of Electrical Engineering
-- PDS 2024
-- https://github.com/etf-unibl/fpga-pwg
-----------------------------------------------------------------------------
--
-- unit name:     FIFO BUFFER
--
-- description:
--
--   This file implements FIFO buffer with configurable depth.
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
--! @file fifo_buffer.vhd
--! @brief FIFO buffer with configurable depth
-------------------------------------------------------

--! Use standard library
library ieee;
--! Use logic elements
use ieee.std_logic_1164.all;
--! Use numeric types and conversion functions
use ieee.numeric_std.all;

--! @brief FIFO buffer desing used to store user defined timestamps and values
--! @details Entity is responsible for storing used defined timestamps and values.
--! Desing offers synchronous first in first out mechanism for data storage and output.
--! It uses two enable signals, one for reading, one for writing, to indicate the operation
--! which is to be executed on the next rising edge of clock signal. Data that is stored
--! consists of 96-bit long vectors with the following format:
--! [95:64] bits - unix time timestamp,
--! [63:32] bits - nanosecond time timestamp,
--! [31:0] bits - output value for specific timestamp.
--! Buffer depth is configurable and it is a generic parameter of the entity.
--! The entity has the following ports:
--! `clk_i` is the clock input, used to synchronize the circuit,
--! `rst_i` is the reset input, which resets the data registers and internal counters,
--! `write_en_i` is the enable signal for write operation,
--! `read_en_i` is the enable signal for read operation,
--! `write_data_i` is the vector that holds data which will be inserted into
--! buffer on the next rising edge when write_en_i is asserted,
--! `read_data_o` is the vector containing data that is next for reading
--! accordingly to FIFO mechanism,
--! `buf_full_o` is the status output signal indicating that buffer is full,
--! `buf_empty_o` is the status output signal indicating that buffer is empty.

entity fifo_buffer is
  generic(
    g_DEPTH : natural := 32 --! FIFO buffer depth parameter
  );
  port(
    clk_i        : in  std_logic; --! Clock signal input
    rst_i        : in  std_logic; --! Asynchronous reset signal input
    write_en_i   : in  std_logic; --! Write enable signal input
    read_en_i    : in  std_logic; --! Read enable signal input
    write_data_i : in  std_logic_vector(95 downto 0); --! Input data vector
    read_data_o  : out std_logic_vector(95 downto 0); --! Output data vector
    buf_full_o   : out std_logic; --! Status output indicating a full buffer
    buf_empty_o  : out std_logic --! Status output indicating an empty buffer
  );
end fifo_buffer;

--! @brief Architecture definition of the FIFO buffer
--! @details Architecture implemented using array of vectors as a register memory
--! to place the buffer data. In order to find correct places for writing and reading
--! accordingly to FIFO mechanism two counters are used, fifo_write_idx and fifo_read_idx.
--! Another counter, fifo_count, is used to calculate number of vectors inside the buffer,
--! so it can set buffer empty and buffer full status outputs. It increments synchronously
--! with clock signal when write_en_i is set, and decrements the same way if read_en_i is set.
--! Write and read index counters increment in sync with clock, accorindly to the status of
--! corresponding enable signals. Data is written in buffer registers synchronously with clock
--! by copying write_data_i content to array location indexed by fifo_write_idx counter
--! when the write_en_i signal is set.
--! Output data is always set by copying data from register memory array which is indexed by
--! fifo_read_idx counter to the read_data_o output vector. Status outputs are set using
--! the value of fifo_count counter.

architecture arch of fifo_buffer is
  type t_fifo_data is array(0 to g_DEPTH - 1) of std_logic_vector(95 downto 0);
  signal fifo_data : t_fifo_data := (others => (others => '0'));

  signal fifo_count     : integer range 0 to g_DEPTH     := 0;
  signal fifo_write_idx : integer range 0 to g_DEPTH - 1 := 0;
  signal fifo_read_idx  : integer range 0 to g_DEPTH - 1 := 0;

  signal fifo_full  : std_logic;
  signal fifo_empty : std_logic;
begin
  -- Main process for asynch reset, synch updates of fifo index counters and synch data input
  process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      fifo_count     <= 0;
      fifo_write_idx <= 0;
      fifo_read_idx  <= 0;
      for i in 0 to g_DEPTH - 1 loop
        fifo_data(i) <= (others => '0');
      end loop;
    elsif rising_edge(clk_i) then
      -- Keep track of total number of data in the buffer
      if write_en_i = '1' and read_en_i = '0' then
        fifo_count <= fifo_count + 1;
      elsif write_en_i = '0' and read_en_i = '1' then
        fifo_count <= fifo_count - 1;
      end if;
      -- Keep track of write index and control wrapping
      if write_en_i = '1' and fifo_full = '0' then
        if fifo_write_idx = g_DEPTH - 1 then
          fifo_write_idx <= 0;
        else
          fifo_write_idx <= fifo_write_idx + 1;
        end if;
      end if;
      -- Keep track of read index and control wrapping
      if read_en_i = '1' and fifo_empty = '0' then
        if fifo_read_idx = g_DEPTH - 1 then
          fifo_read_idx <= 0;
        else
          fifo_read_idx <= fifo_read_idx + 1;
        end if;
      end if;
      -- Add new data if write enable is set
      if write_en_i = '1' then
        fifo_data(fifo_write_idx) <= write_data_i;
      end if;
    end if;
  end process;

  fifo_full  <= '1' when fifo_count = g_DEPTH else '0';
  fifo_empty <= '1' when fifo_count = 0       else '0';

  read_data_o <= fifo_data(fifo_read_idx);
  buf_full_o  <= fifo_full;
  buf_empty_o <= fifo_empty;
end arch;
