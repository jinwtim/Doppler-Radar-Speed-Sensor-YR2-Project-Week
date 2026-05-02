library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_logic is
    Port (
        CLKINT      : in  STD_LOGIC;  -- 8x baud clock
        CLR_N       : in  STD_LOGIC;  -- active-low reset
        SERIAL_IN   : in  STD_LOGIC;  -- UART RX line

        SHIFT_EN    : out STD_LOGIC;  -- pulse to shift register CE
        BYTE_DONE   : out STD_LOGIC;  -- pulse when full byte received

        STATE_DBG   : out STD_LOGIC_VECTOR(1 downto 0);
        BIT_CNT_DBG : out STD_LOGIC_VECTOR(3 downto 0)
    );
end control_logic;

architecture Behavioral of control_logic is

    type uart_state_t is (ST_IDLE, ST_DATA, ST_STOP);
    signal uart_state : uart_state_t := ST_IDLE;

    signal zero_cnt : unsigned(2 downto 0) := (others => '0'); -- start-bit detector
    signal clk_cnt  : unsigned(2 downto 0) := (others => '0'); -- counts 0 to 7
    signal bit_cnt  : unsigned(3 downto 0) := (others => '0'); -- counts 8 data bits

begin

    process(CLKINT, CLR_N)
    begin
        if CLR_N = '0' then
            uart_state <= ST_IDLE;
            zero_cnt   <= (others => '0');
            clk_cnt    <= (others => '0');
            bit_cnt    <= (others => '0');
            SHIFT_EN   <= '0';
            BYTE_DONE  <= '0';

        elsif rising_edge(CLKINT) then
            -- default outputs each clock
            SHIFT_EN  <= '0';
            BYTE_DONE <= '0';

            case uart_state is

                when ST_IDLE =>
                    clk_cnt <= (others => '0');
                    bit_cnt <= (others => '0');

                    if SERIAL_IN = '0' then
                        zero_cnt <= zero_cnt + 1;

                        -- 4 consecutive low samples -> valid start detected
                        if zero_cnt = "011" then
                            zero_cnt   <= (others => '0');
                            clk_cnt    <= (others => '0');
                            uart_state <= ST_DATA;
                        end if;
                    else
                        zero_cnt <= (others => '0');
                    end if;

                when ST_DATA =>
                    if clk_cnt = "111" then
                        clk_cnt   <= (others => '0');
                        SHIFT_EN  <= '1';  -- sample/shift this data bit

                        if bit_cnt = "0111" then
                            uart_state <= ST_STOP;
                        else
                            bit_cnt <= bit_cnt + 1;
                        end if;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                when ST_STOP =>
                    if clk_cnt = "111" then
                        clk_cnt <= (others => '0');

                        if SERIAL_IN = '1' then
                            BYTE_DONE <= '1';  -- valid stop bit
                        end if;

                        uart_state <= ST_IDLE;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

            end case;
        end if;
    end process;

    -- debug outputs for simulation
    with uart_state select
        STATE_DBG <= "00" when ST_IDLE,
                     "01" when ST_DATA,
                     "10" when ST_STOP,
                     "11" when others;

    BIT_CNT_DBG <= std_logic_vector(bit_cnt);

end Behavioral;