----------------------------------------------------------------------------------
-- Company: 
-- Engineer: M.M. Cheraghi
-- 
-- Create Date:    20:27:18 03/10/2024 
-- Design Name: 
-- Module Name:    sram_controller - Behavioral 
-- Project Name: 
-- Target Devices: IS61WV5128BLL-10TI
-- Tool versions: 1.0
-- Description: This module is intented to work on Posedge development board with Spartan-6 FPGA working in 24 MHz.
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sram_controller is

-- SRAM Controller
	port
	 (
	   -- Wishbone bus interface (available if MEM_EXT_EN = true) --
		xbus_adr_i       	: in   std_ulogic_vector(18 downto 0); -- address
		xbus_dat_o       	: out  std_ulogic_vector(31 downto 0) := (others => '0'); -- read data
		xbus_dat_i       	: in   std_ulogic_vector(31 downto 0); -- write data
		xbus_we_i        	: in   std_ulogic; -- read/write
		xbus_sel_i       	: in   std_ulogic_vector(03 downto 0); -- byte enable
		xbus_stb_i       	: in   std_ulogic; -- strobe
		xbus_cyc_i       	: in   std_ulogic; -- valid cycle
		xbus_ack_o       	: out  std_ulogic := '0'; -- transfer acknowledge
		xbus_err_o       	: out  std_ulogic := '0'; -- transfer errors
		-- SRAM signals --
		ADDR_out		: out	std_ulogic_vector(18 downto 0) := (others => 'X');
		DATApin			: inout	std_ulogic_vector(7 downto 0);
		Sram_ce			: out	std_logic;
		Sram_oe			: out	std_logic;
		Sram_we			: out	std_logic;
		-- General signals --
		clk_i            	: in  std_logic;       -- global clock, rising edge
		rstn_i           	: in  std_logic        -- global reset, low-active, async
	 );

end entity;

architecture Behavioral of sram_controller is
	-- 1- There are Four states for wrinting and Four states for reading. Each write/read state takes two cycles 
	-- to fullfill SRAM timing constraints (The delay_signal is used to delay state machine in each write/read state).
	
	-- 2- The target SRAM is byte accessible and we should devide word access to byte access. Master specifies required bytes
	-- with 4-bit xbus_sel_i signal. The machine state traverses states based on this select signal.
	
	-- 3- This module hardwires xbus_err_o to '0' and further improvement should handle error situations. 
	
	type 	 Sram_State is  (IDLE, READ0, READ1, READ2, READ3, WRITE0, WRITE1, WRITE2, WRITE3);
	signal pr_state   	 	: Sram_State := IDLE;
	signal xbus_dat_i_reg 		: std_ulogic_vector(31 downto 0) := (others => '0'); -- write data
	signal xbus_adr_i_reg 		: unsigned(18 downto 0) := (others => '0'); -- write data address
	
	signal sel_reg 		 	: std_ulogic_vector(03 downto 0) := (others => '0'); -- write data address
	signal delay_signal 	 	: std_logic := '0'; -- write data address
	signal xbus_dat_o_tmp 		: std_ulogic_vector(31 downto 0) := (others => '0'); -- write data address
	signal DATApin_TX		: std_ulogic_vector(7 downto 0) := (others => 'Z');
	signal Tri_en 	 		: std_logic := '0'; -- write data address
	
begin
	

	
	DATApin 	<= DATApin_TX when Tri_en = '1' else (others => 'Z');
	
	process (clk_i, rstn_i)
	begin
		if(rstn_i = '0') then
			pr_state		<= IDLE;
			xbus_dat_i_reg     	<= (others => '0');
			xbus_adr_i_reg     	<= (others => '0');
			sel_reg   		<= (others => '0');
			DATApin_TX    		<= (others => 'Z');
			delay_signal 		<= '0';
			Tri_en			<= '0';
			xbus_ack_o 		<= '0';
			
			Sram_we    		<= '1';
			Sram_oe    		<= '1';
    	    		Sram_ce 		<= '1'; 
			
						
		elsif (clk_i'event and clk_i = '1') then
		   	Sram_ce 		<= '0';
			
			case pr_state is 
				when IDLE =>
		                    if (delay_signal = '1')then
		                        delay_signal        <= '0';
		                        Sram_oe    	        <= '1';
		                    else
					xbus_dat_i_reg 		<= xbus_dat_i;
					xbus_adr_i_reg 		<= unsigned(xbus_adr_i);
					sel_reg   		<= xbus_sel_i;
					DATApin_TX    		<= (others => '0');
					xbus_dat_o_tmp 		<= (others => '0');
		                  	xbus_dat_o 	        <= (others => '0');
					delay_signal 		<= '0';
								
					Tri_en 			<= '0';
					Sram_we    		<= '1';
					Sram_oe    		<= '1';
					xbus_ack_o 		<= '0';
								
					if ((xbus_cyc_i and xbus_stb_i) = '1') then
						if (xbus_we_i = '1') then
							-- valid write access
							-- Decide on Byte Enable --
							if(sel_reg(0) = '1')then
								pr_state <= WRITE0;
							elsif(sel_reg(1) = '1')then
								pr_state <= WRITE1;
							elsif(sel_reg(2) = '1')then
								pr_state <= WRITE2;
							elsif(sel_reg(3) = '1')then
								pr_state <= WRITE3;
							end if;
							---------------------------
										
						else
							-- valid read access
							-- Decide on Byte Enable --
							if(sel_reg(0) = '1')then
								pr_state <= READ0;
							elsif(sel_reg(1) = '1')then
								pr_state <= READ1;
							elsif(sel_reg(2) = '1')then
								pr_state <= READ2;
							elsif(sel_reg(3) = '1')then
								pr_state <= READ3;
							end if;
							---------------------------
										
						end if;
					else
						pr_state 	<= IDLE;
					end if;
		                    end if;
		--------------------------------------
				when READ0 =>
					delay_signal 		<= '1';
					ADDR_out 		<= std_ulogic_vector(xbus_adr_i_reg);
					
					Tri_en			<= '0';
					Sram_we    		<= '1';
					Sram_oe    		<= '0';
					
					if(delay_signal = '1')then
						xbus_dat_o_tmp(7 downto 0) <= DATApin;
						delay_signal		<= '0';
						-- Decide on Byte Enable --
						if(sel_reg(1) = '1')then
							pr_state <= READ1;
						elsif(sel_reg(2) = '1')then
							pr_state <= READ2;
						elsif(sel_reg(3) = '1')then
							pr_state <= READ3;
						else
							pr_state        <= IDLE;
							xbus_ack_o 	<= '1';
                     					delay_signal	<= '1';
                     					xbus_dat_o 	<= X"000000" & DATApin;
						end if;
						---------------------------
						
					end if;
		--------------------------------------
				when READ1 =>
					delay_signal 	<= '1';
					ADDR_out 		<= std_ulogic_vector(xbus_adr_i_reg + 1);
					
					Tri_en			<= '0';
					Sram_we    		<= '1';
					Sram_oe    		<= '0';
					
					if(delay_signal = '1')then
						xbus_dat_o_tmp(15 downto 8) <= DATApin;
						delay_signal		<= '0';
						-- Decide on Byte Enable --
						if(sel_reg(2) = '1')then
							pr_state <= READ2;
						elsif(sel_reg(3) = '1')then
							pr_state <= READ3;
						else
							pr_state        <= IDLE;
							xbus_ack_o 	<= '1';
                     					delay_signal	<= '1';
                     					xbus_dat_o 	<= X"0000" & DATApin & xbus_dat_o_tmp(7 downto 0);
						end if;
						---------------------------
						
					end if;
		--------------------------------------
				when READ2 =>
					delay_signal 	<= '1';
					ADDR_out 		<= std_ulogic_vector(xbus_adr_i_reg + 2);
					
					Tri_en			<= '0';
					Sram_we    		<= '1';
					Sram_oe    		<= '0';
					
					if(delay_signal = '1')then
						xbus_dat_o_tmp(23 downto 16) <= DATApin;
						delay_signal		<= '0';
						-- Decide on Byte Enable --
						if(sel_reg(3) = '1')then
							pr_state <= READ3;
						else
							pr_state        <= IDLE;
							xbus_ack_o 	<= '1';
                     					delay_signal	<= '1';
                     					xbus_dat_o 	<= X"00" & DATApin & xbus_dat_o_tmp(15 downto 0);
						end if;
						---------------------------
						
					end if;
		--------------------------------------
				when READ3 =>
					delay_signal 	<= '1';
					ADDR_out 		<= std_ulogic_vector(xbus_adr_i_reg + 3);
					
					Tri_en			<= '0';
					Sram_we    		<= '1';
					Sram_oe    		<= '0';
					
					if(delay_signal = '1')then
						xbus_dat_o_tmp(31 downto 24) <= DATApin;
						delay_signal		<= '0';
						
						pr_state   	<= IDLE;
						xbus_ack_o 	<= '1';
			                  	delay_signal	<= '1';
			                  	xbus_dat_o 	<= DATApin & xbus_dat_o_tmp(23 downto 0);
					end if;
		--------------------------------------
				when WRITE0 =>
					delay_signal 	<= '1';
					ADDR_out 		<= std_ulogic_vector(xbus_adr_i_reg);
					DATApin_TX    	<= xbus_dat_i_reg(7 downto 0);
					Sram_we    		<= '0';
					Tri_en			<= '1';
					Sram_oe    		<= '1';
					
					if(delay_signal = '1')then
						Sram_we    			<= '1';
						delay_signal		<= '0';
						-- Decide on Byte Enable --
						if(sel_reg(1) = '1')then
							pr_state <= WRITE1;
						elsif(sel_reg(2) = '1')then
							pr_state <= WRITE2;
						elsif(sel_reg(3) = '1')then
							pr_state <= WRITE3;
						else
							pr_state   		<= IDLE;
							xbus_ack_o 		<= '1';
							xbus_dat_o 		<= xbus_dat_i_reg;
                     					delay_signal		<= '1';
						end if;
						---------------------------
					end if;
		--------------------------------------
				when WRITE1 =>
					delay_signal 	<= '1';
					ADDR_out 		<= std_ulogic_vector(xbus_adr_i_reg + 1);
					DATApin_TX    	<= xbus_dat_i_reg(15 downto 8);
					Sram_we    		<= '0';
					Tri_en			<= '1';
					Sram_oe    		<= '1';
					
					
					if(delay_signal = '1')then
						Sram_we    			<= '1';
						delay_signal		<= '0';
						-- Decide on Byte Enable --
						if(sel_reg(2) = '1')then
							pr_state <= WRITE2;
						elsif(sel_reg(3) = '1')then
							pr_state <= WRITE3;
						else
							pr_state   			<= IDLE;
							xbus_ack_o 			<= '1';
							xbus_dat_o 			<= xbus_dat_i_reg;
                     					delay_signal			<= '1';
						end if;
						---------------------------
					end if;
		--------------------------------------
				when WRITE2 =>
					delay_signal 	<= '1';
					ADDR_out 		<= std_ulogic_vector(xbus_adr_i_reg + 2);
					DATApin_TX    	<= xbus_dat_i_reg(23 downto 16);
					Sram_we    		<= '0';
					Tri_en			<= '1';
					Sram_oe    		<= '1';
					
					
					if(delay_signal = '1')then
						Sram_we    			<= '1';
						delay_signal		<= '0';
						-- Decide on Byte Enable --
						if(sel_reg(3) = '1')then
							pr_state <= WRITE3;
						else
							pr_state   			<= IDLE;
							xbus_ack_o 			<= '1';
							xbus_dat_o 			<= xbus_dat_i_reg;
                     					delay_signal			<= '1';
						end if;
						---------------------------
					end if;
		--------------------------------------
				when WRITE3 =>
					delay_signal 	<= '1';
					ADDR_out 		<= std_ulogic_vector(xbus_adr_i_reg + 3);
					DATApin_TX    	<= xbus_dat_i_reg(31 downto 24);
					Sram_we    		<= '0';
					Tri_en			<= '1';
					Sram_oe    		<= '1';
					
					
					if(delay_signal = '1')then
						xbus_dat_o_tmp <= xbus_dat_i_reg;
						Sram_we    			<= '1';
						delay_signal			<= '0';
						pr_state   			<= IDLE;
						xbus_ack_o 			<= '1';
						xbus_dat_o 			<= xbus_dat_i_reg;
                  				delay_signal			<= '1';
					end if;
		--------------------------------------
						
			end case;
		
		end if;
	end process;
	

end Behavioral;
