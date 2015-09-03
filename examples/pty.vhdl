-- Simulator <-> C interfacing example via linux pipes
-- (c) 2011 Martin Strubel <hackfin@section5.ch>
--
--
-- Under Linux, run this command to create a virtual UART interface:
--
--    > sudo socat PTY,link=/var/run/ghdlsim,raw,echo=0,user=`whoami` \
--              PTY,link=/var/run/iopipe,raw,echo=0,user=`whoami`
--
-- Then open a terminal on the host side:
--
--    > minicom -o -D /var/run/iopipe
--
-- and run the simulation:
-- ./simpty
--
-- What you type into the terminal window is then echoed by the simulation.
-- Also, you'll see the characters printed out in hex on the simulation
-- windows.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- Unsigned

library ghdlex;
use ghdlex.ghpi_pipe.all;
use ghdlex.txt_util.all;

use std.textio.all;

entity simpty is end simpty;

architecture behaviour of simpty is
	signal clk : std_ulogic := '0';
	signal count : unsigned(7 downto 0) := x"05";
	signal data : unsigned(7 downto 0);
	signal sigterm : std_logic := '0';
	signal wr       : std_logic := '0';
	signal rx_ready : std_logic := '1';
	signal data_valid : std_logic := '0';
	signal pipe_flags : pipeflag_t := "0000";
	-- Pipe handles:
	shared variable iopipe : pipehandle_t;

begin
	process
		variable err : integer;
	begin
		iopipe := openpipe("/var/run/ghdlsim");
		if iopipe < 0 then
			assert false report "Failed to open PTY pipe" severity failure;
		end if;
		clkloop : loop
			wait for 1 us;
			clk <= not clk;
			if sigterm = '1' then
				exit;
			end if;
		end loop clkloop;

		print(output, " -- TERMINATED --");
		closepipe(iopipe);
		wait;

	end process;

	process (clk)
		variable val : unsigned(7 downto 0);
		variable flags : pipeflag_t;
	begin
		if rising_edge(clk) then

			flags := pipe_flags;

			-- Only call pipe if
			-- * Data ready to receive
			-- * Write command
			-- * There was something in the RX buffer

			if wr = '1' or rx_ready = '1' or flags(RX) = '1' then
				val := data;
				flags(TX) := wr;
				pipe_rxtx(iopipe, val, flags);
			end if;

			-- Did we get a byte?
			if pipe_flags(RX) = '1' then
				data <= val;
				data_valid <= '1';
				-- Terminate when we get Ctrl-E:
				if val = x"05" then
					sigterm <= '1';
				end if;
				print(output, "SIM> " & hstr(val(8-1 downto 0)));
				wr <= '1';
			else
				wr <= '0';
				data_valid <= '0';
			end if;

			-- Only file read on next cycle when requested:
			flags(RX) := flags(RX) and rx_ready;

			-- Save flags for next time
			pipe_flags <= flags;

		end if;
	end process;

end;
