library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library design_lib;

entity tb_top is
  generic (runner_cfg : string);
end tb_top;

architecture testbench of tb_top is
  signal clk_tb, rst_tb, set_i_tb: std_logic;
  signal user_time_i_tb: std_logic_vector(63 downto 0);
  signal counter_time_o_tb: std_logic_vector(63 downto 0);
  signal value_i_tb, time_i_tb: std_logic_vector(31 downto 0);
  signal system_o_tb: std_logic;
  type timestamp_array_t is array(0 to 4) of std_logic_vector(63 downto 0);
  signal timestamp_array : timestamp_array_t;
  type value_array_t is array(0 to 4) of std_logic_vector(31 downto 0);
  signal value_array : value_array_t;
  signal dummy : std_logic := '0';
  constant CLOCK_PERIOD : time := 20 ns;
begin
  uut_counter : entity design_lib.time_counter
    port map(
      clk_i  => clk_tb,
      rst_i  => rst_tb,
      set_i  => set_i_tb,
      time_i => time_i_tb,
      time_o => counter_time_o_tb
    );

  uut_output : entity design_lib.output_logic
    port map(
      clk_i          => clk_tb,
      rst_i          => rst_tb,
      value_i        => value_i_tb,  
      counter_time_i => counter_time_o_tb,
      user_time_i    => user_time_i_tb,
      system_o       => system_o_tb
    );
	
  vunit_gen : process
  begin
	test_runner_setup(runner, runner_cfg);
	set_stop_level(failure);
	show(get_logger(default_checker), display_handler, pass);
	wait;
  end process;

  clk_gen: process
  begin
    clk_tb <= '0';
    wait for CLOCK_PERIOD / 2;
    clk_tb <= '1';
    wait for CLOCK_PERIOD / 2;
  end process;

  rst_gen: process
  begin
    rst_tb <= '1';
    wait for CLOCK_PERIOD / 4;
    rst_tb <= '0';
    wait;
  end process;
  
  timestamp_gen : process
  begin
    timestamp_array(0) <=  std_logic_vector(to_unsigned(1707211273,time_i_tb'length)) & std_logic_vector(to_unsigned(160,time_i_tb'length));
    value_array(0) <=  (others => '1');
    timestamp_array(1) <=  std_logic_vector(to_unsigned(1707211273,time_i_tb'length)) & std_logic_vector(to_unsigned(500,time_i_tb'length));
    value_array(1) <=  (others => '0');
    timestamp_array(2) <=  std_logic_vector(to_unsigned(1707211273,time_i_tb'length)) & std_logic_vector(to_unsigned(900,time_i_tb'length));
    value_array(2) <=  (others => '1');
    timestamp_array(3) <=  std_logic_vector(to_unsigned(1707211273,time_i_tb'length)) & std_logic_vector(to_unsigned(1200,time_i_tb'length));
    value_array(3) <=  (others => '1');
    timestamp_array(4) <=  std_logic_vector(to_unsigned(1707211273,time_i_tb'length)) & std_logic_vector(to_unsigned(1560,time_i_tb'length));
    value_array(4) <=  (others => '0');
	wait;
  end process;

  set_gen: process
  begin
    set_i_tb <= '1';
    time_i_tb <= std_logic_vector(to_unsigned(1707211273,time_i_tb'length));
    wait for CLOCK_PERIOD;
    set_i_tb <= '0';
    wait;
  end process;

  stim_gen: process
    variable i: integer := 0;
  begin
    if (i /= 5) then
        wait for 5 ns;
        user_time_i_tb <= timestamp_array(i);
        value_i_tb <= value_array(i);
        i := i+1;
        wait on dummy;
    else
        test_runner_cleanup(runner);
        wait;
    end if;
  end process;

  monitor_gen: process
  begin
    wait until rising_edge(clk_tb);
    if counter_time_o_tb = user_time_i_tb then
	    wait for CLOCK_PERIOD/2;
        if value_i_tb(31) = '1' then
			check(system_o_tb = '1', "Checking that logic HIGH is generated at the specified timestamp");
        else
			check(system_o_tb = '0', "Checking that logic LOW is generated at the specified timestamp");
		end if;
    dummy <= not dummy;
	end if;
  end process;

end testbench;