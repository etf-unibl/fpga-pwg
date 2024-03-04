library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library design_lib;

entity atomic_access_tb is
    generic (runner_cfg : string);
end entity;

architecture arch of atomic_access_tb is
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
        variable fifo_empty_flag : std_logic := '0';
        variable ts_fall_err : std_logic := '0';
        variable ts_rise_err : std_logic := '0';
	begin
		test_runner_setup(runner, runner_cfg);
		set_stop_level(failure);
		show(get_logger(default_checker), display_handler, pass);
		
		rst <= '1';
		wait for T/2;
		rst <= '0';
		
		-- Set current UNIX time
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(0, address'length)), std_logic_vector(to_unsigned(1520, address'length)));
		wait_until_idle(net, avmm_bus);

        -- Write to the MSB part of the fall register pair
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(3, address'length)), std_logic_vector(to_unsigned(1520, address'length)));
		wait_until_idle(net, avmm_bus);
        -- Break the write chain with non atomic write request
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(0, address'length)), std_logic_vector(to_unsigned(0, address'length)));
		wait_until_idle(net, avmm_bus);
        -- Try to finish the timestamp write request
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(4, address'length)), std_logic_vector(to_unsigned(1337, address'length)));
		wait_until_idle(net, avmm_bus);

        wait for T;

        read_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), readdata_temp);
        wait_until_idle(net, avmm_bus);

        fifo_empty_flag := readdata_temp(1);
        ts_fall_err := readdata_temp(3);

        check(ts_fall_err = '1', "Checking if ERROR flag is set after failing atomic transaction to the fall TS");
        check(fifo_empty_flag = '1', "Checking if nothing was written in FIFO after failing atomic transaction to fall TS");

        -- Clear status register
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), std_logic_vector(to_unsigned(0, address'length)));
		wait_until_idle(net, avmm_bus);

        readdata_temp := (others => '0');
        fifo_empty_flag := '0';
        ts_rise_err := '0';
        ts_fall_err := '0';

        -- Write to the MSB part of the rise register pair
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(5, address'length)), std_logic_vector(to_unsigned(1520, address'length)));
		wait_until_idle(net, avmm_bus);
        -- Break the write chain with non atomic write request
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(0, address'length)), std_logic_vector(to_unsigned(0, address'length)));
		wait_until_idle(net, avmm_bus);
        -- Try to finish the timestamp write request
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(6, address'length)), std_logic_vector(to_unsigned(1337, address'length)));
		wait_until_idle(net, avmm_bus);

        wait for T;

        read_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), readdata_temp);
        wait_until_idle(net, avmm_bus);

        fifo_empty_flag := readdata_temp(1);
        ts_rise_err := readdata_temp(4);

        check(ts_rise_err = '1', "Checking if ERROR flag is set after failing atomic transaction to the rise TS");
        check(fifo_empty_flag = '1', "Checking if nothing was written in FIFO after failing atomic transaction to the rise TS");

        -- Clear status register
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), std_logic_vector(to_unsigned(0, address'length)));
		wait_until_idle(net, avmm_bus);

        readdata_temp := (others => '0');
        fifo_empty_flag := '0';
        ts_rise_err := '0';
        ts_fall_err := '0';

        -- Generate some regular timestamp inputs to the FIFO
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(3, address'length)), std_logic_vector(to_unsigned(1520, address'length)));
		wait_until_idle(net, avmm_bus);
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(4, address'length)), std_logic_vector(to_unsigned(1520, address'length)));
		wait_until_idle(net, avmm_bus);
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(5, address'length)), std_logic_vector(to_unsigned(1520, address'length)));
		wait_until_idle(net, avmm_bus);
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(6, address'length)), std_logic_vector(to_unsigned(1520, address'length)));
		wait_until_idle(net, avmm_bus);

		-- Clear status register
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), std_logic_vector(to_unsigned(0, address'length)));
		wait_until_idle(net, avmm_bus);

		wait for T;

        read_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), readdata_temp);
        wait_until_idle(net, avmm_bus);

        fifo_empty_flag := readdata_temp(1);
        check(fifo_empty_flag = '0', "Checking if FIFO is not empty after correct atomic transactions");

        -- Try to initiate transaction with LSB reg. pair first
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(4, address'length)), std_logic_vector(to_unsigned(1520, address'length)));
		wait_until_idle(net, avmm_bus);

        wait for T;

        read_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), readdata_temp);
        wait_until_idle(net, avmm_bus);

        ts_fall_err := readdata_temp(3);
        check(ts_fall_err = '1', "Checking if ERROR flag is set after failing atomic transaction to the fall TS");

        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(6, address'length)), std_logic_vector(to_unsigned(1520, address'length)));
		wait_until_idle(net, avmm_bus);

        wait for T;

        read_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), readdata_temp);
        wait_until_idle(net, avmm_bus);
        
        ts_rise_err := readdata_temp(4);
        check(ts_rise_err = '1', "Checking if ERROR flag is set after failing atomic transaction to the rise TS");

		test_runner_cleanup(runner);
		wait;
	end process;

	test_runner_watchdog(runner, 5 us);
end arch;