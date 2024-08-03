----------------------------------------------------------------------------------
-- Company: Zehrforce
-- Engineer: Evan Zehr
-- 
-- Create Date: 08/02/2024 11:37:42 PM
-- Design Name: UART_rx
-- Module Name: UART_rx - rtl
-- Project Name: UART
-- Target Devices: MISC
-- Tool Versions: Vivado 2024.1
-- Description: uart receiver module
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


entity UART_rx is
    generic(
        clk_in    : integer := 100000000; -- 100MHZ
        baud_rate : integer := 9600;
        word_size : integer := 8;
        parity    : integer := 0; -- 0 no parity. 1 odd parity, 2 even parity
        stop_bits : integer := 1  -- 1 or 2 stop bits
        );
    port ( 
        i_clk            : in std_logic;
        i_nrst           : in std_logic;
        i_data_in_rx     : in std_logic;
        o_rx_data_out    : out std_logic_vector(word_size-1 downto 0);
        o_rx_ready       : out std_logic;
        o_rx_done        : out std_logic;
        o_parity_error   : out std_logic
        );
end UART_rx;

architecture rtl of UART_rx is
    constant clks_per_bit        : integer := clk_in/baud_rate; -- calculation of clk cycles per bit
    
    type state_mne is (s_Reset, s_Ready, s_Start, s_Receive, s_Parity, s_Stop, s_Cleanup); -- state machine initiation
    signal cur_state : state_mne := s_Ready; -- signal for current state
    
    signal r_rx_data_bit         : std_logic := '0'; -- data bit in register
    signal r_rx_data_bit_double  : std_logic := '0'; -- double data bit in register for metastability purposes
    
    signal clk_counter           : integer range 0 to clks_per_bit := 0; -- counter for clock cycles
    signal bit_counter           : integer range 0 to word_size := 0; -- counter for number of bits gone through
    signal r_rx_data             : std_logic_vector(word_size-1 downto 0):= (others => '0'); -- vector to store the final data reads
    signal r_rx_done             : std_logic := '0'; -- signifies a completed word read
    signal r_data_in_ready       : std_logic := '0'; -- ready to read data
    signal r_parity_error        : std_logic := '0'; -- signal for detecting a parrity error
    signal one_count             : integer range 0 to word_size := 0; -- for parity math
    signal even_odd              : integer range 1 to 2; -- for parity conditional

begin
    process(i_clk, i_nrst)
    begin
        if rising_edge(i_clk) then
            if i_nrst = '0' then -- the reset case
                r_rx_data_bit        <= '0';
                r_rx_data_bit_double <= '0';
                clk_counter          <= 0;
                bit_counter          <= 0;
                r_rx_data            <= (others => '0');
                r_rx_done            <= '0';
                r_data_in_ready      <= '0';
                r_parity_error       <= '0';
                one_count            <= 0;
                even_odd             <= 1;
                cur_state            <= s_Reset;
                
            elsif i_nrst = '1' then -- if out of reset
                r_rx_data_bit_double <= i_data_in_rx;
                r_rx_data_bit <= r_rx_data_bit_double; -- double register to avouid metastability
                case cur_state is
                    when s_Reset => --dead reset case
                        r_rx_data_bit        <= '0';
                        r_rx_data_bit_double <= '0';
                        clk_counter          <= 0;
                        bit_counter          <= 0;
                        r_rx_data            <= (others => '0');
                        r_rx_done            <= '0';
                        r_data_in_ready      <= '0';
                        one_count            <= 0;
                        even_odd             <= 1;
                        cur_state            <= s_Ready;
                
                    when s_Ready => -- ready to recieve state
                        r_data_in_ready <= '1';
                        r_rx_done <= '0';
                        clk_counter <= 0;
                        bit_counter <= 0;
                        if r_rx_data_bit = '0' then
                            cur_state <= s_Start;
                        else
                            cur_state <= s_Ready;
                        end if;
                    
                    when s_Start => -- start bit has been recieved case
                        if clk_counter = (clks_per_bit-1)/2 then
                            if r_rx_data_bit = '0' then
                                clk_counter <= 0;
                                cur_state <= s_Receive;
                            else
                                cur_state <= s_Ready;
                            end if;
                        else
                            clk_counter <= clk_counter + 1;
                            cur_state <= s_Start;
                        end if;
                    
                    when s_Receive => -- receiving data case
                        if clk_counter < clks_per_bit then
                            clk_counter <= clk_counter + 1;
                            cur_state <= s_Receive;
                        else
                            clk_counter <= 0;
                            r_rx_data(bit_counter) <= r_rx_data_bit;
                            if bit_counter < word_size-1 then
                                bit_counter <= bit_counter+1;
                                cur_state <= s_Receive;
                            else
                                bit_counter <= 0;
                                cur_state <= s_Parity;
                            end if;
                        end if;
                    
                    when s_Parity => -- deal with parity bit case
                        case parity is
                            when 0 => -- no parity bit
                                 cur_state <= s_Stop;
                                
                            when 1 => -- odd parity
                                one_count <= 0;
                                for i in r_rx_data'range loop
                                    if r_rx_data(i) = '1' then
                                        one_count <= one_count + 1;
                                    end if;
                                end loop;
                                if (one_count mod 2 = 1) then
                                    even_odd <= 1; -- Odd number of 1's
                                else
                                    even_odd <= 2; -- Even number of 1's
                                end if;
                                if even_odd = 1 then
                                    if clk_counter < clks_per_bit then
                                        clk_counter <= clk_counter + 1;
                                        cur_state <= s_Receive;
                                    else
                                        clk_counter <= 0;
                                        cur_state <= s_Stop;
                                    end if;
                                else
                                    r_parity_error <= '1'; 
                                    cur_state <= s_Reset;
                                end if;
                                 
                            when 2 => -- even parity
                                one_count <= 0;
                                for i in r_rx_data'range loop
                                    if r_rx_data(i) = '1' then
                                        one_count <= one_count + 1;
                                    end if;
                                end loop;
                                if (one_count mod 2 = 1) then
                                    even_odd <= 1; -- Odd number of 1's
                                else
                                    even_odd <= 2; -- Even number of 1's
                                end if;
                                if even_odd = 2 then
                                    if clk_counter < clks_per_bit-1 then
                                        clk_counter <= clk_counter + 1;
                                        cur_state <= s_Receive;
                                    else
                                        clk_counter <= 0;
                                        cur_state <= s_Stop;
                                    end if;
                                else
                                    r_parity_error <= '1';
                                    cur_state <= s_Reset;
                                end if; 
                        end case;
                    
                    when s_Stop => -- deal with stop bit(s) case
                        case stop_bits is
                            when 1 => -- 1 stop bit
                                if clk_counter < clks_per_bit-1 then
                                    clk_counter <= clk_counter + 1;
                                    cur_state <= s_Stop;
                                else
                                    clk_counter <= 0;
                                    r_rx_done <= '1';
                                    cur_state <= s_Cleanup;
                                end if;
                            when 2 => -- 2 stop bits
                                if clk_counter < 2*(clks_per_bit-1) then
                                    clk_counter <= clk_counter + 1;
                                    cur_state <= s_Stop;
                                else
                                    clk_counter <= 0;
                                    r_rx_done <= '1';
                                    cur_state <= s_Cleanup;
                                end if;
                        end case;
                    
                    when s_Cleanup => -- get back to a good state case
                        cur_state <= s_Ready;
                        r_rx_done <= '0'; 
                    when others =>
                        cur_state <= s_Ready;
                end case;
            end if;
        end if;
    end process;
    o_rx_data_out  <= r_rx_data;
    o_rx_ready     <= r_data_in_ready;
    o_rx_done      <= r_rx_done;
    o_parity_error <= r_parity_error;
end architecture;
