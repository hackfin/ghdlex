<!-- 
	Port export utilities
    (c) 2007-2014 Martin Strubel <hackfin@section5.ch>

     This file is under GPLv2 license. Dual licensing models are possible, as
     long as no third party is involved.
-->

<xsl:stylesheet version="1.0" 
	xmlns:my="http://www.section5.ch/dclib/schema/devdesc"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" >

<!-- Convert access spec into port spec -->

<xsl:template name="access2port">
	<xsl:param name="access">RW</xsl:param>
	<xsl:choose>
		<xsl:when test="$access = 'RO'">in</xsl:when>
		<xsl:when test="$access = 'WO'">out</xsl:when>
		<xsl:otherwise>inout</xsl:otherwise>
	</xsl:choose>
</xsl:template>

	<!-- Signal export to PORT -->
<xsl:template match="my:bitfield" mode="signal_export">
	<xsl:param name="prefix"></xsl:param>

	<xsl:param name="arraysize">0</xsl:param>
	<xsl:variable name="pin_type">
		<xsl:choose>
			<xsl:when test="$arraysize = 0">std_logic</xsl:when>
			<xsl:otherwise>std_logic_vector(<xsl:value-of select="$arraysize"/> downto 0)</xsl:otherwise>
		</xsl:choose>
	</xsl:variable>

	<!-- Inherit access from parenting register, if not defined -->
	<xsl:variable name="access">
		<xsl:choose>
			<xsl:when test="@access"><xsl:value-of select="@access"/></xsl:when>
			<xsl:otherwise><xsl:value-of select="../@access"/></xsl:otherwise>
		</xsl:choose>
	</xsl:variable>

	<xsl:text>		</xsl:text>
		<xsl:value-of select="$prefix"/><xsl:value-of select="@name"/> : <xsl:call-template name="access2port">
		<xsl:with-param name="access" select="$access"/>
	</xsl:call-template>
		<xsl:text>  </xsl:text>
	<xsl:choose>
		<xsl:when test="@msb = @lsb"> <xsl:value-of select="$pin_type"/>;</xsl:when>
		<xsl:otherwise>
			<xsl:value-of select="$iface_type"/>(<xsl:value-of select="@msb"/> downto <xsl:value-of select="@lsb"/>);</xsl:otherwise>
	</xsl:choose>
	<xsl:if test="my:info">--! <xsl:value-of select="my:info"/></xsl:if>
	<xsl:text>
</xsl:text>
</xsl:template>


<xsl:template match="my:register" mode="signal_export">
	<xsl:param name="arraysize">0</xsl:param>
	<xsl:param name="prefix"><xsl:value-of select="@id"/>_</xsl:param>
	<xsl:choose>
		<xsl:when test="./my:bitfield">
	<xsl:text>		---- Port export for </xsl:text><xsl:value-of select="@id"/><xsl:text> pseudo register
</xsl:text>
		<xsl:apply-templates select="my:bitfield" mode="signal_export">
			<xsl:with-param name="prefix" select="$prefix"/>
			<xsl:with-param name="arraysize" select="$arraysize"/>
		</xsl:apply-templates>
		</xsl:when>
		<xsl:otherwise>
			<xsl:text>		</xsl:text>
			<xsl:value-of select="@id"/> : <xsl:call-template name="access2port">
				<xsl:with-param name="access" select="@access"/>
			</xsl:call-template>
			<xsl:text>  </xsl:text>
<xsl:value-of select="$iface_type"/>(<xsl:value-of select="@size"/>*8-1 downto 0);<xsl:if test="my:info">--! <xsl:value-of select="my:info"/></xsl:if></xsl:otherwise>
	</xsl:choose>
	<xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="my:array" mode="signal_export">
	<xsl:text>		-- Pin array export for </xsl:text><xsl:value-of select="@name"/><xsl:text> units --
</xsl:text>
	<xsl:apply-templates select="key('regkey', ./my:property/my:regref/@ref)" mode="signal_export">
		<xsl:with-param name="arraysize" select="my:size/my:value"/>
	</xsl:apply-templates>
</xsl:template>

<xsl:template match="my:property" mode="signal_export">
	<xsl:text>		-- Pin export for </xsl:text><xsl:value-of select="@name"/><xsl:text> unit --
</xsl:text>
	<xsl:apply-templates select="key('regkey', ./my:regref/@ref)" mode="signal_export"/>
</xsl:template>

<xsl:template match="my:registermap" mode="signal_export">
	<xsl:apply-templates select=".//my:register" mode="signal_export" />
</xsl:template>

<xsl:template match="my:registermap" mode="decl_dwidths">
<xsl:text>	subtype DATA_SLICE_</xsl:text><xsl:value-of select="@id"/><xsl:text> is integer range </xsl:text>
	<xsl:choose>
		<xsl:when test="@size"><xsl:value-of select="@size"/></xsl:when>
		<xsl:otherwise><xsl:value-of select="$dwidth"/></xsl:otherwise>
	</xsl:choose><xsl:text>-1 downto 0;
</xsl:text>
	<!-- subtype pio_data_<xsl:value-of select="@id"/>_t is 
		<xsl:value-of select="$iface_type"/>(DATA_SLICE_<xsl:value-of select="@id"/>);
	-->
</xsl:template>


<xsl:template match="my:item" mode="perio_select">
	ce_<xsl:value-of select="@name"/> &lt;= ce when to_integer(perio_unit) = SELECT_<xsl:value-of select="@name"/>
		else '0';
</xsl:template>

</xsl:stylesheet>
