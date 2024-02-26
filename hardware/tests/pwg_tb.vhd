library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library design_lib;

entity pwg_tb is
    generic (runner_cfg : string);
end pwg_tb;

architecture arch of pwg_tb is
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
	signal sys_output : std_logic := '0';
	signal timer : integer := -80;
	
	constant avmm_bus : bus_master_t := new_bus(
		data_length => 32,
		address_length => 32,
		logger => get_logger("avmm_bus")
	);

	constant T : time := 20 ns;

	constant UNIX_TIME : std_logic_vector(31 downto 0) := "01100101110110010010110101011011";

	type test_array_t is array(0 to 4) of std_logic_vector(31 downto 0);
    signal nano_timestamps_rise : test_array_t := (
        std_logic_vector(to_unsigned(1500, writedata'length)),
        std_logic_vector(to_unsigned(2500, writedata'length)),
        std_logic_vector(to_unsigned(3500, writedata'length)),
        std_logic_vector(to_unsigned(4500, writedata'length)),
        std_logic_vector(to_unsigned(5500, writedata'length))
    );
	signal nano_timestamps_fall : test_array_t := (
        std_logic_vector(to_unsigned(2000, writedata'length)),
        std_logic_vector(to_unsigned(3000, writedata'length)),
        std_logic_vector(to_unsigned(4000, writedata'length)),
        std_logic_vector(to_unsigned(5000, writedata'length)),
        std_logic_vector(to_unsigned(6000, writedata'length))
    );

	signal nano_timestamps_rise_2 : test_array_t := (
        std_logic_vector(to_unsigned(8000, writedata'length)),
        std_logic_vector(to_unsigned(10000, writedata'length)),
        std_logic_vector(to_unsigned(12000, writedata'length)),
        std_logic_vector(to_unsigned(14000, writedata'length)),
        std_logic_vector(to_unsigned(16000, writedata'length))
    );
	signal nano_timestamps_fall_2 : test_array_t := (
        std_logic_vector(to_unsigned(9000, writedata'length)),
        std_logic_vector(to_unsigned(11000, writedata'length)),
        std_logic_vector(to_unsigned(13000, writedata'length)),
        std_logic_vector(to_unsigned(15000, writedata'length)),
        std_logic_vector(to_unsigned(17000, writedata'length))
    );
	
begin
	dut : entity design_lib.register_file port map(
		clk_i => clk,
    	rst_i => rst,
    	av_read_i => read,
    	av_write_i => write,
    	av_address_i => address,
    	av_writedata_i => writedata,
    	av_readdata_o => readdata,
    	av_waitrequest_o => waitrequest,
		sys_output_o => sys_output
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

	timer_inc : process(clk)
	begin
		if rising_edge(clk) then
			timer <= timer + 20;
		end if;
	end process;
	
	main : process
		variable readdata_temp : std_logic_vector(31 downto 0) := (others => '0');
	begin
		test_runner_setup(runner, runner_cfg);
		set_stop_level(failure);
		show(get_logger(default_checker), display_handler, pass);
		
		rst <= '1';
		wait for T/2;
		rst <= '0';
		
		-- Set counter to the specified unix timestamp
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(0, address'length)), UNIX_TIME);
		wait_until_idle(net, avmm_bus);
		wait for T;
		check_bus(net, avmm_bus, std_logic_vector(to_unsigned(0, address'length)), UNIX_TIME, 
		"Checking if unix time was set correctly");

		-- Assert ENABLE signal
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(2, address'length)), std_logic_vector(to_unsigned(1, address'length)));
		wait_until_idle(net, avmm_bus);

		-- Write timestamps to the FIFO buffer 
		for i in 0 to 4 loop
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(5, address'length)), UNIX_TIME);
			wait_until_idle(net, avmm_bus);
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(6, address'length)), nano_timestamps_rise(i));
			wait_until_idle(net, avmm_bus);
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(3, address'length)), UNIX_TIME);
			wait_until_idle(net, avmm_bus);
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(4, address'length)), nano_timestamps_fall(i));
			wait_until_idle(net, avmm_bus);
		end loop;
		
		-- Wait for output changes and peform checks
		for i in 0 to 4 loop
			wait until sys_output = '1';
			info("System output " & integer'image(i+1) & ". rising edge");
			info("Current measured timestamp " & integer'image(timer));
			check(timer = to_integer(unsigned(nano_timestamps_rise(i))), "Checking if output changed at the correct timestamp");
			wait until sys_output = '0';
			info("System output " & integer'image(i+1) & ". falling edge");
			info("Current measured timestamp " & integer'image(timer));
			check(timer = to_integer(unsigned(nano_timestamps_fall(i))), "Checking if output changed at the correct timestamp");
		end loop;
		
		-- Delay next sequence of tests
		wait for 5*T;

		-- Write timestamps to the FIFO buffer 
		for i in 0 to 4 loop
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(5, address'length)), UNIX_TIME);
			wait_until_idle(net, avmm_bus);
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(6, address'length)), nano_timestamps_rise_2(i));
			wait_until_idle(net, avmm_bus);
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(3, address'length)), UNIX_TIME);
			wait_until_idle(net, avmm_bus);
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(4, address'length)), nano_timestamps_fall_2(i));
			wait_until_idle(net, avmm_bus);
		end loop;
		
		-- Wait for output changes and peform checks
		for i in 0 to 4 loop
			wait until sys_output = '1';
			info("System output " & integer'image(i+1) & ". rising edge - 2nd test");
			check(timer = to_integer(unsigned(nano_timestamps_rise_2(i))), "Checking if output changed at the correct timestamp");
			wait until sys_output = '0';
			info("System output " & integer'image(i+1) & ". falling edge - 2nd test");
			check(timer = to_integer(unsigned(nano_timestamps_fall_2(i))), "Checking if output changed at the correct timestamp");
		end loop;

		test_runner_cleanup(runner);
		wait;
	end process;

	test_runner_watchdog(runner, 20 us);
end arch;
