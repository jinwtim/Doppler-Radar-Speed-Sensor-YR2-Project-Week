library ieee;
use ieee.std_logic_1164.all;

entity shift_register is
    port (
        clk       : in  std_logic;
        clr       : in  std_logic;  -- active high clear
        ce        : in  std_logic;  -- clock enable
        serial_in : in  std_logic;
        q         : out std_logic_vector(7 downto 0)
    );
end shift_register;

architecture Behavioral of shift_register is
    signal reg_data : std_logic_vector(7 downto 0) := (others => '0');
begin

    process(clk, clr)
    begin
        if clr = '1' then
            reg_data <= (others => '0');
        elsif rising_edge(clk) then
            if ce = '1' then
                -- shift right, new serial bit enters MSB
                reg_data <= serial_in & reg_data(7 downto 1);
            end if;
        end if;
    end process;

    q <= reg_data;

end Behavioral;