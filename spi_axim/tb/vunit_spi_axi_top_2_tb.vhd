-- This testbench simulates the AXI interface as a memory
-- The tests are:
-- test_write - Reads some sequential words with the READ_C command
-- test_fast_write - Reads some sequential words with the FAST_READ_C command



--! Standard library.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--
library std;
use std.textio.all;
--
library stdblocks;
library stdcores;
library expert;
    use expert.std_logic_expert.all;

library tb_lib;

library osvvm;
use osvvm.RandomPkg.all;

-- vunit
library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

entity vunit_spi_axi_top_2_tb is
    --vunit
    generic (
        runner_cfg : string
    );
end;

architecture tb of vunit_spi_axi_top_2_tb is

    constant  ID_WIDTH      : integer := 1;
    constant  ID_VALUE      : integer := 0;
    constant  ADDR_BYTE_NUM : integer := 4;
    constant  DATA_BYTE_NUM : integer := 4;
    constant  serial_num_rw : boolean := true;
  
    signal    rst_i         : std_logic;
    signal    mclk_i        : std_logic := '0';
    signal    mosi_s        : std_logic;
    signal    miso_s        : std_logic;
    signal    spck_s        : std_logic;
    signal    spcs_s        : std_logic;
    signal    RSTIO_o       : std_logic;
  
    constant  DID_i         : std_logic_vector(DATA_BYTE_NUM*8-1 downto 0) := x"76543210";
    constant  UID_i         : std_logic_vector(DATA_BYTE_NUM*8-1 downto 0) := x"AAAAAAAA";
    constant  serial_num_i  : std_logic_vector(DATA_BYTE_NUM*8-1 downto 0) := x"00000000";
    signal    irq_i         : std_logic_vector(7 downto 0)                 := x"86";
    signal    irq_o         : std_logic;
  
    signal    M_AXI_AWID    : std_logic_vector(ID_WIDTH-1 downto 0);
    signal    M_AXI_AWVALID : std_logic;
    signal    M_AXI_AWREADY : std_logic;
    signal    M_AXI_AWADDR  : std_logic_vector(8*ADDR_BYTE_NUM-1 downto 0);
    signal    M_AXI_AWPROT  : std_logic_vector(2 downto 0);
    signal    M_AXI_WVALID  : std_logic;
    signal    M_AXI_WREADY  : std_logic;
    signal    M_AXI_WDATA   : std_logic_vector(8*DATA_BYTE_NUM-1 downto 0);
    signal    M_AXI_WSTRB   : std_logic_vector(DATA_BYTE_NUM-1 downto 0);
    signal    M_AXI_WLAST   : std_logic;
    signal    M_AXI_BVALID  : std_logic;
    signal    M_AXI_BREADY  : std_logic;
    signal    M_AXI_BRESP   : std_logic_vector(1 downto 0);
    signal    M_AXI_BID     : std_logic_vector(ID_WIDTH-1 downto 0);
    signal    M_AXI_ARVALID : std_logic;
    signal    M_AXI_ARREADY : std_logic;
    signal    M_AXI_ARADDR  : std_logic_vector(8*ADDR_BYTE_NUM-1 downto 0);
    signal    M_AXI_ARPROT  : std_logic_vector(2 downto 0);
    signal    M_AXI_ARID    : std_logic_vector(ID_WIDTH-1 downto 0);
    signal    M_AXI_RVALID  : std_logic;
    signal    M_AXI_RREADY  : std_logic;
    signal    M_AXI_RDATA   : std_logic_vector(8*DATA_BYTE_NUM-1 downto 0);
    signal    M_AXI_RRESP   : std_logic_vector(1 downto 0);
    signal    M_AXI_RID     : std_logic_vector(ID_WIDTH-1 downto 0);
    signal    M_AXI_RLAST   : std_logic;
  
    constant frequency_mhz   : real := 12.5000;
    constant spi_period      : time := ( 1.000 / frequency_mhz) * 1 us;
    constant spi_half_period : time := spi_period;
  
    type data_vector_t is array (NATURAL RANGE <>) of std_logic_vector(7 downto 0);
  
    signal WRITE_c       : std_logic_vector(7 downto 0) := x"02";
    signal READ_c        : std_logic_vector(7 downto 0) := x"03";
    signal FAST_WRITE_c  : std_logic_vector(7 downto 0) := x"0A";
    signal FAST_READ_c   : std_logic_vector(7 downto 0) := x"0B";
    signal WRITE_BURST_c : std_logic_vector(7 downto 0) := x"42";
    signal READ_BURST_c  : std_logic_vector(7 downto 0) := x"4B";
    signal EDIO_c        : std_logic_vector(7 downto 0) := x"3B";
    signal EQIO_c        : std_logic_vector(7 downto 0) := x"38";
    signal RSTIO_c       : std_logic_vector(7 downto 0) := x"FF";
    signal RDMR_c        : std_logic_vector(7 downto 0) := x"05";
    signal WRMR_c        : std_logic_vector(7 downto 0) := x"01";
    signal DPD_c         : std_logic_vector(7 downto 0) := x"BA";
    signal HBN_c         : std_logic_vector(7 downto 0) := x"B9";
    signal STAT_c        : std_logic_vector(7 downto 0) := x"A5";
  
    type axi_mem_t is array (NATURAL RANGE <>) of std_logic_vector(M_AXI_WDATA'range);
    signal axi_memory_s    : axi_mem_t(4095 downto 0);
    signal spi_txdata_s    : data_vector_t(63 downto 0);
    signal spi_rxdata_s    : data_vector_t(63 downto 0);
    signal spi_rxdata_en   : std_logic;
  
begin
    --clock and reset
    mclk_i <= not mclk_i after 10 ns;
    rst_i  <= '1', '0' after 30 ns;

    spi_axi_top_i : entity stdcores.spi_axi_top
        generic map (
            CPOL          => '0',
            CPHA          => '1',
            ID_WIDTH      => ID_WIDTH,
            ID_VALUE      => ID_VALUE,
            ADDR_BYTE_NUM => ADDR_BYTE_NUM,
            DATA_BYTE_NUM => DATA_BYTE_NUM,
            serial_num_rw => serial_num_rw,
            native_clock_mode => true
        )
        port map (
            rst_i         => rst_i,
            mclk_i        => mclk_i,
            mosi_i        => mosi_s,
            miso_o        => miso_s,
            spck_i        => spck_s,
            spcs_i        => spcs_s,
            RSTIO_o       => RSTIO_o,
            DID_i         => DID_i,
            UID_i         => UID_i,
            serial_num_i  => serial_num_i,
            irq_i         => irq_i,
            irq_o         => irq_o,
            M_AXI_AWID    => M_AXI_AWID,
            M_AXI_AWVALID => M_AXI_AWVALID,
            M_AXI_AWREADY => M_AXI_AWREADY,
            M_AXI_AWADDR  => M_AXI_AWADDR,
            M_AXI_AWPROT  => M_AXI_AWPROT,
            M_AXI_WVALID  => M_AXI_WVALID,
            M_AXI_WREADY  => M_AXI_WREADY,
            M_AXI_WDATA   => M_AXI_WDATA,
            M_AXI_WSTRB   => M_AXI_WSTRB,
            M_AXI_WLAST   => M_AXI_WLAST,
            M_AXI_BVALID  => M_AXI_BVALID,
            M_AXI_BREADY  => M_AXI_BREADY,
            M_AXI_BRESP   => M_AXI_BRESP,
            M_AXI_BID     => M_AXI_BID,
            M_AXI_ARVALID => M_AXI_ARVALID,
            M_AXI_ARREADY => M_AXI_ARREADY,
            M_AXI_ARADDR  => M_AXI_ARADDR,
            M_AXI_ARPROT  => M_AXI_ARPROT,
            M_AXI_ARID    => M_AXI_ARID,
            M_AXI_RVALID  => M_AXI_RVALID,
            M_AXI_RREADY  => M_AXI_RREADY,
            M_AXI_RDATA   => M_AXI_RDATA,
            M_AXI_RRESP   => M_AXI_RRESP,
            M_AXI_RID     => M_AXI_RID,
            M_AXI_RLAST   => M_AXI_RLAST
        );

    axi_wr_sim_p : process
        variable waddr_aux_v : std_logic_vector(M_AXI_AWADDR'range); 
        variable wdata_aux_v : std_logic_vector(M_AXI_WDATA'range); 
        variable waddr_ready_v : std_logic := '0';
        variable wdata_ready_v : std_logic := '0';
    begin
        M_AXI_AWREADY <= '1';
        M_AXI_WREADY  <= '1';
        M_AXI_BVALID  <= '0';

        wait until rising_edge(M_AXI_AWVALID) or rising_edge(M_AXI_WVALID);

        if (M_AXI_AWVALID = '1') then
            waddr_aux_v := M_AXI_AWADDR;
            waddr_ready_v := '1';
            -- M_AXI_AWREADY <= '0' transport after 2*10 ns;
        end if;
        if (M_AXI_WVALID = '1') then
            wdata_aux_v := M_AXI_WDATA;
            wdata_ready_v := '1';
            -- M_AXI_WREADY <= '0' transport after 2*10 ns;
        end if;

        if (wdata_ready_v = '1' and waddr_ready_v = '1') then
            axi_memory_s(to_integer(waddr_aux_v(waddr_aux_v'high downto 2))) <= wdata_aux_v;

            wait for 0*2*10 ns;
            M_AXI_BVALID  <= '1';
            wait for 2*10 ns;
            while (M_AXI_BREADY = '0') loop
                wait for 2*10 ns;
            end loop;
            M_AXI_BVALID  <= '0';
        end if;
    end process;
    axi_rd_sim_p : process
        variable rdata_aux_v : std_logic_vector(M_AXI_RDATA'range); 
    begin
        M_AXI_ARREADY <= '1';
        M_AXI_RVALID  <= '0';

        wait until rising_edge(M_AXI_ARVALID);
        rdata_aux_v := axi_memory_s(to_integer(M_AXI_ARADDR(M_AXI_ARADDR'high downto 2)));
        wait for 2*10 ns;
        M_AXI_ARREADY <= '0';

        wait for 0*2*10 ns;
        M_AXI_RVALID  <= '1';
        M_AXI_RDATA   <= rdata_aux_v;
        wait for 2*10 ns;
        while (M_AXI_RREADY = '0') loop
            wait for 2*10 ns;
        end loop;
        M_AXI_RVALID  <= '0';
        M_AXI_RDATA   <= x"UUUUUUUU";

    end process;

    M_AXI_BRESP   <= "00";
    M_AXI_BID     <= (others=>'0');
    M_AXI_RRESP   <= "00";
    M_AXI_RID     <= (others=>'0');
    M_AXI_RLAST   <= '0';


    main : process
        variable delay : RandomPType;

        procedure test_init is
        begin
            -- show(get_logger(default_checker), display_handler, pass);
            disable_stop(get_logger(default_checker), error);
            delay.InitSeed(delay'instance_name);
        end procedure;

        procedure tb_init is
        begin
            spck_s <= '0';
            spcs_s <= '1';
            mosi_s <= 'H';

            spi_txdata_s <= (others => x"00");
            spi_rxdata_s <= (others => x"00");
        end procedure;

        procedure spi_bus (
            signal data_i  : in  data_vector_t;
            signal data_o  : out data_vector_t;
            length_i : in integer
        ) is
            variable data_rx_v : std_logic_vector(7 downto 0);
        begin
            for k in 0 to length_i-1 loop
                for j in 7 downto 0 loop
                    spcs_s <= '0';
                    spck_s <= '1';
                    mosi_s <= data_i(k)(j);
                    wait for spi_half_period;
                    spck_s      <= '0';
                    data_rx_v(j) := miso_s;
                    wait for spi_half_period;
                end loop;

                -- Update the output
                data_o(k) <= data_rx_v;
            end loop;
            spcs_s <= '1';
            spck_s <= '0';
            mosi_s <= 'H';

            wait for 2*spi_half_period;
        end procedure;

        procedure spi_check_read (
            command_i : in std_logic_vector(7 downto 0);
            signal data_wr  : in  data_vector_t;
            signal data_rd  : in  data_vector_t;
            length_i : in integer
        ) is
            variable expected_value_v : std_logic_vector(7 downto 0);
            variable rd_byte_idx_v : integer;
            variable byte_idx_v : integer;
            variable fast_read_offset_v : integer;
            variable data_length_v : integer;
        begin
            data_length_v := length_i-5;
            byte_idx_v := 5; -- Skips command and address
            fast_read_offset_v := 0;
            -- check ACK byte when needed
            if (command_i = FAST_READ_c) then
                expected_value_v := x"AC";
                check_equal(data_rd(byte_idx_v), expected_value_v, "Testing ACK byte");
                
                byte_idx_v := byte_idx_v + 1;
                data_length_v := data_length_v - 1;
                fast_read_offset_v := 1;
            end if;
            
            -- check data byte(s)
            for i in 0 to data_length_v-1 loop
                info("Byte " & to_string(byte_idx_v));
                expected_value_v := data_wr(byte_idx_v);
                check_equal(data_rd(byte_idx_v), expected_value_v, "Testing data byte");

                byte_idx_v := byte_idx_v + 1;
            end loop;                                 
        end procedure;

        procedure test_write is
            constant num_words_c : integer := 3;
            variable address_v : std_logic_vector(ADDR_BYTE_NUM*8-1 downto 0);
        begin
            address_v := x"0000_0010";
            
            spi_txdata_s(0) <= WRITE_c;
            for i in 1 downto ADDR_BYTE_NUM loop
                spi_txdata_s(i) <= address_v((i+1)*8-1 downto i*8);
            end loop;
            
            for i in ADDR_BYTE_NUM+1 to ADDR_BYTE_NUM+num_words_c*DATA_BYTE_NUM loop
                spi_txdata_s(i) <= to_std_logic_vector(i, 8);
            end loop;

            wait for 100 ns;
            -- not fast write - n words
            spi_bus(spi_txdata_s, spi_rxdata_s, num_words_c*DATA_BYTE_NUM + ADDR_BYTE_NUM + 1);

            wait for 1000 ns;
            -- now read the content of the memory
            spi_txdata_s(0) <= READ_c;
            spi_bus(spi_txdata_s, spi_rxdata_s, num_words_c*DATA_BYTE_NUM + ADDR_BYTE_NUM + 1);
            spi_check_read(READ_c, spi_txdata_s, spi_rxdata_s, num_words_c*DATA_BYTE_NUM + ADDR_BYTE_NUM + 1);

        end procedure;

        procedure test_fast_write is
            constant num_words_c : integer := 3;
            variable address_v : std_logic_vector(ADDR_BYTE_NUM*8-1 downto 0);
        begin
            address_v := x"0000_0000";
            
            spi_txdata_s(0) <= FAST_WRITE_c;
            for i in 1 downto ADDR_BYTE_NUM loop
                spi_txdata_s(i) <= address_v((i+1)*8-1 downto i*8);
            end loop;

            spi_txdata_s(ADDR_BYTE_NUM+1) <= x"AC";
            
            for i in ADDR_BYTE_NUM+2 to ADDR_BYTE_NUM+num_words_c*DATA_BYTE_NUM+1 loop
                spi_txdata_s(i) <= to_std_logic_vector(i, 8);
            end loop;

            wait for 100 ns;
            -- fast write - n words
            -- fast write and write are the same 
            spi_bus(spi_txdata_s, spi_rxdata_s, num_words_c*DATA_BYTE_NUM + ADDR_BYTE_NUM + 2);

            wait for 1000 ns;
            -- now read the content of the memory
            spi_txdata_s(0) <= FAST_READ_c;
            spi_bus(spi_txdata_s, spi_rxdata_s, num_words_c*DATA_BYTE_NUM + ADDR_BYTE_NUM + 2);
            spi_check_read(FAST_READ_c, spi_txdata_s, spi_rxdata_s, num_words_c*DATA_BYTE_NUM + ADDR_BYTE_NUM + 2);
        end procedure;

    begin
        test_runner_setup(runner, runner_cfg);
        test_init;
        tb_init;

        while test_suite loop
            if run("Sanity.check") then
                test_runner_cleanup(runner);

            elsif run("write.something") then
                info("Writes something from SPI");
                wait for 100 ns;
                test_write;
                wait for 100 ns;
                test_write;

                test_runner_cleanup(runner);

            elsif run("fast.write.something") then
                info("Writes something from SPI");
                wait for 100 ns;
                test_fast_write;
                wait for 100 ns;
                test_fast_write;

                test_runner_cleanup(runner);
            end if;
        end loop;
    end process;

    test_runner_watchdog(runner, 10 ms);

end tb;
