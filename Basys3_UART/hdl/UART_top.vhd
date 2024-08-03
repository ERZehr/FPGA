----------------------------------------------------------------------------------
-- Company: Zehrforce
-- Engineer: Evan Zehr
-- 
-- Create Date: 08/03/2024 12:12:56 PM
-- Design Name: Uart_top
-- Module Name: UART_top - rtl
-- Project Name: UART
-- Target Devices: MISC
-- Tool Versions: Vivado 2024.1
-- Description: top level implementation of UART protocol
-- 
-- Dependencies: UART_tx, UART_rx
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity UART_top is
    generic (
        clk_in_top    : integer := 100000000; -- 100MHZ
        baud_rate_top : integer := 9600;
        word_size_top : integer := 8;
        parity_top    : integer := 0; -- 0 no parity. 1 odd parity, 2 even parity
        stop_bits_top : integer := 1  -- 1 or 2 stop bits
    );
    
    port ( 
        i_clk               : in std_logic;
        i_nrst              : in std_logic;
        i_data_in_tx        : in std_logic_vector(word_size_top-1 downto 0);
        i_start             : in std_logic;
        i_data_in_rx        : in std_logic;
        o_tx_data           : out std_logic; 
        o_tx_active         : out std_logic; 
        o_tx_done           : out std_logic; 
        o_rx_data_out       : out std_logic_vector(word_size_top-1 downto 0);
        o_rx_ready          : out std_logic;
        o_rx_done           : out std_logic;
        o_parity_error      : out std_logic
    );
end UART_top;

architecture rtl of UART_top is
    signal debounce_out : std_logic;
    
    component UART_tx is
        generic(
            clk_in    : integer := 100000000;
            baud_rate : integer := 9600;
            word_size : integer := 8;
            parity    : integer := 0;
            stop_bits : integer := 1
        );
        port(
            i_clk                : in std_logic;
            i_nrst               : in std_logic;
            i_data_in_tx         : in std_logic_vector(word_size-1 downto 0);
            i_start              : in std_logic;
            o_tx_data            : out std_logic;
            o_tx_active          : out std_logic;
            o_tx_done            : out std_logic
        );
    end component UART_tx;
    
    component UART_rx is
        generic(
            clk_in    : integer := 100000000;
            baud_rate : integer := 9600;
            word_size : integer := 8;
            parity    : integer := 0;
            stop_bits : integer := 1
        );
        port(
            i_clk            : in std_logic;
            i_nrst           : in std_logic;
            i_data_in_rx     : in std_logic;
            o_rx_data_out    : out std_logic_vector(word_size-1 downto 0);
            o_rx_ready       : out std_logic;
            o_rx_done        : out std_logic;
            o_parity_error   : out std_logic
        );
    end component UART_rx;
    
    component button_debounce is
        port ( 
            clk        : in std_logic;
            nrst       : in std_logic;
            button_in  : in std_logic;
            button_out : inout std_logic
        );
    end component;
        
begin
    U1: button_debounce 
        port map (
            clk        => i_clk,
            nrst       => i_nrst,
            button_in  => i_start,
            button_out => debounce_out
        );

    U2: UART_tx
        generic map (
            clk_in    => clk_in_top,
            baud_rate => baud_rate_top,
            word_size => word_size_top,
            parity    => parity_top,
            stop_bits => stop_bits_top
        )
        port map (
            i_clk        => i_clk,     
            i_nrst       => i_nrst,
            i_data_in_tx => i_data_in_tx,
            i_start      => debounce_out,
            o_tx_data    => o_tx_data,
            o_tx_active  => o_tx_active,
            o_tx_done    => o_tx_done
        );
        
        
    U3: UART_rx
        generic map (
            clk_in    => clk_in_top,
            baud_rate => baud_rate_top,
            word_size => word_size_top,
            parity    => parity_top,
            stop_bits => stop_bits_top
        )
        port map (
            i_clk          => i_clk,
            i_nrst         => i_nrst,
            i_data_in_rx   => i_data_in_rx,
            o_rx_data_out  => o_rx_data_out,
            o_rx_ready     => o_rx_ready,
            o_rx_done      => o_rx_done,
            o_parity_error => o_parity_error
        );


end rtl;
