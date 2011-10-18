library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- Unsigned

entity simple is end simple;
architecture behaviour of simple is
	signal clk : std_logic := '0';
	signal sigterm : std_logic := '0';
	signal counter : unsigned(7 downto 0) := x"00";
begin
	process
	begin
		wait for 5 us;
		clkloop : loop
			wait for 1 us;
			clk <= not clk;
			if sigterm = '1' then
				exit;
			end if;
		end loop clkloop;
		wait for 5 us;
		wait;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if counter = 16 then
				sigterm <= '1';
			end if;
			counter <= counter + 1;
		end if;
	end process;
end behaviour;
