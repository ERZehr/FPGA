----------------------------------------------------------------------------------
-- Company: Zehrforce
-- Engineer: Evan Zehr
-- 
-- Create Date: 08/02/2024 09:57:10 PM
-- Design Name: UART_tx
-- Module Name: UART_tx - rtl
-- Project Name: UART
-- Target Devices: MISC
-- Tool Versions: Vivado 2024.1
-- Description: 
-- 
-- Dependencies: None
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_tx is
    generic(
        clk_in    : integer := 100000000; -- 100MHZ
        baud_rate : integer := 9600;
        word_size : integer := 8;
        parity    : integer := 0; -- 0 no parity. 1 odd parity, 2 even parity
        stop_bits : integer := 1  -- 1 or 2 stop bits
    );
    port ( 
        i_clk                : in std_logic;
        i_nrst               : in std_logic;
        i_data_in_tx         : in std_logic_vector(word_size-1 downto 0);
        i_start              : in std_logic;
        o_tx_data            : out std_logic;
        o_tx_active          : out std_logic;
        o_tx_done            : out std_logic
    );
end UART_tx;

architecture rtl of UART_tx is
    constant clks_per_bit : integer := clk_in/baud_rate; -- number of clks per bit write
    
    type state_mne is (s_Idle, s_Start, s_Transmit, s_Parity, s_Stop, s_Cleanup); -- state machine initiation
    signal cur_state      : state_mne := s_Idle; -- current state
    
    signal clk_counter    : integer range 0 to clks_per_bit := 0;
    signal bit_counter    : integer range 0 to word_size := 0;
    signal r_tx_data      : std_logic_vector(word_size-1 downto 0):= (others => '0');
    signal r_tx_done      : std_logic := '0';
    signal one_count      : integer range 0 to word_size := 0;
    signal even_odd       : integer range 1 to 2 := 1;
    
begin
    process(i_clk, i_nrst)
    begin
        if rising_edge(i_clk) then
            if i_nrst = '0' then -- the reset case
                o_tx_data <= '1'; 
                o_tx_active <= '0';
                clk_counter <= 0;
                bit_counter <= 0;
                r_tx_data <= (others => '0');
                r_tx_done <= '0';
                one_count <= 0;
                even_odd <= 1;
                cur_state <= s_Idle;
                
            elsif i_nrst = '1' then -- if out of reset
                case cur_state is
                    when s_Idle => -- idle state
                        o_tx_active <= '0';
                        o_tx_data <= '1';
                        clk_counter <= 0;
                        bit_counter <= 0;
                        --r_tx_data <= (others => '0');
                        r_tx_done <= '0';
                        clk_counter <= 0;
                        bit_counter <= 0;
                        if i_start = '1' then
                            r_tx_data <= i_data_in_tx;
                            cur_state <= s_Start;
                        else
                            cur_state <= s_Idle;
                        end if;
                        
                    when s_Start => -- start bit state
                        o_tx_active <= '1';
                        o_tx_data <= '0';
                        if clk_counter < clks_per_bit then
                            clk_counter <= clk_counter + 1;
                            cur_state <= s_Start;
                        else
                            clk_counter <= 0;
                            cur_state <= s_Transmit;
                        end if;
                        
                    when s_Transmit => -- word transmit state
                        o_tx_data <= r_tx_data(bit_counter);
                        if clk_counter < clks_per_bit then
                            clk_counter <= clk_counter + 1;
                            cur_state <= s_Transmit;
                        else
                            clk_counter <= 0;
                            if bit_counter < word_size-1 then
                                bit_counter <= bit_counter + 1;
                                cur_state <= s_Transmit;
                            else
                                bit_counter <= 0;
                                cur_state <= s_Parity;
                            end if;
                        end if;
                        
                    when s_Parity => -- parity state
                        case parity is 
                            when 0 => -- no parity
                                 cur_state <= s_Stop;
                                
                            when 1 => -- odd parity
                                one_count <= 0;
                                for i in r_tx_data'range loop
                                    if r_tx_data(i) = '1' then
                                        one_count <= one_count + 1;
                                    end if;
                                 end loop;
                                 if (one_count mod 2 = 1) then
                                     even_odd <= 1; -- Odd number of 1's
                                 else
                                     even_odd <= 2; -- Even number of 1's
                                 end if;
                                 
                                 if even_odd = 1 then
                                     o_tx_data <= '0';
                                 else 
                                     o_tx_data <= '1';
                                 end if;
                                
                            when 2 => -- even parity
                                one_count <= 0;
                                for i in r_tx_data'range loop
                                    if r_tx_data(i) = '1' then
                                        one_count <= one_count + 1;
                                    end if;
                                 end loop;
                                 if (one_count mod 2 = 1) then
                                     even_odd <= 1; -- Odd number of 1's
                                 else
                                     even_odd <= 2; -- Even number of 1's
                                 end if;
                                 if even_odd = 1 then
                                     o_tx_data <= '1';
                                 else 
                                     o_tx_data <= '0';
                                 end if;
                        end case;
                        
                        if clk_counter < clks_per_bit then
                            clk_counter <= clk_counter + 1;
                            cur_state <= s_Parity;
                        else
                            clk_counter <= 0;
                            cur_state <= s_Stop;
                        end if;
                    
                    when s_Stop => -- stop bit state 
                        case stop_bits is
                            when 1 =>
                                o_tx_data <= '1';
                                if clk_counter < clks_per_bit then
                                    clk_counter <= clk_counter + 1;
                                    cur_state <= s_Stop;
                                else
                                    r_tx_done <= '1';
                                    clk_counter <= 0;
                                    cur_state <= s_Cleanup;
                                end if;
                                
                            when 2 =>
                                o_tx_data <= '1';
                                if clk_counter < clks_per_bit then
                                    clk_counter <= clk_counter + 1;
                                    cur_state <= s_Stop;
                                else
                                    r_tx_done <= '1';
                                    clk_counter <= 0;
                                end if;
                                if clk_counter < clks_per_bit then
                                    clk_counter <= clk_counter + 1;
                                    cur_state <= s_Stop;
                                else
                                    r_tx_done <= '1';
                                    clk_counter <= 0;
                                    cur_state <= s_Cleanup;
                                end if;
                        end case;
                        
                    when s_Cleanup => -- give everything a chance to settle down
                        o_tx_active <= '0';
                        r_tx_done <= '1';
                        cur_state <= s_Idle;
                    
                    when others =>
                        cur_state <= s_Idle;
                end case;
            end if;
        end if;
     end process;
     o_tx_done <= r_tx_done;
end architecture;
