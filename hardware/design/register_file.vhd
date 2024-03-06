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
--! This entity also represents a top-level entity for the whole design.
--! It has one additional port which represents the systems final output.

entity register_file is
  port(
    clk_i            : in  std_logic; --! Clock signal input
    rst_i            : in  std_logic; --! Asynchronous reset input
    av_read_i        : in  std_logic; --! Avalon-MM read indicator
    av_write_i       : in  std_logic; --! Avalon-MM write indicator
    av_address_i     : in  std_logic_vector(31 downto 0); --! Avalon-MM address signal
    av_writedata_i   : in  std_logic_vector(31 downto 0); --! Avalon-MM data input
    av_readdata_o    : out std_logic_vector(31 downto 0); --! Avalon-MM data output
    av_waitrequest_o : out std_logic; --! Avalon-MM wait-state signal for response control
    av_response_o    : out std_logic_vector(1 downto 0); --! Avalon-MM response output
    sys_output_o     : out std_logic; --! System output port
    interrupt_o      : out std_logic  --! Interrupt output port
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
--! one clock cycle when read/write operation is executed. Besides avalon-mm
--! slave and register file implementation, the architecture also interconnects
--! all of the components to create the whole design. It implements FIFO buffer
--! data exchange, from avalon master to FIFO and from FIFO to the output logic
--! comparator. It also initializes counter and connects it to the output logic
--! comparator. Finally, it connects output from output logic components to the
--! system output.

architecture arch of register_file is
  type reg_file_t is array(0 to 6) of std_logic_vector(31 downto 0);
  signal reg_file : reg_file_t := (others => (others => '0'));

  -- Internal arch signals
  signal global_reset    : std_logic := '0';
  signal counter_rise    : integer   :=  0;
  signal counter_fall    : integer   :=  0;
  signal address_index   : integer   :=  0;

  -- FIFO buffer connection signals
  signal fifo_write_en   : std_logic := '0';
  signal fifo_read_en    : std_logic := '0';
  signal fifo_buf_full   : std_logic := '0';
  signal fifo_buf_empty  : std_logic := '0';
  signal fifo_write_data : std_logic_vector(95 downto 0) := (others => '0');
  signal fifo_read_data  : std_logic_vector(95 downto 0) := (others => '0');

  -- Time counter connection signals
  signal timer_set      : std_logic := '0';
  signal timer_set_time : std_logic_vector(31 downto 0) := (others => '0');
  signal timer_output   : std_logic_vector(63 downto 0) := (others => '0');

  -- Output logic connection signals
  signal out_log_value       : std_logic_vector(31 downto 0) := (others => '0');
  signal out_log_user_time   : std_logic_vector(63 downto 0) := (others => '0');
  signal out_log_output      : std_logic := '0';
  signal out_log_comparator  : std_logic := '0';

  -- Interrupt signals
  signal interrupt_buffer_empty      : std_logic := '0';
  signal interrupt_buffer_full       : std_logic := '0';
  signal interrupt_system_time_error : std_logic := '0';
  signal interrupt_timestamp_1       : std_logic := '0';
  signal interrupt_timestamp_2       : std_logic := '0';
  signal interrupt_enable            : std_logic := '0';
  signal interrupt                   : std_logic := '0';

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

  component time_counter is
    port(
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      set_i  : in  std_logic;
      time_i : in  std_logic_vector(31 downto 0);
      time_o : out std_logic_vector(63 downto 0)
    );
  end component;

  component output_logic is
    port(
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;
      value_i        : in  std_logic_vector(31 downto 0);
      counter_time_i : in  std_logic_vector(63 downto 0);
      user_time_i    : in  std_logic_vector(63 downto 0);
      system_o       : out std_logic;
      comparator_o   : out std_logic
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

      -- FIFO flags assertion part
      if fifo_buf_full = '1' then
        reg_file(1)(2) <= '1';
      elsif fifo_buf_empty = '1' then
        reg_file(1)(1) <= '1';
      end if;

      -- Avalon-MM write operaion
      if av_write_i = '1' then
        av_waitrequest_o <= '0';
        if address_index < 7 then
          av_response_o <= "00";
          if(counter_fall = 2 and address_index /= 4) or
          (counter_fall = 0 and address_index = 4) then
            reg_file(1)(3) <= '1';
            counter_fall <= 0;
          elsif (counter_rise = 2 and address_index /= 6) or
          (counter_rise = 0 and address_index = 6) then
            reg_file(1)(4) <= '1';
            counter_rise <= 0;
          else
            reg_file(address_index) <= av_writedata_i;
            if address_index = 3 or address_index = 4 then
              counter_fall <= counter_fall + 1;
            end if;
            if address_index = 5 or address_index = 6 then
              counter_rise <= counter_rise + 1;
            end if;
            if address_index = 0 then
              timer_set_time <= av_writedata_i;
              timer_set <= '1';
            else
              timer_set_time <= (others => '0');
              timer_set <= '0';
            end if;
          end if;
        else
          av_response_o <= "11";
        end if;

      -- Avalon-MM read operation
      elsif av_read_i = '1' then
        av_waitrequest_o <= '0';
        if address_index < 3 then
          av_response_o <= "00";
          if address_index = 0 then
            av_readdata_o <= timer_output(63 downto 32);
          else
            av_readdata_o <= reg_file(address_index);
          end if;
        else
          av_response_o <= "11";
        end if;

      else
        av_waitrequest_o <= '1';
        timer_set_time <= (others => '0');
        timer_set <= '0';
      end if;

      -- Send data to FIFO buffer when both registers are ready
      if counter_fall = 4 then
        counter_fall <= 0;
        if (reg_file(3) & reg_file(4)) < timer_output then
          reg_file(1)(0) <= '1';
        else
          fifo_write_data(95 downto 64) <= reg_file(3);
          fifo_write_data(63 downto 32) <= reg_file(4);
          fifo_write_data(31 downto 0)  <= (others => '0');
          fifo_write_en <= '1';
        end if;
      elsif counter_rise = 4 then
        counter_rise <= 0;
        if (reg_file(5) & reg_file(6)) < timer_output then
          reg_file(1)(0) <= '1';
        else
          fifo_write_data(95 downto 64) <= reg_file(5);
          fifo_write_data(63 downto 32) <= reg_file(6);
          fifo_write_data(31 downto 0)  <= (others => '1');
          fifo_write_en <= '1';
        end if;
      else
        fifo_write_data <= (others => '0');
        fifo_write_en   <= '0';
      end if;

      if out_log_comparator = '1' and fifo_buf_empty = '0' then
        fifo_read_en <= '1';
      else
        fifo_read_en <= '0';
      end if;

    end if;
  end process;

  interrupt_enable            <= reg_file(2)(1);
  interrupt_system_time_error <= reg_file(1)(0);
  interrupt_buffer_empty      <= reg_file(1)(1);
  interrupt_buffer_full       <= reg_file(1)(2);
  interrupt_timestamp_1       <= reg_file(1)(3);
  interrupt_timestamp_2       <= reg_file(1)(4);

  -- Interrupt_process
  process(interrupt_enable, interrupt_buffer_full, interrupt_buffer_empty,
          interrupt_system_time_error, interrupt_timestamp_1, interrupt_timestamp_2)
  begin
    interrupt <= interrupt_enable and (interrupt_buffer_full  or interrupt_buffer_empty  or
    interrupt_system_time_error  or interrupt_timestamp_1  or interrupt_timestamp_2);
  end process;

  address_index <= to_integer(unsigned(av_address_i));
  global_reset <= reg_file(2)(2) or rst_i;

  -- Set output logic component signals
  out_log_value     <= fifo_read_data(31 downto 0);
  out_log_user_time <= fifo_read_data(95 downto 32);

  -- Output logic
  sys_output_o <= out_log_output and reg_file(2)(0);
  interrupt_o <= interrupt;

  fifo : fifo_buffer
  generic map(
    g_DEPTH => 16
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

  timer : time_counter
  port map(
    clk_i  => clk_i,
    rst_i  => global_reset,
    set_i  => timer_set,
    time_i => timer_set_time,
    time_o => timer_output
  );

  out_log : output_logic
  port map(
    clk_i          => clk_i,
    rst_i          => global_reset,
    value_i        => out_log_value,
    counter_time_i => timer_output,
    user_time_i    => out_log_user_time,
    system_o       => out_log_output,
    comparator_o   => out_log_comparator
  );
end arch;
