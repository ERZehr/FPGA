----------------------------------------------------------------------------------
-- Company: Zehrforce
-- Engineer: Evan Zehr
-- 
-- Create Date: 08/02/2024 07:02:48 PM
-- Design Name: button_debounce
-- Module Name: button_debounce - rtl
-- Project Name: MISC
-- Target Devices: MISC
-- Tool Versions: Vivado 2024.1
-- Description: Creating a button debounce for initiating transfer via UART. Will not be used in final design. 
-- 
-- Dependencies: None
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity button_debounce is
  port ( 
  clk : in std_logic;
  nrst : in std_logic;
  button_in : in std_logic;
  button_out : inout std_logic
  );
end entity;

architecture rtl of button_debounce is
    signal button_hist : std_logic_vector(7 downto 0) := (others => '0');
begin
    process(clk, nrst)
    begin
        if nrst = '0' then
            button_hist <= (others => '0');
            button_out <= '0';            
        elsif rising_edge(clk)then
            button_hist <= button_hist(6 downto 0) & button_in;
            if button_out = '0' then
                if button_hist = "11111111" then
                    button_out <= '1';
                end if;
            elsif button_out = '1' then
                if button_hist = "00000000" then
                    button_out <= '0';
                end if;
            end if;
        end if;
    end process;
end architecture;
