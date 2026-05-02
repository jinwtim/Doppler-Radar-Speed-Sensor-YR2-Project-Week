library ieee;
use ieee.std_logic_1164.all;

entity tb_shift_register is
end tb_shift_register;

architecture behavior of tb_shift_register is

    component shift_register
        port (
            clk       : in  std_logic;
            clr       : in  std_logic;
            ce        : in  std_logic;
            serial_in : in  std_logic;
            q         : out std_logic_vector(7 downto 0)
        );
    end component;

    signal clk       : std_logic := '0';
    signal clr       : std_logic := '0';
    signal ce        : std_logic := '0';
    signal serial_in : std_logic := '0';
    signal q         : std_logic_vector(7 downto 0);

    constant clk_period : time := 20 ns;

begin

    uut: shift_register
        port map (
            clk       => clk,
            clr       => clr,
            ce        => ce,
            serial_in => serial_in,
            q         => q
        );

    -- Clock generation
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for clk_period/2;
            clk <= '1';
            wait for clk_period/2;
        end loop;
    end process;

    -- Stimulus process
    stim_proc: process
    begin
        -- Reset the shift register
        clr <= '1';
        ce  <= '0';
        serial_in <= '0';
        wait for 2 * clk_period;

        clr <= '0';
        ce  <= '1';

        -- Send byte 00110010 LSB first
        -- Bit order applied: 0 1 0 0 1 1 0 0
        serial_in <= '0'; wait for clk_period; -- b0
        serial_in <= '1'; wait for clk_period; -- b1
        serial_in <= '0'; wait for clk_period; -- b2
        serial_in <= '0'; wait for clk_period; -- b3
        serial_in <= '1'; wait for clk_period; -- b4
        serial_in <= '1'; wait for clk_period; -- b5
        serial_in <= '0'; wait for clk_period; -- b6
        serial_in <= '0'; wait for clk_period; -- b7

        wait for clk_period;

        assert q = "00110010"
            report "Test failed: q does not match expected value 00110010"
            severity error;

        report "Test passed: q = 00110010" severity note;

        wait;
    end process;

end behavior;