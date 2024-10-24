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
-- 1- There are Four states for wrinting and Four states for reading. Each write/read state takes two cycles 
-- to fullfill SRAM timing constraints (The delay_signal is used to delay state machine in each write/read state).
-- 2- The target SRAM is byte accessible and we should devide word access to byte access. Master specifies required bytes
-- with 4-bit xbus_sel_i signal. The machine state traverses states based on this select signal.
-- 3- This module hardwires xbus_err_o to '0' and further improvement should handle error situations.

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
		xbus_dat_i       	: in   std_ulogic_vector(31 downto 0); -- write data
		xbus_we_i        	: in   std_ulogic; -- read/write
		xbus_sel_i       	: in   std_ulogic_vector(03 downto 0); -- byte enable
		xbus_stb_i       	: in   std_ulogic; -- strobe
		xbus_cyc_i       	: in   std_ulogic; -- valid cycle
		xbus_dat_o       	: out  std_ulogic_vector(31 downto 0) := (others => '0'); -- read data
		xbus_ack_o       	: out  std_ulogic := '0'; -- transfer acknowledge
		xbus_err_o       	: out  std_ulogic := '0'; -- transfer errors
		-- SRAM signals --
		ADDR_out		      : out	std_ulogic_vector(18 downto 0) := (others => 'X');
		DATApin			   : inout	std_ulogic_vector(7 downto 0);
		Sram_ce			   : out	std_logic;
		Sram_oe			   : out	std_logic;
		Sram_we			   : out	std_logic;
		-- General signals --
		clk_i            	: in  std_logic;       -- global clock, rising edge
		rstn_i           	: in  std_logic        -- global reset, low-active, async
	 );

end entity;

architecture Behavioral of sram_controller is 
	
	type 	 controller_State is  (IDLE, D_READ1, D_READ2, D_READ3, D_WRITE1, D_WRITE2, D_WRITE3);
	signal state   	 	      : controller_State := IDLE;
	signal xbus_dat_i_reg 		: std_ulogic_vector(31 downto 0) := (others => '0'); -- write data
	signal xbus_adr_i_reg 		: unsigned(18 downto 0) := (others => '0'); -- write data address
	
	signal delay_signal 	 		: std_logic := '0'; -- write data address
	signal xbus_dat_o_tmp 		: std_ulogic_vector(31 downto 00) := (others => '0'); -- write data address
	signal DATApin_TX				: std_ulogic_vector(07 downto 00) := (others => 'Z');
	signal Tri_en 	 				: std_logic := '0'; -- write data address
	signal sel_reg       		: std_ulogic_vector(03 downto 00) := (others => '0');
	
	-------- Sram => signals --------
	signal		srd				:std_logic:='0';
	signal		wrt				:std_logic:='0';
	signal		Done				:std_logic:='0';
	signal		ADDR_in			:std_ulogic_vector(18 downto 0); 
	signal		DATA_in			:std_ulogic_vector(7 downto 0); 
	signal		DATAout			:std_ulogic_vector(7 downto 0); 
	signal		d_out				:std_ulogic_vector(7 downto 0); 

	-- ### SRAM controller core
	component Sram is

	port ( clk		:in	STD_LOGIC;	      
	       rd		:in	STD_LOGIC;
	       wrt		:in	STD_LOGIC;
	       
	       DATApin		:inout	std_ulogic_vector(7 downto 0);	
		    DATAin		:in		std_ulogic_vector(7 downto 0):=x"00";
		    DATAout		:out		std_ulogic_vector(7 downto 0):=x"00";
	       ADDR_out	:out		std_ulogic_vector(18 downto 0);
		    ADDR_in		:in		std_ulogic_vector(18 downto 0); 
		   
	       Done			:out	STD_LOGIC;
	       
	       Sram_ce		:out	std_logic;	
	       Sram_oe		:out	std_logic;
	       sram_we		:out	std_logic;
			 
			 rstn_i     : in  std_logic        -- global reset, low-active, async
	       
	
		);
end component;
	
begin
	
	Inst_sram: sram PORT MAP(
						DATAout => DATAout,
						DATApin => DATApin,
						DATAin => DATA_in,
						clk => clk_i,
						rd  => srd,
						wrt => wrt,
						ADDR_out => ADDR_out,
						ADDR_in	=>  ADDR_in	,
						Done => Done,
						Sram_ce => Sram_ce,
						Sram_oe => Sram_oe,
						Sram_we => Sram_we,
						rstn_i  => rstn_i
						);


	process (clk_i, rstn_i)
	begin
		if(rstn_i = '0') then
		
			state		 					<= IDLE;
			sel_reg   					<= B"0000";
			xbus_ack_o 					<= '0';
			xbus_err_o  				<= '0';
			ADDR_in						<= (others=>'0');
			DATA_in						<= (others=>'0');
			xbus_dat_o(7 downto 0) 	<= (others=>'0');
			
		elsif (clk_i'event and clk_i = '1') then
		
			ADDR_in						<= (others=>'0');
			DATA_in						<= (others=>'0');
			xbus_dat_o(7 downto 0) 	<= (others=>'0');
			xbus_ack_o 					<= '0';
			xbus_err_o  				<= '0';
		   	
			case state is 
			
				-- IDLE state --
				when IDLE =>
					sel_reg   			<= xbus_sel_i;
					wrt 					<= '0';
					srd        			<= '0';
					
					if ((xbus_cyc_i and xbus_stb_i and xbus_we_i) = '1') then -- valid write access
						state 			<= D_WRITE1;
					elsif ((xbus_cyc_i and xbus_stb_i) = '1') then -- valid read access
						state 			<= D_READ1;
					else
						state 			<= IDLE;
					end if;
					
				-- WRITE1 state --
				when D_WRITE1 =>
				if(sel_reg(3)='1')then
						ADDR_in					<= xbus_adr_i(18 downto 02) & B"11";
						DATA_in 					<= xbus_dat_i(31 downto 24);
					elsif(sel_reg(2)='1')then
						ADDR_in					<= xbus_adr_i(18 downto 02) & B"10";
						DATA_in 					<= xbus_dat_i(23 downto 16);
					elsif(sel_reg(1)='1')then
						ADDR_in					<= xbus_adr_i(18 downto 02) & B"01";
						DATA_in 					<= xbus_dat_i(15 downto 08);
					elsif(sel_reg(0)='1')then
						ADDR_in					<= xbus_adr_i(18 downto 02) & B"00";
						DATA_in 					<= xbus_dat_i(07 downto 00);
					end if;
					
					xbus_dat_o	 			<= (others=>'0');
					state 					<= D_WRITE1;
					wrt 						<= '1';
					xbus_err_o				<= '0';
					xbus_ack_o 				<= '0';
							
					if (Done = '1')then
						wrt 					<= '0';
						state 				<= D_WRITE2;
--						xbus_ack_o 			<= '1';
					end if;
				
				-- WRITE2 state --
				when D_WRITE2 =>
					state 				<= D_WRITE3;
					wrt 					<= '0';
					if(sel_reg(3)='1')then
						sel_reg			<= B"0" & sel_reg(2 downto 0);
					elsif(sel_reg(2)='1')then
						sel_reg			<= B"00" & sel_reg(1 downto 0);
					elsif(sel_reg(1)='1')then
						sel_reg			<= B"000" & sel_reg(0);
					elsif(sel_reg(0)='1')then
						sel_reg			<= B"0000";
						xbus_ack_o 		<= '1';
						state 			<= IDLE;
					else
						xbus_ack_o 		<= '1';
						state 			<= IDLE;
					end if;
				-- WRITE3 state --
				when D_WRITE3 =>
					state 				<= D_WRITE1;
				
				-- READ1 state --
				when D_READ1 =>
					if(sel_reg(3)='1')then
						ADDR_in					<= xbus_adr_i(18 downto 2) & B"11";
					elsif(sel_reg(2)='1')then
						ADDR_in					<= xbus_adr_i(18 downto 2) & B"10";
					elsif(sel_reg(1)='1')then
						ADDR_in					<= xbus_adr_i(18 downto 2) & B"01";
					elsif(sel_reg(0)='1')then
						ADDR_in					<= xbus_adr_i(18 downto 2) & B"00";
					end if;
					
					DATA_in					<= (others=>'0');
					state 					<= D_READ1;
					srd        				<= '1';
					xbus_err_o				<= '0';
					xbus_ack_o 				<= '0';
					
					if (Done = '1')then
						srd 					<= '0';
						state 				<= D_READ2;
--						xbus_ack_o 			<= '1';
						
					end if;
				-- READ2 state --
				when D_READ2 =>
					state 					<= D_READ3;
					srd 						<= '0';
					if(sel_reg(3)='1')then
						xbus_dat_o(31 downto 24)	<= DATAout;
						sel_reg							<= B"0" & sel_reg(2 downto 0);
					elsif(sel_reg(2)='1')then
						xbus_dat_o(23 downto 16)	<= DATAout;
						sel_reg							<= B"00" & sel_reg(1 downto 0);
					elsif(sel_reg(1)='1')then
						xbus_dat_o(15 downto 08)	<= DATAout;
						sel_reg							<= B"000" & sel_reg(0);
					elsif(sel_reg(0)='1')then
						xbus_dat_o(07 downto 00)	<= DATAout;
						sel_reg							<= B"0000";
						xbus_ack_o 						<= '1';
						state 							<= IDLE;
					else
						xbus_ack_o 						<= '1';
						state 							<= IDLE;
					end if;
					
				-- READ3 state --
				when D_READ3 =>
					state 					<= D_READ1;
				end case;
			
		end if;
	end process;
	

end Behavioral;





----------------------------------------------------------------------------------
-- Mohsen Sadeghi Moghaddam
-- Sram Component
-- m.sadeghimoghaddam@yahoo.com
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Sram is

	port ( clk		:in	STD_LOGIC;	      
	       rd		:in	STD_LOGIC;
	       wrt		:in	STD_LOGIC;
	       
	       DATApin		:inout	std_ulogic_vector(7 downto 0);	
		    DATAin		:in		std_ulogic_vector(7 downto 0):=x"00";
		    DATAout		:out		std_ulogic_vector(7 downto 0):=x"00";
	       ADDR_out	:out		std_ulogic_vector(18 downto 0);
		    ADDR_in		:in		std_ulogic_vector(18 downto 0); 
		   
	       Done			:out	STD_LOGIC;
	       
	       Sram_ce		:out	std_logic;	
	       Sram_oe		:out	std_logic;
	       Sram_we		:out	std_logic;
			 
			 rstn_i     : in  std_logic        -- global reset, low-active, async
	       
	
		);
end Sram;

------------------------------------------------------------------------
architecture Behavioral of Sram is
		type 	  Sram_State is (S_start,S_Read,S_write,S_wrt_done,S_get,S_finish);
		signal	  pr_state   :Sram_State := S_start;
begin
	ADDR_out <= ADDR_in;
	process (clk, rstn_i)
	begin
		if(rstn_i = '0') then
		
			pr_state		 	<= S_start;
			Done 				<= '0';
			Sram_ce 			<= '1';
			Sram_we 			<= '1';
			Sram_oe 			<= '1';
			DATAout			<= X"00";

		elsif (clk'event and clk = '1') then
			case pr_state is 
			
				when S_start =>
					Done <= '0';
					if (wrt = '1') then
						DATApin <= DATAin;
						Sram_ce <= '0';
						Sram_we <= '0';
						Sram_oe <= '1';
						pr_state <= S_write;
					elsif (rd = '1') then
						DATApin<=(others => 'Z');
						Sram_ce <= '0';
						Sram_we <= '1';
						Sram_oe <= '0';					
						pr_state <= S_Read;
					end if;	
		--------------------------------------
				when S_Read =>
						Sram_ce <= '0';
						Sram_we <= '1';
						Sram_oe <= '0';
						pr_state <= S_get;					
		--------------------------------------
				when S_get =>
						Done <= '1';	
						DATAout <=DATApin;
						pr_state <= S_finish;
		--------------------------------------
				when S_write =>
						DATApin<=DATAin;
						Sram_ce <= '0';
						Sram_we <= '0';
						Sram_oe <= '1';
						pr_state <= S_wrt_done;
		--------------------------------------
				when S_wrt_done =>
						Done <= '1';
						pr_state <= S_finish;
		--------------------------------------
				when S_finish =>
						Sram_ce <= '0';
						Sram_oe <= '1';
						Sram_we <= '1';
					if(rd='0' and wrt='0') then
						pr_state <= S_start;
					end if;
			end case;
		
		end if;
	end process;
end Behavioral;

