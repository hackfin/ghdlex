--! \file      Virtual n-bit RAM (up to 32 bit) (dual clock)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- Unsigned

library work;
-- The RAM functions are generated within the netpp autowrapper
use work.ghpi_netpp.all;
use work.virtual.all;

--! \brief Dual port RAM with simulation interface via netpp
--! Experimental dual clock version of the VirtualDualPortRAM component
--! Does not check for collisions
--!
--! \endcode
--!
entity VirtualDualPortRAM_dc is
	generic(
		NETPP_NAME   : string   := "DEFAULT";
		HAVE_RESET   : boolean  := false;
		DATA_W       : natural  := 32;
		ADDR_W       : natural  := 14;
		EN_BYPASS   : boolean := false;
		SYN_RAMTYPE  : string   := "simulation_only";

		INIT_DATA    : vram32_init_t := (0 => x"00000000")
	);
	port(
		-- Port A
		a_clk   : in  std_logic;           --! Clock for Port A
		a_we    : in  std_logic;           --! A write enable (high active)
		a_addr  : in  unsigned(ADDR_W-1 downto 0); --! Port A Address
		a_write : in  unsigned(DATA_W-1 downto 0); --! Port A write data
		a_read  : out unsigned(DATA_W-1 downto 0); --! Read data
		-- Port B
		b_clk   : in  std_logic;           --! Clock for Port B
		b_we    : in  std_logic;           --! B write enable
		b_addr  : in  unsigned(ADDR_W-1 downto 0); --! B address
		b_write : in  unsigned(DATA_W-1 downto 0);  --! B write data
		b_read  : out unsigned(DATA_W-1 downto 0);  --! B read data
		reset   : in  std_logic            --! Reset for compatibility
	);
end VirtualDualPortRAM_dc;

architecture simulation of VirtualDualPortRAM_dc is
	shared variable ram_handle : rambuf_t;

	procedure ram_init (data : in vram32_init_t) is
		variable size : integer;
		variable wdat : ram_port_t;
		variable addr : unsigned(ADDR_W-1 downto 0);
	begin
		size := (2**ADDR_W);

		if data'length < size then
			size := data'length;
			assert false
			report "Init data not specified or less than RAM size"
			severity warning;

		elsif data'length > size then
			assert false
			report "Init data size mismatch, not initializing"
			severity failure;
		end if;

		for i in 0 to size-1 loop
			addr := to_unsigned(i, ADDR_W);
			wdat := resize(data(i)(DATA_W-1 downto 0), wdat'length);
			ram_write(ram_handle, addr, wdat);
		end loop;
	end procedure;

begin

-- Initialization within simulation:
	process
	begin
		if NETPP_NAME = "DEFAULT" then
			ram_handle := ram_new(simulation'path_name, DATA_W, ADDR_W);
		else
			ram_handle := ram_new(NETPP_NAME, DATA_W, ADDR_W);
		end if;
		if ram_handle = null then
			assert false report "Failed to reserve RAM buffer";
		end if;
		ram_init(INIT_DATA);
		wait;
		ram_del(ram_handle); -- We never get here..
	end process;

porta_proc:
	process(a_clk)
		variable addr_a: unsigned(ADDR_W-1 downto 0);
		variable wdata_a: ram_port_t;
		variable rdata_a: ram_port_t;
	begin
		addr_a := a_addr;
		wdata_a := resize(a_write, wdata_a'length);
		if rising_edge(a_clk) then
			if a_we = '1' then
				ram_write(ram_handle, addr_a, wdata_a);
				rdata_a := wdata_a; -- bypass
			else
				ram_read(ram_handle, addr_a, rdata_a);
			end if;

		end if;
		a_read <= rdata_a(DATA_W-1 downto 0);
	end process;

portb_proc:
	process(b_clk)
		variable addr_b: unsigned(ADDR_W-1 downto 0);
		variable wdata_b: ram_port_t;
		variable rdata_b: ram_port_t;
	begin
		addr_b := b_addr;
		wdata_b := resize(b_write, wdata_b'length);
		if rising_edge(b_clk) then
			if b_we = '1' then
				ram_write(ram_handle, addr_b, wdata_b);
				rdata_b := wdata_b; -- bypass
			else
				ram_read(ram_handle, addr_b, rdata_b);
			end if;

		end if;
		b_read <= rdata_b(DATA_W-1 downto 0);
	end process;

end simulation;
