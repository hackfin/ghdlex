--! \file vram.vhdl Virtual n-bit RAM (up to 32 bit) for backdoor access
--!

--
-- (c) 2011-2018 Martin Strubel <hackfin@section5.ch>
--
-- Configureable WORDSIZE (1, 2)
--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- Unsigned

library work;
-- The RAM functions are generated within the netpp autowrapper
use work.ghpi_netpp.all;
use work.virtual.all;

--! \brief Dual port RAM with simulation interface via netpp
--!
--! This RAM registers itself as a netpp property and can be addressed
--! under its instance name from outside, provided the netpp.vpi module
--! is loaded or initialized from within the simulation.
--!
--!
entity VirtualDualPortRAM is
	generic(
		NETPP_NAME   : string   := "DEFAULT"; --! netpp entity name
		DATA_W       : natural  := 32;        --! Data width (bits)
		ADDR_W       : natural  := 14;        --! Address bits
		--! Initialization data
		INIT_DATA    : vram32_init_t := (0 => x"00000000")
	);
	port(
		clk     : in  std_logic;           --! Clock for Port A and B
		-- Port A
		a_we    : in  std_logic;           --! A write enable (high active)
		a_addr  : in  unsigned(ADDR_W-1 downto 0); --! Port A Address
		a_write : in  unsigned(DATA_W-1 downto 0); --! Port A write data
		a_read  : out unsigned(DATA_W-1 downto 0); --! Read data
		-- Port B
		b_we    : in  std_logic;           --! B write enable
		b_addr  : in  unsigned(ADDR_W-1 downto 0); --! B address
		b_write : in  unsigned(DATA_W-1 downto 0);  --! B write data
		b_read  : out unsigned(DATA_W-1 downto 0)   --! B read data
	);
end VirtualDualPortRAM;

architecture simulation of VirtualDualPortRAM is
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
				if b_we = '1' then
					assert false report "Write collision";
				end if;
				ram_write(ram_handle, addr_a, wdata_a);
				rdata_a := wdata_a; -- bypass
				if addr_a = addr_b then
					rdata_b := wdata_a;
				else
					ram_read(ram_handle, addr_b, rdata_b);
				end if;
			elsif b_we = '1' then
				ram_write(ram_handle, addr_b, wdata_b);
				rdata_b := wdata_b; -- bypass

				if addr_a = addr_b then
					rdata_a := wdata_b;
				else
					ram_read(ram_handle, addr_a, rdata_a);
				end if;
			else
				ram_read(ram_handle, addr_a, rdata_a);
				ram_read(ram_handle, addr_b, rdata_b);
			end if;

		end if;
		a_read <= rdata_a(DATA_W-1 downto 0);
		b_read <= rdata_b(DATA_W-1 downto 0);
	end process;

end simulation;
