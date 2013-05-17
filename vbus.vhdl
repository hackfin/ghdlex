--! \file 
--! \brief Virtualized simple bus implementation

-- (c) 2013 Martin Strubel <hackfin@section5.ch>

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.ghpi_netpp.all; -- For virtual register I/O (regmap_read())
	use work.virtual.all;
	use work.txt_util.all;
	use std.textio.all;

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
--! \example simboard.vhdl

entity VirtualBus is
	generic (
		ADDR_W   : natural := 8;   --! Address bus width
		DATA_W   : natural := 32   --! Data bus width
	);
	port (
		clk         : in  std_logic; --! The input master clock
		wr          : out std_logic; --! Write request
		rd          : out std_logic; --! Read request
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

begin

	process
		variable ret : integer;
	begin
		bus_handle := bus_new(simulation'path_name, DATA_W);
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
		variable flags : busflag_t := "000";
		variable rx:       std_logic := '0';
		variable d_data :  unsigned(DATA_W-1 downto 0);
		variable d_addr :  unsigned(ADDR_W-1 downto 0);
	begin
		if rising_edge(clk) then
			d_data := unsigned(data_out);
			-- No RTXT when we just got a read request, because the result
			-- is one cycle delayed.
--			if flags(2) = '1' then
--				print(output, "Wback: " & hstr(d_data));
--			end if;

			dval <= flags(2);
			bus_rxtx(bus_handle, d_addr, d_data, flags);

			rd   <= flags(0);
			wr   <= flags(1);
			flags(2) := rx;

			if flags(1) = '1' then
				iaddr <= d_addr;
				data_in <= std_logic_vector(d_data);
			elsif flags(0) = '1' then
				iaddr <= d_addr;
				rx := '1';
			else
				rx := '0';
			end if;
		end if;
	end process;

	addr <= std_logic_vector(iaddr);

end simulation;

