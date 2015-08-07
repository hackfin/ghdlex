--! \file simboard.vhdl   Virtual board example
-- A little more complex configuration
--
-- Test for various virtual entities

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all; -- Unsigned

library ghdlex;
	use ghdlex.ghpi_netpp.all;
	use ghdlex.virtual.all;
	use ghdlex.ghdlsim.all;
	use ghdlex.txt_util.all;

use std.textio.all;

entity simboard is
end simboard;

architecture simulation of simboard is
	constant FIFO_WORDWIDTH : natural := 1;
	signal clk: std_logic := '0';
	signal we: std_logic := '0';
	constant ADDR_W : natural := 12;
	signal addr: unsigned(ADDR_W-1 downto 0) := (others => '0');
	signal data0: unsigned(31 downto 0);
	signal data1: unsigned(15 downto 0);
	signal data2: unsigned(15 downto 0);

	-- Global, netpp 'property exported' bus:
	signal vbus_wr   : std_logic;
	signal vbus_rd   : std_logic;
	signal vbus_din  : std_logic_vector(31 downto 0) := (others => '0');
	signal vbus_dout : std_logic_vector(31 downto 0) := (others => '0');
	signal vbus_addr : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');

	-- Virtual local bus, without netpp device read/write access:
	signal lbus_wr   : std_logic;
	signal lbus_rd   : std_logic;
	signal lbus_din  : std_logic_vector(31 downto 0) := (others => '0');
	signal lbus_dout : std_logic_vector(31 downto 0) := (others => '0');
	signal lbus_addr : std_logic_vector(ADDR_W-1 downto 0)
		:= (others => '0');


	signal tap_ce    : std_logic;
	signal tap_ctrl  : tap_registers_WritePort;
	signal tap_stat  : tap_registers_ReadPort;

	signal lbus_ce    : std_logic;
	signal lbus_ctrl  : fpga_registers_WritePort;
	signal lbus_stat  : fpga_registers_ReadPort;



	constant NFIFOS  : natural := 2;
 
	type byte_bus_t is array (0 to NFIFOS-1) of
		std_logic_vector(FIFO_WORDWIDTH*8-1 downto 0);

	signal fifo_canwrite   : std_logic;
	signal fifo_wready     : std_logic_vector(0 to NFIFOS-1);
	signal fifo_rready     : std_logic_vector(0 to NFIFOS-1);
	signal fifo_we         : std_logic_vector(0 to NFIFOS-1);
	signal fifo_re         : std_logic_vector(0 to NFIFOS-1);
	-- Note: Arrays of that kind are not yet supported by the wrapper
	signal fifo_din        : byte_bus_t;
	signal fifo_dout       : byte_bus_t;
begin

clkgen:
	process
		variable err : integer;
	begin
		clkloop : loop
			wait for 10 us;
			clk <= not clk;
			-- if sigterm = '1' then
				-- exit;
			-- end if;
		end loop clkloop;
		print(output, " -- TERMINATED --");

	end process;

ram0:
	DualPort16 generic map (ADDR_W => ADDR_W)
	   port map (
			clk     => clk,
			-- Port A
			a_we    => we,
			a_addr  => addr,
			a_write => data0(15 downto 0),
			a_read  => data1,
			-- Port B
			b_we    => '0',
			b_addr  => addr,
			b_write => data0(15 downto 0),
			b_read  => open
	   );

ram1:
	DualPort16 generic map (ADDR_W => ADDR_W)
	   port map (
			clk     => clk,
			-- Port A
			a_we    => we,
			a_addr  => addr,
			a_write => data0(31 downto 16),
			a_read  => data2,
			-- Port B
			b_we    => '0',
			b_addr  => addr,
			b_write => data0(31 downto 16),
			b_read  => open
	   );

	-- Create a FIFO loopback:

nfifo:
	for i in 0 to 1 generate
fifo: VirtualFIFO
	generic map (WORDSIZE => FIFO_WORDWIDTH)
	port map (
		clk         => clk,
		throttle    => global_throttle,
		wr_ready    => fifo_wready(i),
		rd_ready    => fifo_rready(i),
		wr_enable   => fifo_we(i),
		rd_enable   => fifo_re(i),
		data_in     => fifo_dout(i),
		data_out    => fifo_din(i)
	);
	end generate;

	-- Feed out data to input:

	fifo_din(0) <= fifo_dout(0);

	-- Delayed process, because full flag signals on (FULL-1) pointer
	-- condition:
loopback:
	process (clk)
	begin
		if rising_edge(clk) then
			fifo_re(0) <= fifo_rready(0); -- Read when data ready
			fifo_canwrite <= fifo_wready(0);
			fifo_we(0) <= fifo_rready(0) and fifo_canwrite;
		end if;
	end process;

-- Disabled, we play with the procedural generation above.

-- fifo_single: VirtualFIFO
-- 	generic map (WORDSIZE => 1)
-- 	port map (
-- 		clk         => clk,
-- 		throttle    => global_throttle,
-- 		wr_ready    => fifo_wready(2),
-- 		rd_ready    => fifo_rready(2),
-- 		wr_enable   => fifo_we(2),
-- 		rd_enable   => fifo_re(2),
-- 		data_in     => fifo_dout(2),
-- 		data_out    => fifo_din(2)
-- 	);

	-- Instancing the global bus that is accessible by netpp properties
	-- device_read() and device_write()
netpp_vbus:
	VirtualBus
	generic map ( ADDR_W => ADDR_W, BUSTYPE => BUS_GLOBAL )
	port map (
		clk         => clk,
		wr          => vbus_wr,
		rd          => vbus_rd,
		wr_busy     => '0',
		rd_busy     => '0',
		addr        => vbus_addr,
		data_in     => vbus_din,
		data_out    => vbus_dout
	);

	tap_ce <= vbus_wr or vbus_rd;

	tap_stat.tap_idcode <= x"deadbeef";

	global_throttle <= tap_ctrl.sim_throttle;

	-- Local bus: This one does is local, i.e. the netpp device layer
	-- only allows direct raw access (not through properties)
virtual_local_bus:
	VirtualBus
	generic map ( ADDR_W => ADDR_W, BUSTYPE => BUS_LOCAL, NETPP_NAME => "localbus" )
	port map (
		clk         => clk,
		wr          => lbus_wr,
		rd          => lbus_rd,
		wr_busy     => '0',
		rd_busy     => '0',
		addr        => lbus_addr,
		data_in     => lbus_din,
		data_out    => lbus_dout
	);

	lbus_ce <= lbus_wr or lbus_rd;

	lbus_stat.magicid <= x"baadf00d";
	lbus_stat.magic2 <= x"facebead";
	lbus_stat.fwrev_maj <= std_logic_vector(to_unsigned(HWREV_ghdlsim_MAJOR, 4));
	lbus_stat.fwrev_min <= std_logic_vector(to_unsigned(HWREV_ghdlsim_MINOR, 4));

local_decoder:
	decode_fpga_registers
	port map (
		ce        => lbus_ce,
		
		ctrl      => lbus_ctrl,
		stat      => lbus_stat,
		data_in   => lbus_din,
		data_out  => lbus_dout,
		addr      => lbus_addr(BV_MMR_CFG_fpga_registers),
		we        => lbus_wr,
		re        => lbus_rd,
		clk       => clk
	);


reg_decode:
	decode_tap_registers
	port map (
		clk      => clk,
		ce       => tap_ce,
		ctrl     => tap_ctrl,
		stat     => tap_stat,
		data_in  => vbus_din,
		data_out => vbus_dout,
		addr     => vbus_addr(BV_MMR_CFG_tap_registers),
		re       => vbus_rd,
		we       => vbus_wr
	);

stim:
	process
		variable retval : integer;
	begin
		-- Explicitely initialize netpp, thus not needing --vpi=netpp.vpi:
		retval := netpp_init("VirtualBoard");
		we <= '0';
		data0 <= x"deadbeef";
		addr <= "000000000001";
		wait for 40 us;
		we <= '1';
		wait for 20 us;
		we <= '0';
		wait for 20 us;

		data0 <= x"f00dface";
		addr <= "000000000010";
		wait;
	end process;

end simulation;
