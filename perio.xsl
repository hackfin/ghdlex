<?xml version="1.0" encoding="ISO-8859-1"?>
<!-- 
      XML style sheet template to create I/O address decoders in VHDL.
      (c) 2011-2014 Martin Strubel <hackfin@section5.ch>
-->
<xsl:stylesheet version="1.0" 
	xmlns:my="http://www.section5.ch/dclib/schema/devdesc"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" >

<xsl:import href="map.xsl"/>	

	<xsl:output method="text" indent="yes" encoding="ISO-8859-1"/>	

<!-- Source file name -->
<xsl:param name="srcfile">"-UNKNOWN-"</xsl:param>
<!-- Index of desired device or id reference -->
<xsl:param name="selectDevice">1</xsl:param>
<!-- If 1, use parent register map's name as prefix -->
<xsl:param name="useMapPrefix">0</xsl:param>
<!-- Register prefix -->
<xsl:param name="regprefix">R_</xsl:param>
<!-- Entity prefix -->
<xsl:param name="entprefix">decode_</xsl:param>
<!-- most significant byte to define address width -->
<xsl:param name="selprefix">select_</xsl:param>
<!-- most significant byte to define address width -->
<xsl:param name="msb">15</xsl:param>
<!-- register map to be output -->
<xsl:param name="regmap">default</xsl:param>

<!-- Interface type (std_logic_vector or unsigned) -->
<xsl:param name="iface_type">std_logic_vector</xsl:param>

<xsl:param name="dwidth">16</xsl:param>

<xsl:variable name="index" select="number($selectDevice)"></xsl:variable>
<xsl:variable name="defaultvalue">X</xsl:variable>


<xsl:template match="my:device" mode="impl_decoder">
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.<xsl:value-of select="@id"/>.all;

<xsl:variable name="entityname" select="my:registermap[@id=$regmap]/@id"></xsl:variable>

entity <xsl:value-of select="$entprefix"/><xsl:value-of select="$entityname"/> is
	port (
		ce        : in  std_logic;
		ctrl      : out <xsl:value-of select="$entityname"/>_WritePort;
		stat      : in  <xsl:value-of select="$entityname"/>_ReadPort;
		data_in   : in  <xsl:value-of select="$iface_type"/>(<xsl:value-of select="$dwidth"/>-1 downto 0);
		data_out  : out <xsl:value-of select="$iface_type"/>(<xsl:value-of select="$dwidth"/>-1 downto 0);
		addr      : in  <xsl:value-of select="$iface_type"/>(BV_MMR_CFG_<xsl:value-of select="$entityname"/>);
		we        : in  std_logic;
		clk       : in  std_logic
	);
end entity <xsl:value-of select="$entprefix"/><xsl:value-of select="$entityname" />;

architecture behaviour of <xsl:value-of select="$entprefix"/><xsl:value-of select="$entityname" /> is

	constant ADDR_MSB : natural := <xsl:value-of select="$msb"/>;
	subtype REG_SIZE1B is integer range 7 downto 0;
	subtype REG_SIZE2B is integer range 15 downto 0;
	subtype REG_SIZE4B is integer range 31 downto 0;

	-- Default register size:
	subtype reg_size1_t is <xsl:value-of select="$iface_type"/>(7 downto 0);
	subtype reg_size2_t is <xsl:value-of select="$iface_type"/>(15 downto 0);
	subtype reg_size4_t is <xsl:value-of select="$iface_type"/>(31 downto 0);

	signal uaddr : unsigned(BV_MMR_CFG_<xsl:value-of select="$entityname"/>);
<xsl:apply-templates select=".//my:registermap[@id=$regmap]" mode="sig_decl" />

begin

	uaddr    &lt;= unsigned(addr);
<xsl:apply-templates select=".//my:registermap[@id=$regmap]" mode="implementation" />
end behaviour;
</xsl:template>


<xsl:template match="/">
-- This is a VHDL template file generated from
-- <xsl:value-of select="$srcfile"/>
-- using perio.xsl
-- Changes to this file WILL BE LOST. Edit the source file.
--
-- (c) 2012-2013, Martin Strubel // hackfin@section5.ch
--
--

	<xsl:choose>
	<xsl:when test="string(index) != 'NaN'">
		<xsl:apply-templates select=".//my:device[$index]" mode="impl_decoder"/>
	</xsl:when>
	<xsl:otherwise>
		<xsl:apply-templates select=".//my:device[@id=$selectDevice]" mode="impl_decoder"/>
	</xsl:otherwise>
	</xsl:choose>

</xsl:template>


<xsl:template match= "my:register" mode="impl_read">
	<xsl:if test="not(@access) or @access = 'RW' or @access = 'RO'">
		<xsl:text>				when </xsl:text>
		<xsl:value-of select="$regprefix"/>
		<xsl:if test="$useMapPrefix = 1">
			<xsl:value-of select="../@name"/>_</xsl:if>
		<xsl:value-of select="@id"/>
		<xsl:text> =&gt;
</xsl:text>
		<xsl:choose>
			<xsl:when test="./my:bitfield">
				<xsl:apply-templates select=".//my:bitfield" mode="impl_read"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:choose>
					<xsl:when test="@size">
					<xsl:text>					data_out(REG_SIZE</xsl:text>
					<xsl:value-of select="@size"/>B) &lt;= reg_<xsl:value-of select="@id"/>
					</xsl:when>
					<xsl:otherwise>
					<xsl:text>					data_out &lt;= reg_</xsl:text>
						<xsl:value-of select="translate(@id, $ucase, $lcase)"/>
					</xsl:otherwise>
				</xsl:choose>
			<xsl:text>;
</xsl:text>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:if>
</xsl:template>

<xsl:template match= "my:register" mode="impl_write">
<xsl:param name="regid"><xsl:value-of select="translate(@id, $ucase, $lcase)"/></xsl:param>
<xsl:text>				when </xsl:text>
	<xsl:value-of select="$regprefix"/>
	<xsl:if test="$useMapPrefix = 1"><xsl:value-of select="../@name"/>_</xsl:if>
	<xsl:value-of select="@id"/>
	<xsl:text> =&gt;
</xsl:text>
	<xsl:choose>
		<xsl:when test="./my:bitfield">
<xsl:apply-templates select=".//my:bitfield" mode="impl_write"/>
		</xsl:when>
		<xsl:when test="@volatile='true'">
		<xsl:text>					ctrl.</xsl:text><xsl:value-of select="$regid"/> &lt;= data_in(REG_SIZE<xsl:value-of select="@size"/>B)<xsl:text>;
</xsl:text>
		</xsl:when>
		<xsl:otherwise>					reg_<xsl:value-of select="$regid"/> &lt;= data_in(REG_SIZE<xsl:value-of select="@size"/>B)<xsl:text>;
</xsl:text>
		</xsl:otherwise>
	</xsl:choose>
	<xsl:if test="@volatile='true'">
		<xsl:text>					ctrl.</xsl:text><xsl:value-of select="$selprefix"/>
		<xsl:value-of select="$regid"/>
		<xsl:text> &lt;= '1';
</xsl:text>
	</xsl:if>
</xsl:template>

<xsl:template match="my:register" mode="sig_decl" >
	-- Register <xsl:value-of select="@id"/>
	<xsl:text>
</xsl:text>
	<xsl:choose>
		<xsl:when test="./my:bitfield">
			<xsl:apply-templates select="./my:bitfield" mode="sig_decl" />
		</xsl:when>
		<xsl:otherwise>
	<xsl:text>	signal reg_</xsl:text>
	<xsl:value-of select="translate(@id, $ucase, $lcase)"/> : reg_size<xsl:value-of select="@size"/>_t<xsl:apply-templates select="./my:default" mode="reg_assign"/>;
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match= "my:default" mode="reg_assign">
	<xsl:text> := x"</xsl:text>
	<xsl:value-of select="."/>
	<xsl:text>"</xsl:text>
</xsl:template>

<xsl:template name="b_assign">
	<xsl:variable name="pos_lsb" select="number(string-length(../my:default)-@msb)"></xsl:variable>
	<xsl:variable name="bvlen" select="number(@msb) - number(@lsb) + 1"></xsl:variable>
	<xsl:choose>
		<xsl:when test="@msb = @lsb">
			<xsl:text> := '</xsl:text>
			<xsl:value-of select="substring(../my:default, $pos_lsb, 1)"/>
			<xsl:text>'</xsl:text>
		</xsl:when>
		<xsl:otherwise>
			<xsl:text> := "</xsl:text>
			<xsl:value-of select="substring(../my:default, $pos_lsb, $bvlen)"/>
			<xsl:text>"</xsl:text>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match= "my:register" mode="sig_assign_ro">
	<xsl:param name="regid"><xsl:value-of select="translate(@id, $ucase, $lcase)"/></xsl:param>
	<xsl:text>				when </xsl:text>
		<xsl:value-of select="$regprefix"/>
		<xsl:if test="$useMapPrefix = 1">
			<xsl:value-of select="../@name"/>_</xsl:if>
			<xsl:value-of select="@id"/>
		<xsl:text> =&gt;
</xsl:text>
	<xsl:choose>
		<xsl:when test="./my:bitfield">
			<xsl:apply-templates select=".//my:bitfield" mode="sig_assign_ro"/>
		</xsl:when>
		<xsl:otherwise>

			<xsl:choose>
				<xsl:when test="@size">
				<xsl:text>					data_out(REG_SIZE</xsl:text>
				<xsl:value-of select="@size"/>B) &lt;= stat.<xsl:value-of select="$regid"/>
				</xsl:when>
				<xsl:otherwise>
				<xsl:text>					data_out &lt;= stat.</xsl:text>
				<xsl:value-of select="$regid"/>
				</xsl:otherwise>
			</xsl:choose>
		<xsl:text>;
</xsl:text>
			<xsl:if test="@volatile">
				<xsl:text>					ctrl.</xsl:text><xsl:value-of select="$selprefix"/>
				<xsl:value-of select="$regid"/>
				<xsl:text> &lt;= '1';
</xsl:text>
			</xsl:if>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match= "my:register" mode="sig_set_default">
	<xsl:text>			ctrl.</xsl:text><xsl:value-of select="$selprefix"/>
	<xsl:value-of select="translate(@id, $ucase, $lcase)"/>
	<xsl:text> &lt;= '0';
</xsl:text>

</xsl:template>


<xsl:template match= "my:register" mode="sig_assign_rw">
	<xsl:param name="regid"><xsl:value-of select="translate(@id, $ucase, $lcase)"/></xsl:param>
	<xsl:choose>
		<xsl:when test="./my:bitfield">
			<xsl:apply-templates select=".//my:bitfield" mode="sig_assign_rw"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:text>	ctrl.</xsl:text>
				<xsl:value-of select="$regid"/>
			<xsl:text> &lt;= reg_</xsl:text>
				<xsl:value-of select="$regid"/>
		<xsl:text>;
</xsl:text>

		</xsl:otherwise>
	</xsl:choose>

</xsl:template>

<xsl:template match="my:bitfield" mode="sig_decl" >
<xsl:param name="bfid"><xsl:value-of select="translate(@name, $ucase, $lcase)"/></xsl:param>
	<xsl:choose>
	<xsl:when test="@msb = @lsb">
		<xsl:text>	signal bit_</xsl:text>
		<xsl:value-of select="$bfid"/>
		<xsl:text> : std_logic</xsl:text>
			<xsl:if test="../my:default">
			<xsl:call-template name="b_assign"/>
			</xsl:if>
		<xsl:text>;
</xsl:text>
	</xsl:when>
	<xsl:otherwise>
		<xsl:text>	signal reg_</xsl:text>
		<xsl:value-of select="$bfid"/> : <xsl:value-of select="$iface_type"/>(BV_<xsl:value-of select="@name"/>
			<xsl:text>)</xsl:text>
			<xsl:if test="../my:default">
			<xsl:call-template name="b_assign"/>
			</xsl:if>
			<xsl:text>;
</xsl:text>
	</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="my:bitfield" mode="impl_read" >
<xsl:param name="bfid"><xsl:value-of select="translate(@name, $ucase, $lcase)"/></xsl:param>
	<xsl:choose>
		<xsl:when test="@msb = @lsb">
			<xsl:text>					data_out(B_</xsl:text>
			<xsl:value-of select="@name"/>) &lt;= bit_<xsl:value-of select="$bfid"/>
			<xsl:text>;
</xsl:text>
		</xsl:when>
		<xsl:otherwise>
			<xsl:text>					data_out(BV_</xsl:text>
			<xsl:value-of select="@name"/>) &lt;= reg_<xsl:value-of select="$bfid"/>
			<xsl:text>;
</xsl:text>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="my:bitfield" mode="impl_write" >
<xsl:param name="bfid"><xsl:value-of select="translate(@name, $ucase, $lcase)"/></xsl:param>
	<xsl:choose>
		<xsl:when test="../@volatile">
			<xsl:text>					ctrl.</xsl:text>
			<xsl:value-of select="$bfid"/> &lt;= data_in(B_<xsl:value-of select="@name"/>
			<xsl:text>);
</xsl:text>
		</xsl:when>
		<xsl:when test="@msb = @lsb">
			<xsl:text>					bit_</xsl:text>
			<xsl:value-of select="$bfid"/> &lt;= data_in(B_<xsl:value-of select="@name"/>
			<xsl:text>);
</xsl:text>
		</xsl:when>
		<xsl:otherwise>
			<xsl:text>					reg_</xsl:text>
			<xsl:value-of select="$bfid"/> &lt;= data_in(BV_<xsl:value-of select="@name"/>
			<xsl:text>);
</xsl:text>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="my:bitfield" mode="sig_assign_ro" >
<xsl:param name="bfid"><xsl:value-of select="translate(@name, $ucase, $lcase)"/></xsl:param>
	<xsl:choose>
		<xsl:when test="@msb = @lsb">
			<xsl:text>					data_out(B_</xsl:text>
		<xsl:value-of select="@name"/>) &lt;= stat.<xsl:value-of select="$bfid"/>
			<xsl:text>;
</xsl:text>
		</xsl:when>
		<xsl:otherwise>	
			<xsl:text>					data_out(BV_</xsl:text>
			<xsl:value-of select="@name"/>) &lt;= stat.<xsl:value-of select="$bfid"/>
			<xsl:text>;
</xsl:text>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="my:bitfield" mode="sig_assign_rw" >
<xsl:param name="bfid"><xsl:value-of select="translate(@name, $ucase, $lcase)"/></xsl:param>

	<xsl:if test="not(../@access='RO')">
		<xsl:choose>
			<xsl:when test="@msb = @lsb">
				<xsl:text>	ctrl.</xsl:text>
				<xsl:value-of select="$bfid"/> &lt;= bit_<xsl:value-of select="$bfid"/>
			<xsl:text>;
</xsl:text>
			</xsl:when>
			<xsl:otherwise>	
				<xsl:text>	ctrl.</xsl:text>
				<xsl:value-of select="$bfid"/> &lt;= reg_<xsl:value-of select="$bfid"/>
			<xsl:text>;
</xsl:text>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:if>
</xsl:template>

<xsl:template match="my:registermap" mode="sig_decl" >
	--------------------------
	-- Register allocations --
	<xsl:apply-templates select=".//my:register[not(@access) or @access='RW' or (not(@access='RO') and not(@volatile='true'))]" mode="sig_decl" />

</xsl:template>

<!-- Inactive 
<xsl:template match="my:registermap" mode="sig_assign" >

<xsl:apply-templates select=".//my:register[not(@access='RO') or not(@access) or @access='RW']" mode="sig_assign_w"/>
<xsl:apply-templates select=".//my:register[@access='RO']" mode="sig_assign_ro"/>
</xsl:template>
-->

<xsl:template match="my:registermap" mode="implementation" >
-- Registermap <xsl:value-of select="@name" />

ioproc_<xsl:value-of select="@id"/>:
	process(clk)
		variable addr : unsigned(ADDR_MSB downto 0);
		constant ZEROPAD   :
		unsigned(ADDR_MSB - uaddr'length downto 0) :=
			(others => '0');
	begin
		if rising_edge(clk) then
<xsl:apply-templates select=".//my:register[@volatile='true']" mode="sig_set_default" />
		if ce = '1' then
			addr := ZEROPAD &amp; uaddr;
			-- WRITE
			if we = '1' then
				case addr is
<xsl:apply-templates select=".//my:register[not(@access) or @access = 'RW']" mode="impl_write" />
<xsl:apply-templates select=".//my:register[@access = 'WO']" mode="impl_write" />
				when others =>
				end case;
			-- READ
			else
				case addr is
<xsl:apply-templates select=".//my:register[@access='RO']" mode="sig_assign_ro" />
<xsl:apply-templates select=".//my:register[not(@access='RO')]" mode="impl_read" />
				when others =>
					data_out &lt;= (others => '<xsl:value-of select="$defaultvalue"/>');
				end case;
			end if;
		end if;
		end if;
	end process;

	-- Assignments
<xsl:apply-templates select=".//my:register[not(@access='RO') and not(@volatile='true')]" mode="sig_assign_rw" />

</xsl:template>

</xsl:stylesheet>
