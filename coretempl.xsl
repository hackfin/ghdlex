<?xml version="1.0" encoding="ISO-8859-1"?>
<!-- (c) 2007-2014 Martin Strubel <hackfin@section5.ch>
     This file converts a XML device description into VHDL a SoC system map

     This file is under GPLv2 license. Dual licensing models are possible, as
     long as no third party is involved.
-->
<xsl:stylesheet version="1.0" 
	xmlns:my="http://www.section5.ch/dclib/schema/devdesc"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" >
<xsl:import href="map.xsl"/>	
<xsl:import href="vhdlport.xsl"/>	

<!-- Output method TEXT -->
	<xsl:output method="text" indent="yes" encoding="ISO-8859-1"/>	

<!-- Source file name -->
<xsl:param name="srcfile">"-UNKNOWN-"</xsl:param>
<!-- Entity name -->
<xsl:param name="entityname">default</xsl:param>
<!-- Interface type (std_logic_vector or unsigned) -->
<xsl:param name="iface_type">std_logic_vector</xsl:param>
<!-- Data bus width -->
<xsl:param name="dwidth">16</xsl:param>


<xsl:template match="my:property" mode="signal_export">
entity <xsl:value-of select="@name"/> is
	port (
		<xsl:apply-templates select="key('regkey', ./my:regref/@ref)" mode="signal_export">
			<xsl:with-param name="prefix"></xsl:with-param>
		</xsl:apply-templates>
		ctrl      : out <xsl:value-of select="@name"/>_WritePort;
		stat      : in  <xsl:value-of select="@name"/>_ReadPort;

		clk       : in std_logic
	);
end entity <xsl:value-of select="$entityname"/>;


architecture behaviour of <xsl:value-of select="$entityname"/> is
begin

end architecture;
</xsl:template>

<xsl:template match="my:array" mode="signal_export">
entity <xsl:value-of select="@name"/> is
<xsl:text>	port (
</xsl:text>
		<xsl:apply-templates select="key('regkey', ./my:property/my:regref/@ref)" mode="signal_export">
			<xsl:with-param name="prefix"></xsl:with-param>
		</xsl:apply-templates>
		-- Standard ports:
		ctrl      : out <xsl:value-of select="@name"/>_WritePort;
		stat      : in  <xsl:value-of select="@name"/>_ReadPort;

		clk       : in std_logic
	);
end entity <xsl:value-of select="$entityname"/>;


architecture behaviour of <xsl:value-of select="$entityname"/> is
begin

end architecture;

</xsl:template>

<xsl:template match="/">
-- This is a VHDL template file generated from
-- <xsl:value-of select="$srcfile"/>
-- using coretempl.xsl
-- Changes to this file MAY BE LOST. Copy and edit manually!
--
-- (c) 2012-2013, Martin Strubel // hackfin@section5.ch
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
--  System map definitions:
	use work.system_map.all;

<xsl:apply-templates select=".//my:group[@name='INSTANCES']/my:array[@name=$entityname]" mode="signal_export" />
<xsl:apply-templates select=".//my:group[@name='INSTANCES']/my:property[@name=$entityname]" mode="signal_export" />


</xsl:template>
</xsl:stylesheet>
