library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- Unsigned

library work;
-- The RAM functions are generated within the netpp autowrapper
use work.ghpi_netpp.all;


entity DualPort16 is
	generic(
		ADDR_W       : natural := 14
	);
	port(
		clk     : in  std_logic;
		-- Port A
		a_we    : in  std_logic;
		a_addr  : in  unsigned(ADDR_W-1 downto 0);
		a_write : in  unsigned(16-1 downto 0);
		a_read  : out unsigned(16-1 downto 0);
		-- Port B
		b_we    : in  std_logic;
		b_addr  : in  unsigned(ADDR_W-1 downto 0);
		b_write : in  unsigned(16-1 downto 0);
		b_read  : out unsigned(16-1 downto 0)
	);
end DualPort16;

architecture simulation of DualPort16 is
	shared variable ram_handle : rambuf_t;
begin

-- Initialization within simulation:
	process
	begin
		ram_handle := ram_new(ADDR_W, simulation'instance_name);
		if ram_handle = null then
			assert false report "Failed to reserve RAM buffer";
		end if;
		wait;
		ram_del(ram_handle); -- We never get here..
	end process;

	process(clk)
		variable err: integer;
		variable addr_a: unsigned(ADDR_W-1 downto 0);
		variable addr_b: unsigned(ADDR_W-1 downto 0);
		variable wdata_a: unsigned(15 downto 0);
		variable wdata_b: unsigned(15 downto 0);
		variable rdata_a: unsigned(15 downto 0);
		variable rdata_b: unsigned(15 downto 0);
	begin
		addr_a := a_addr;
		addr_b := b_addr;
		wdata_a := a_write;
		wdata_b := b_write;
		if rising_edge(clk) then
			if a_we = '1' then
				ram_write(ram_handle, addr_a, wdata_a);
			elsif b_we = '1' then
				ram_write(ram_handle, addr_b, wdata_b);
			else
				ram_read(ram_handle, addr_a, rdata_a);
				ram_read(ram_handle, addr_b, rdata_b);
			end if;
		end if;
		a_read <= rdata_a;
		b_read <= rdata_b;
	end process;

end simulation;