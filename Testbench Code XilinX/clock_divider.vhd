library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clock_divider is
    Port (
        CLKEXT  : in  STD_LOGIC;   -- 1.8432 MHz Crystal Oscillator
        CLKINT  : out STD_LOGIC    -- 460.8 kHz, 8x 57,600 baud
    );
end clock_divider;

architecture Behavioral of clock_divider is
    signal clk_pre  : STD_LOGIC := '0';
    signal clk_int_r : STD_LOGIC := '0';
begin

    -- Same divide-by-4 logic used inside the final display_top code.
    p_clkdiv : process(CLKEXT)
    begin
        if rising_edge(CLKEXT) then
            clk_pre <= not clk_pre;
            if clk_pre = '1' then
                clk_int_r <= not clk_int_r;
            end if;
        end if;
    end process p_clkdiv;

    CLKINT <= clk_int_r;

end Behavioral;
