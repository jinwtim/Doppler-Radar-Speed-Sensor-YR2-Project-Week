library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity display_top is
    Port (
        CLKEXT  : in  STD_LOGIC;   -- 1.8432 MHz Crystal Oscillator
        RXD     : in  STD_LOGIC;   -- From RS-485 Receiver (RO Pin)
        CLR_N   : in  STD_LOGIC;   -- Reset (Tie to 3.3V if no button)
		  
		  -- Segment 1 (Units/Right)
        SEG1_A, SEG1_B, SEG1_C, SEG1_D, SEG1_E, SEG1_F, SEG1_G : out STD_LOGIC;
        -- Segment 2 (Tens/Left)
        SEG2_A, SEG2_B, SEG2_C, SEG2_D, SEG2_E, SEG2_F, SEG2_G : out STD_LOGIC
    );
end display_top;

architecture Behavioral of display_top is
    -- Clock signals
    signal clk_pre  : STD_LOGIC := '0';
    signal CLKINT   : STD_LOGIC := '0'; -- 460,800 Hz (8x Baud Rate)
	 
	 -- UART State Machine
    type uart_state_t is (ST_IDLE, ST_DATA, ST_STOP);
    signal uart_state : uart_state_t := ST_IDLE;

    -- UART Counters and Registers
    signal zero_cnt  : STD_LOGIC_VECTOR(2 downto 0) := "000";
    signal clk_cnt   : STD_LOGIC_VECTOR(2 downto 0) := "000";
    signal bit_cnt   : STD_LOGIC_VECTOR(2 downto 0) := "000";
    signal shift_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	 
	 -- Display Register (Default to "00")
    signal display_r : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

    -- BCD and Segment signals
    signal bcd_tens, bcd_units : STD_LOGIC_VECTOR(3 downto 0);
    signal seg1_bus, seg2_bus  : STD_LOGIC_VECTOR(6 downto 0);

begin

-- Task 13: Clock Divider (Divide by 4)
    p_clkdiv : process(CLKEXT)
    begin
        if rising_edge(CLKEXT) then
            clk_pre <= not clk_pre;
            if clk_pre = '1' then
                CLKINT <= not CLKINT;
            end if;
        end if;
    end process p_clkdiv;
	 
	 -- Tasks 15 & 16: UART Receiver State Machine
    p_uart : process(CLKINT, CLR_N)
    begin
        if CLR_N = '0' then
            uart_state <= ST_IDLE;
            display_r  <= (others => '0'); -- Defaults to "00" on Clear
            zero_cnt   <= "000";
        elsif rising_edge(CLKINT) then
		  case uart_state is
                when ST_IDLE =>
                    clk_cnt <= "000";
                    bit_cnt <= "000";
                    if RXD = '0' then -- Start bit detected
                        zero_cnt <= zero_cnt + 1;
                        if zero_cnt = "011" then -- Sample middle of start bit
                            zero_cnt   <= "000";
                            uart_state <= ST_DATA;
                        end if;
								
								else
                        zero_cnt <= "000";
                    end if;

                when ST_DATA =>
                    clk_cnt <= clk_cnt + 1;
                    if clk_cnt = "111" then -- Sample middle of every data bit
                        shift_reg <= RXD & shift_reg(7 downto 1);
                        bit_cnt   <= bit_cnt + 1;
                        if bit_cnt = "111" then
                            uart_state <= ST_STOP;
                        end if;
                    end if;
						  
						  when ST_STOP =>
                    clk_cnt <= clk_cnt + 1;
                    if clk_cnt = "111" then
                        if RXD = '1' then -- Valid Stop bit confirmed
                            display_r <= shift_reg; -- Update display in real-time
                        end if;
                        uart_state <= ST_IDLE;
                    end if;
            end case;
        end if;
    end process p_uart;
	 
	 -- Task 14: BCD Extraction
    bcd_tens  <= display_r(7 downto 4);
    bcd_units <= display_r(3 downto 0);

    -- BCD to 7-Segment Decoder (Common Anode: '0' is ON)
    process(bcd_units) begin
        case bcd_units is
            when "0000" => seg1_bus <= "0000001"; -- 0
            when "0001" => seg1_bus <= "1001111"; -- 1
            when "0010" => seg1_bus <= "0010010"; -- 2
            when "0011" => seg1_bus <= "0000110"; -- 3
				when "0100" => seg1_bus <= "1001100"; -- 4
            when "0101" => seg1_bus <= "0100100"; -- 5
            when "0110" => seg1_bus <= "0100000"; -- 6
            when "0111" => seg1_bus <= "0001111"; -- 7
            when "1000" => seg1_bus <= "0000000"; -- 8
            when "1001" => seg1_bus <= "0000100"; -- 9
            when others => seg1_bus <= "1111111"; -- OFF
        end case;
    end process;
	 
	 process(bcd_tens) begin
        case bcd_tens is
            when "0000" => seg2_bus <= "0000001";
            when "0001" => seg2_bus <= "1001111";
            when "0010" => seg2_bus <= "0010010";
            when "0011" => seg2_bus <= "0000110";
            when "0100" => seg2_bus <= "1001100";
            when "0101" => seg2_bus <= "0100100";
				when "0110" => seg2_bus <= "0100000";
            when "0111" => seg2_bus <= "0001111";
            when "1000" => seg2_bus <= "0000000";
            when "1001" => seg2_bus <= "0000100";
            when others => seg2_bus <= "1111111";
        end case;
    end process;

    -- Final Signal Assignment
    (SEG1_A, SEG1_B, SEG1_C, SEG1_D, SEG1_E, SEG1_F, SEG1_G) <= seg1_bus;
    (SEG2_A, SEG2_B, SEG2_C, SEG2_D, SEG2_E, SEG2_F, SEG2_G) <= seg2_bus;

end Behavioral;