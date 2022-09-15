library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sim_out is
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        halt  : in  std_logic;
        dat_i : in  std_logic_vector(31 downto 0);
        cyc_i : in  std_logic;
        stb_i : in  std_logic;
        we_i  : in  std_logic;
        sel_i : in  std_logic_vector(3  downto 0);        
        adr_i : in  std_logic_vector(1  downto 0);
        ack_o : out std_logic;
        dat_o : out std_logic_vector(31 downto 0)
    );
end entity sim_out;

architecture rtl of sim_out is

    constant STAT_ADDR : std_logic_vector(1 downto 0) := b"00";
    constant CTRL_ADDR : std_logic_vector(1 downto 0) := b"01";
    constant BRDV_ADDR : std_logic_vector(1 downto 0) := b"10";
    constant TXRX_ADDR : std_logic_vector(1 downto 0) := b"11";

    signal ack : std_logic;

    type charfile is file of character;
    
    file out_file : charfile;
    file in_file  : charfile;

begin

    main: process(clk_i)
        variable char : character;
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                file_open(out_file, "STD_OUTPUT", write_mode);
                file_open(in_file, "STD_INPUT", read_mode);
            elsif halt = '1' then
                file_close(out_file);
                file_close(in_file);
            elsif ack = '0' and cyc_i = '1' and stb_i = '1' then
                if we_i = '1' then
                    if adr_i = TXRX_ADDR then
                        write(out_file, character'val(to_integer(unsigned(dat_i(7 downto 0)))));
                    end if;
                else
                    if adr_i = STAT_ADDR then
                        dat_o <= (31 downto 6 => '1') & b"111100";
                    elsif adr_i = TXRX_ADDR then
                        read(in_file, char);
                        dat_o <= (31 downto 8 => '0') & std_logic_vector(to_unsigned(character'pos(char), 8));
                    else
                        dat_o <= (31 downto 0 => '1');
                    end if;
                end if;
            end if;
        end if;
    end process main;

    ack_reg: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack <= '0';
            elsif ack = '1' then
                ack <= not ack;
            else
                ack <= cyc_i and stb_i;
            end if;
        end if;
    end process ack_reg;

    ack_o <= ack;

end architecture rtl;