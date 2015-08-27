--! \file dpram16    Virtual 16 bit RAM for backdoor access
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- Unsigned

library work;
-- The RAM functions are generated within the netpp autowrapper
use work.ghpi_netpp.all;

--! \brief Dual port RAM with simulation interface via netpp
--!
--! This RAM registers itself as a netpp property and can be addressed
--! under its instance name from outside, provided the netpp.vpi module
--! is loaded or initialized from within the simulation.
--! Access to a RAM block is easiest done via Python, example:
--! \code
--! import netpp
--! dev = netpp.connect("localhost")
--! root = dev.sync()
--!
--! Ram0 = getattr(root, ":sim_top:ram:") # Retrieve Ram0 entity token
--! rambuf0 = Ram0.get()  # Get old buffer
--! a = 256 * chr(0)      # Generate 256 zeros
--! Ram0.set(buffer(a))   # Set RAM
--! \endcode
--!
entity DualPort16 is
	generic(
		NETPP_NAME   : string   := "DEFAULT";
		ADDR_W       : natural  := 14
	);
	port(
		clk     : in  std_logic;           --! Clock for Port A and B
		-- Port A
		a_we    : in  std_logic;           --! A write enable (high active)
		a_addr  : in  unsigned(ADDR_W-1 downto 0); --! Port A Address
		a_write : in  unsigned(16-1 downto 0); --! Port A write data
		a_read  : out unsigned(16-1 downto 0); --! Read data
		-- Port B
		b_we    : in  std_logic;           --! B write enable
		b_addr  : in  unsigned(ADDR_W-1 downto 0); --! B address
		b_write : in  unsigned(16-1 downto 0);  --! B write data
		b_read  : out unsigned(16-1 downto 0)   --! B read data
	);
end DualPort16;

architecture simulation of DualPort16 is
	shared variable ram_handle : rambuf_t;
begin

-- Initialization within simulation:
	process
	begin
		if NETPP_NAME = "DEFAULT" then
			ram_handle := ram_new(simulation'path_name, 16, ADDR_W);
		else
			ram_handle := ram_new(NETPP_NAME, 16, ADDR_W);
		end if;
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
		variable wdata_a: ram_port_t;
		variable wdata_b: ram_port_t;
		variable rdata_a: ram_port_t;
		variable rdata_b: ram_port_t;
	begin
		addr_a := a_addr;
		addr_b := b_addr;
		wdata_a := resize(a_write, wdata_a'length);
		wdata_b := resize(b_write, wdata_b'length);
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
		a_read <= rdata_a(a_read'range);
		b_read <= rdata_b(b_read'range);
	end process;

end simulation;
