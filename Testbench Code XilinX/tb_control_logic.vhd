library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_control_logic is
end tb_control_logic;

architecture Behavioral of tb_control_logic is

    signal CLKINT      : STD_LOGIC := '0';
    signal CLR_N       : STD_LOGIC := '0';
    signal SERIAL_IN   : STD_LOGIC := '1';

    signal SHIFT_EN    : STD_LOGIC;
    signal BYTE_DONE   : STD_LOGIC;
    signal STATE_DBG   : STD_LOGIC_VECTOR(1 downto 0);
    signal BIT_CNT_DBG : STD_LOGIC_VECTOR(3 downto 0);

    constant CLK_PERIOD : time := 20 ns;  -- simulation clock only
    constant BIT_TICKS  : integer := 8;   -- 8x baud oversampling
    constant BIT_PERIOD : time := CLK_PERIOD * BIT_TICKS;

    signal shift_count : integer := 0;
    signal done_count  : integer := 0;

    procedure SEND_UART_BYTE(
        signal RX_LINE : out STD_LOGIC;
        constant DATA  : in  STD_LOGIC_VECTOR(7 downto 0)
    ) is
    begin
        -- idle
        RX_LINE <= '1';
        wait for BIT_PERIOD;

        -- start bit
        RX_LINE <= '0';
        wait for BIT_PERIOD;

        -- 8 data bits, LSB first
        for i in 0 to 7 loop
            RX_LINE <= DATA(i);
            wait for BIT_PERIOD;
        end loop;

        -- stop bit
        RX_LINE <= '1';
        wait for BIT_PERIOD;

        -- small gap before next frame
        RX_LINE <= '1';
        wait for BIT_PERIOD;
    end procedure;

begin

    uut: entity work.control_logic
        port map (
            CLKINT      => CLKINT,
            CLR_N       => CLR_N,
            SERIAL_IN   => SERIAL_IN,
            SHIFT_EN    => SHIFT_EN,
            BYTE_DONE   => BYTE_DONE,
            STATE_DBG   => STATE_DBG,
            BIT_CNT_DBG => BIT_CNT_DBG
        );

    -- clock generation
    clk_process : process
    begin
        while true loop
            CLKINT <= '0';
            wait for CLK_PERIOD / 2;
            CLKINT <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    -- monitor pulses
    monitor_process : process(CLKINT)
    begin
        if rising_edge(CLKINT) then
            if SHIFT_EN = '1' then
                shift_count <= shift_count + 1;
            end if;

            if BYTE_DONE = '1' then
                done_count <= done_count + 1;
            end if;
        end if;
    end process;

    -- stimulus
    stim_proc : process
    begin
        -- reset
        CLR_N <= '0';
        SERIAL_IN <= '1';
        wait for 5 * CLK_PERIOD;

        CLR_N <= '1';
        wait for 2 * BIT_PERIOD;

        -------------------------------------------------
        -- Test 1: send one byte, e.g. x"45"
        -------------------------------------------------
        SEND_UART_BYTE(SERIAL_IN, x"45");
        wait for 3 * BIT_PERIOD;

        assert shift_count = 8
            report "Test 1 failed: SHIFT_EN did not pulse 8 times"
            severity error;

        assert done_count = 1
            report "Test 1 failed: BYTE_DONE did not pulse once"
            severity error;

        -------------------------------------------------
        -- Test 2: send another byte, e.g. x"27"
        -- cumulative totals should now be 16 and 2
        -------------------------------------------------
        SEND_UART_BYTE(SERIAL_IN, x"27");
        wait for 3 * BIT_PERIOD;

        assert shift_count = 16
            report "Test 2 failed: cumulative SHIFT_EN count is not 16"
            severity error;

        assert done_count = 2
            report "Test 2 failed: cumulative BYTE_DONE count is not 2"
            severity error;

        report "Control logic block test passed." severity note;
        wait;
    end process;

end Behavioral;