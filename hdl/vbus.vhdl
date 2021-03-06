--! \file vbus.vhdl Virtual Bus implementation

-- (c) 2013 Martin Strubel <hackfin@section5.ch>

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.ghpi_netpp.all; -- For virtual register I/O (regmap_read())
	use work.virtual.all;
	use work.txt_util.all;
	use std.textio.all;


--! \brief Virtualized simple bus implementation
--!
--! The VirtualBus component implements a very simple read/write bus
--! slave protocol for testing a (slave) interface from outside software.
--! 
--! The I/O modes of this bus are either a READ or WRITE cycle.
--! When writing, it is assumed that the data is accepted immediately
--! when the 'wr' pin is asserted.
--! In the READ case, there are delays to be dealt with. On a read request,
--! the address asserted is valid and the data is expected to arrive one
--! cycle later. Therefore, the remote caller has to wait for the data.
--! This is achieved internally by a few FULL and READY flags.
--! The netpp client typically addresses the virtual bus within its
--! device_read() and device_write() functions.
--! In the default case of this library, the device_ functions handle two
--! address spaces: All addresses above #VBUS_ADDR_OFFSET access the
--! VirtualBus, the ones below access the legacy emulated register map.
--!
--! Note that only accesses through the VirtualBus are guarded and handshaked,
--! that means, legacy accesses are timing critical and the simulation
--! does not feed back to the caller if a specific register update was
--! noticed.

entity VirtualBus is
	generic (
		--! Name, as visible from netpp. If 'DEFAULT', the instanciation
		--! uses a generated name from the hierarchy.
		NETPP_NAME   : string  := "DEFAULT";
		ADDR_W       : natural := 8;   --! Address bus width
		DATA_W       : natural := 32;  --! Data bus width
		BUSTYPE      : natural := 1    --! 1 when global netpp bus
	);
	port (
		clk         : in  std_logic; --! The input master clock
		wr          : out std_logic; --! Write request
		rd          : out std_logic; --! Read request
		wr_busy     : in  std_logic; --! '1' when busy writing
		rd_busy     : in  std_logic; --! '1' when busy reading
		--! The address bus
		addr        : out std_logic_vector(ADDR_W-1 downto 0);
		--! Data input
		data_in     : out std_logic_vector(DATA_W-1 downto 0);
		--! Data output
		data_out    : in  std_logic_vector(DATA_W-1 downto 0)
	);
end entity VirtualBus;

architecture simulation of VirtualBus is
	shared variable bus_handle : bus_t;
	signal dval     :  std_logic := '0';
	signal iaddr    :  unsigned(ADDR_W-1 downto 0);

	signal ird      :  std_logic := '0';
	signal iwr      :  std_logic := '0';

begin

	process
		variable ret : integer;
	begin
		if NETPP_NAME = "DEFAULT" then
			bus_handle := bus_new(simulation'path_name, DATA_W, BUSTYPE);
		else
			bus_handle := bus_new(NETPP_NAME, DATA_W, BUSTYPE);
		end if;
		if bus_handle = null then
			assert false report "Failed to register VirtualBus";
		end if;
		wait_loop : loop
		  wait for 10 us;
		end loop wait_loop;
		bus_del(bus_handle);
		wait;

	end process;

bus_handler:
	process(clk)
		-- Flag assignment:
		-- 0: Read request
		-- 1: Write request
		-- 2: in: Data valid, out: Data ready
		variable flags : busflag_t := "000";
		variable d_data :  unsigned(DATA_W-1 downto 0);
		variable d_addr :  unsigned(ADDR_W-1 downto 0);
	begin
		if rising_edge(clk) then
			d_data := unsigned(data_out);
			-- No RXTX when we just got a read request, because the result
			-- is one cycle delayed.
--			if flags(2) = '1' then
--				print(output, "Wback: " & hstr(d_data));
--			end if;

			if wr_busy = '0' then
				bus_rxtx(bus_handle, d_addr, d_data, flags);
				ird   <= flags(0);
				iwr   <= flags(1);
			else
				ird   <= '0';
				iwr   <= '0';
			end if;

			flags(2) := dval;
			iaddr <= d_addr;

			if flags(1) = '1' then -- Writing, latch data
				data_in <= std_logic_vector(d_data);
			end if;
		end if;
	end process;

	rd <= ird; wr <= iwr;
	addr <= std_logic_vector(iaddr);
	-- DVAL only used for reading:
	dval <= (not rd_busy) and (ird);
end simulation;

