library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_bcd_decoder is
end tb_bcd_decoder;

architecture behavior of tb_bcd_decoder is

    component bcd_decoder
        Port (
            bcd_in  : in  STD_LOGIC_VECTOR(3 downto 0);
            seg_out : out STD_LOGIC_VECTOR(6 downto 0)
        );
    end component;

    signal bcd_in  : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal seg_out : STD_LOGIC_VECTOR(6 downto 0);

begin

    uut: bcd_decoder
        port map (
            bcd_in  => bcd_in,
            seg_out => seg_out
        );

    stim_proc: process
    begin
        bcd_in <= "0000"; wait for 20 ns; -- 0
        bcd_in <= "0001"; wait for 20 ns; -- 1
        bcd_in <= "0010"; wait for 20 ns; -- 2
        bcd_in <= "0011"; wait for 20 ns; -- 3
        bcd_in <= "0100"; wait for 20 ns; -- 4
        bcd_in <= "0101"; wait for 20 ns; -- 5
        bcd_in <= "0110"; wait for 20 ns; -- 6
        bcd_in <= "0111"; wait for 20 ns; -- 7
        bcd_in <= "1000"; wait for 20 ns; -- 8
        bcd_in <= "1001"; wait for 20 ns; -- 9
        bcd_in <= "1010"; wait for 20 ns; -- invalid input
        wait;
    end process;

end behavior;