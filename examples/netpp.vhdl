--
-- Simulator <-> netpp server communication example
-- (c) 2011 Martin Strubel <hackfin@section5.ch>
--
-- Sets the control register on a netpp remote device to a value.
--
-- Usage: start devices/example/slave from the netpp distribution, then
-- run ./simnetpp to communicate with it.

-- TODO: Turn this into a little virtual GUI driven FPGA board :-)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- Unsigned

library ghdlex;
--! Use the ghpi_netpp package
	use ghdlex.ghpi_netpp.all;
	use ghdlex.txt_util.all;

use std.textio.all;

entity simnetpp is
	generic (
		ServerPort : string := "TCP:localhost:2008"
	);
end simnetpp;

architecture behaviour of simnetpp is

	signal clk : std_ulogic := '0';
	signal count : unsigned(15 downto 0) := x"0000";
	signal data : unsigned(7 downto 0);
	signal sigterm : std_logic := '0';

	shared variable device : netpphandle_t;
	shared variable t_int : token_t;

begin

	process
	begin
		-- Open device. When failing to connect, function will bail out.
		device := device_open(ServerPort);
		print(output, "Got device handle: " & str(device));
		-- Obtain TOKEN for 'ControlReg' property
		t_int := device_gettoken(device, "ControlReg");
		clkloop : loop
			wait for 1 us;
			clk <= not clk;
			if sigterm = '1' then
				exit;
			end if;
		end loop clkloop;

		print(output, " -- TERMINATED --");
		-- Close connection to netpp device
		device_close(device);
		wait;

	end process;

----------------------------------------------------------------------------

	process (clk)
		variable ret : integer;
	begin
		if rising_edge(clk) then
			count <= count + 1;
			-- Set register value on device to counter value:
			ret := device_set_register(device, t_int, to_integer(count));
			if ret < 0 then
				print(output, "Failed to set integer on peer");
			end if;
		end if;
	end process;

end;
