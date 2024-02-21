library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library design_lib;

entity reg_fifo_tb is
    generic (runner_cfg : string);
end reg_fifo_tb;

architecture arch of reg_fifo_tb is
	signal clk : std_logic := '0';
	signal rst : std_logic := '0';
	signal read : std_logic := '0';
	signal write : std_logic := '0';
	signal waitrequest : std_logic := '0';
	signal address : std_logic_vector(31 downto 0) := (others => '0');
	signal readdata : std_logic_vector(31 downto 0) := (others => '0');
	signal writedata : std_logic_vector(31 downto 0) := (others => '0');
	signal byteenable : std_logic_vector(3 downto 0) := (others => '0');
	signal readdatavalid : std_logic;
	signal burstcount : std_logic_vector(1 downto 0) := (others => '0');
	
	constant avmm_bus : bus_master_t := new_bus(
		data_length => 32,
		address_length => 32,
		logger => get_logger("avmm_bus")
	);

	constant T : time := 20 ns;
	
begin
	dut : entity design_lib.register_file port map(
		clk_i => clk,
    	rst_i => rst,
    	av_read_i => read,
    	av_write_i => write,
    	av_address_i => address,
    	av_writedata_i => writedata,
    	av_readdata_o => readdata,
    	av_waitrequest_o => waitrequest
	);

	avmm_master : entity vunit_lib.avalon_master
	generic map(
		bus_handle => avmm_bus,
		use_readdatavalid => false
	)
	port map(
		clk => clk,
    	address => address, 
    	byteenable => byteenable,
    	burstcount => burstcount,
    	waitrequest => waitrequest,
    	write => write,  
    	writedata => writedata,
    	read => read,  
    	readdata => readdata,      
    	readdatavalid => readdatavalid
	);

	clk_gen : process
	begin
		clk <= '0';
		wait for T/2;
		clk <= '1';
		wait for T/2;
	end process;

	main : process
		variable readdata_temp : std_logic_vector(31 downto 0) := (others => '0');
	begin
		test_runner_setup(runner, runner_cfg);
		set_stop_level(failure);
		show(get_logger(default_checker), display_handler, pass);

		info("Test start...");

		rst <= '1';
		wait for T/4;
		rst <= '0';

		check_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), std_logic_vector(to_unsigned(2, readdata'length)), 
		"Checking if FIFO buffer empty flag is set before transactions");

		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(0, address'length)), std_logic_vector(to_unsigned(1000, writedata'length)));
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(5, address'length)), std_logic_vector(to_unsigned(1500, writedata'length)));
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(6, address'length)), std_logic_vector(to_unsigned(30000, writedata'length)));
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(3, address'length)), std_logic_vector(to_unsigned(1500, writedata'length)));
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(4, address'length)), std_logic_vector(to_unsigned(50000, writedata'length)));

		--Clear status register
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), std_logic_vector(to_unsigned(0, writedata'length)));

		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(3, address'length)), std_logic_vector(to_unsigned(150, writedata'length)));
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(4, address'length)), std_logic_vector(to_unsigned(150, writedata'length)));

		wait_until_idle(net, avmm_bus);
		wait for T;

		check_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), std_logic_vector(to_unsigned(1, readdata'length)), 
		"Checking if SYS_ERR flag is set after bad transaction");

		for i in 0 to 2 loop
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(5, address'length)), std_logic_vector(to_unsigned(1500, writedata'length)));
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(6, address'length)), std_logic_vector(to_unsigned((i+1)*60000, writedata'length)));
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(3, address'length)), std_logic_vector(to_unsigned(1500, writedata'length)));
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(4, address'length)), std_logic_vector(to_unsigned((i+1)*80000, writedata'length)));
		end loop;
		
		wait_until_idle(net, avmm_bus);
		wait for 2*T;

		check_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), std_logic_vector(to_unsigned(4, readdata'length)), 
		"Checking if FIFO buffer full flag is set after transactions");
		
		-- Clear control and status registers
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), std_logic_vector(to_unsigned(0, writedata'length)));
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(2, address'length)), std_logic_vector(to_unsigned(0, writedata'length)));
	
		test_runner_cleanup(runner);
		wait;
	end process;

	test_runner_watchdog(runner, 1 us);
end arch;