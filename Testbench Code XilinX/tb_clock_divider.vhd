LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY tb_clock_divider IS
END tb_clock_divider;

ARCHITECTURE behavior OF tb_clock_divider IS

    COMPONENT clock_divider
    PORT(
        CLKEXT : IN  std_logic;
        CLKINT : OUT std_logic
    );
    END COMPONENT;

    signal CLKEXT : std_logic := '0';
    signal CLKINT : std_logic;

    -- 1 / 1.8432 MHz = 542.535 ns
    constant CLKEXT_period : time := 542.535 ns;

BEGIN

    uut: clock_divider
    PORT MAP (
        CLKEXT => CLKEXT,
        CLKINT => CLKINT
    );

    clk_process : process
    begin
        while true loop
            CLKEXT <= '0';
            wait for CLKEXT_period/2;
            CLKEXT <= '1';
            wait for CLKEXT_period/2;
        end loop;
    end process;

    stim_proc : process
    begin
        wait for 30 us;
        assert false report "Clock divider test completed. CLKINT should be CLKEXT divided by 4." severity failure;
    end process;

END;
