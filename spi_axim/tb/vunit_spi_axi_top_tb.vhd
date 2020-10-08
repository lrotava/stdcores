-- This testbench simulates the AXI interface in a very simple way.
-- The write values are ignored and the read value is based on the address.
--     rdata := araddr(31 downto 16) & not araddr(15 downto 0);
-- The tests are:
-- test_read - Reads some sequential words with the READ_C command
-- test_fast_read - Reads some sequential words with the FAST_READ_C command



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

library avl_utils_lib;
use avl_utils_lib.axi_pkg.all;
use avl_utils_lib.axil_pkg.all;
use avl_utils_lib.avl_clock_utils_pkg.all;

library avl_sim_lib;
use avl_sim_lib.avl_simulators_pkg.all;

library tb_lib;

library osvvm;
use osvvm.RandomPkg.all;

-- vunit
library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

entity vunit_spi_axi_top_tb is
    --vunit
    generic (
        runner_cfg : string
    );
end;

architecture tb of vunit_spi_axi_top_tb is

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
  
    signal axilm_m2s : axil_m2s_t;
    signal axilm_s2m : axil_s2m_t;
  
    constant frequency_mhz   : real := 12.00;
    constant spi_period      : time := ( 1.000 / frequency_mhz) * 1 us;
    constant spi_half_period : time := spi_period/2;
  
    type data_vector_t is array (NATURAL RANGE <>) of std_logic_vector(7 downto 0);
    signal RDSN_c        : data_vector_t(4 downto 0) := (x"C3", others => x"00");
    signal WRSN_c        : data_vector_t(4 downto 0) := (x"C2", x"89", x"AB", x"CD", x"EF" );
  
    signal IRQRD_c       : data_vector_t(1 downto 0) := (x"A2", x"00");
    signal IRQWR_c       : data_vector_t(1 downto 0) := (x"A3", x"0F");
    signal IRQMRD_c      : data_vector_t(1 downto 0) := (x"D2", x"00");
    signal IRQMWR_c      : data_vector_t(1 downto 0) := (x"D3", x"F0");
  
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
    signal RDID_c        : std_logic_vector(7 downto 0) := x"9F";
    signal RUID_c        : std_logic_vector(7 downto 0) := x"4C";
  
    signal spi_txdata_s    : data_vector_t(63 downto 0);
    signal spi_rxdata_s    : data_vector_t(63 downto 0);
    signal spi_rxdata_en   : std_logic;
  
begin
    --clock and reset
    clk_gen(mclk_i, 10 ns);
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
            M_AXI_AWID    => open,--axilm_m2s.awid,
            M_AXI_AWVALID => axilm_m2s.awvalid,
            M_AXI_AWREADY => axilm_s2m.awready,
            M_AXI_AWADDR  => axilm_m2s.awaddr,
            M_AXI_AWPROT  => open,--axilm_s2m.awprot,
            M_AXI_WVALID  => axilm_m2s.wvalid,
            M_AXI_WREADY  => axilm_s2m.wready,
            M_AXI_WDATA   => axilm_m2s.wdata,
            M_AXI_WSTRB   => axilm_m2s.wstrb,
            M_AXI_WLAST   => open,--axilm_m2s.wlast,
            M_AXI_BVALID  => axilm_s2m.bvalid,
            M_AXI_BREADY  => axilm_m2s.bready,
            M_AXI_BRESP   => axilm_s2m.bresp,
            M_AXI_BID     => (others=>'0'),--axilm_m2s.bid,
            M_AXI_ARVALID => axilm_m2s.arvalid,
            M_AXI_ARREADY => axilm_s2m.arready,
            M_AXI_ARADDR  => axilm_m2s.araddr,
            M_AXI_ARPROT  => open,--axilm_m2s.arprot,
            M_AXI_ARID    => open,--axilm_m2s.arid,
            M_AXI_RVALID  => axilm_s2m.rvalid,
            M_AXI_RREADY  => axilm_m2s.rready,
            M_AXI_RDATA   => axilm_s2m.rdata,
            M_AXI_RRESP   => axilm_s2m.rresp,
            M_AXI_RID     => (others=>'0'),--axilm_m2s.rid,
            M_AXI_RLAST   => '0'--axilm_m2s.rlast
        );
        
        avl_axils_sim_inst: entity avl_sim_lib.avl_axils_sim
            generic map (
                memory_length_g => 256,
                memory_width_g => 32,
        
                awready_delay_g => 0,
                wready_delay_g => 0,
                bvalid_delay_g => 0,
                arready_delay_g => 0,
                rvalid_delay_g => 0
            )
            port map (
                clk_i => mclk_i,
                rstn_i => not rst_i,
        
                axilm_m2s_i => axilm_m2s,
                axilm_s2m_o => axilm_s2m
            );


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
            spcs_s <= '0';
            wait for 300 ns;
            for k in 0 to length_i-1 loop
                for j in 7 downto 0 loop
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
            address_i : in std_logic_vector(ADDR_BYTE_NUM*8-1 downto 0);
            signal data_rd  : in  data_vector_t;
            length_i : in integer
        ) is
            variable address_v : std_logic_vector(ADDR_BYTE_NUM*8-1 downto 0);
            variable expected_value_v : std_logic_vector(7 downto 0);
            variable byte_idx_v : integer;
            variable data_length_v : integer;
        begin
            data_length_v := length_i-5;
            byte_idx_v := 5; -- Skips command and address
            -- check ACK byte when needed
            if (command_i = FAST_READ_c) then
                expected_value_v := x"AC";
                check_equal(data_rd(byte_idx_v), expected_value_v, "Testing ACK byte");
                
                byte_idx_v := byte_idx_v + 1;
                data_length_v := data_length_v - 1;
            end if;

            -- check data byte(s)
            for i in 0 to (data_length_v/ADDR_BYTE_NUM)-1 loop
                address_v := address_i + (i*ADDR_BYTE_NUM);
                for j in ADDR_BYTE_NUM-1 downto 0 loop
                    info("Byte " & to_string(byte_idx_v));
                    expected_value_v := address_v((j+1)*8-1 downto j*8);
                    check_equal(data_rd(byte_idx_v), expected_value_v, "Testing data byte");

                    byte_idx_v := byte_idx_v + 1;
                end loop;
            end loop;
                                               
        end procedure;

        procedure test_read is
            constant num_words_c : integer := 3;
            variable address_v : std_logic_vector(ADDR_BYTE_NUM*8-1 downto 0);
        begin
            address_v := x"0000_0004";
            
            spi_txdata_s(0) <= READ_c;
            for i in ADDR_BYTE_NUM downto 1 loop
                spi_txdata_s(ADDR_BYTE_NUM-i+1) <= address_v(i*8-1 downto (i-1)*8);
            end loop;

            wait for 100 ns;

            -- not fast read - n words
            spi_bus(spi_txdata_s, spi_rxdata_s, num_words_c*DATA_BYTE_NUM + ADDR_BYTE_NUM + 1);

            spi_check_read(READ_c, address_v, spi_rxdata_s, num_words_c*DATA_BYTE_NUM + ADDR_BYTE_NUM + 1);
        end procedure;

        procedure test_fast_read is
            constant num_words_c : integer := 3;
            variable address_v : std_logic_vector(ADDR_BYTE_NUM*8-1 downto 0);
        begin
            address_v := x"0000_0004";
            
            spi_txdata_s(0) <= FAST_READ_c;
            for i in ADDR_BYTE_NUM downto 1 loop
                spi_txdata_s(ADDR_BYTE_NUM-i+1) <= address_v(i*8-1 downto (i-1)*8);
            end loop;

            wait for 100 ns;

            -- fast read - 1 word + 1 ack byte 
            spi_bus(spi_txdata_s, spi_rxdata_s, num_words_c*DATA_BYTE_NUM + ADDR_BYTE_NUM + 2);

            spi_check_read(FAST_READ_c, address_v, spi_rxdata_s, num_words_c*DATA_BYTE_NUM + ADDR_BYTE_NUM + 2);
        end procedure;

        procedure test_read_id is
            variable address_v : std_logic_vector(ADDR_BYTE_NUM*8-1 downto 0);
            variable expected_value_v : std_logic_vector(7 downto 0);
        begin
            spi_txdata_s(0) <= RDID_c;

            wait for 100 ns;

            -- 1 word
            spi_bus(spi_txdata_s, spi_rxdata_s, DATA_BYTE_NUM + 1);
            
            for i in 0 to 3 loop
                expected_value_v := DID_i((i+1)*8-1 downto i*8);
                check_equal(spi_rxdata_s(4-i), expected_value_v, "Testing ID bytes");
            end loop;

        end procedure;

    begin
        test_runner_setup(runner, runner_cfg);
        test_init;
        tb_init;

        while test_suite loop
            if run("Sanity.check") then
                test_runner_cleanup(runner);

            elsif run("read.something") then
                info("Reads something from SPI");
                wait for 100 ns;
                test_read;
                wait for 1000 ns;
                test_read;
                wait for 100 ns;

                test_runner_cleanup(runner);

            elsif run("fast.read.something") then
                info("Reads something from SPI");
                wait for 100 ns;
                test_fast_read;
                wait for 1000 ns;
                test_fast_read;
                wait for 100 ns;

                test_runner_cleanup(runner);

            elsif run("read.id") then
                info("Reads ID from SPI");
                wait for 100 ns;
                test_read_id;
                wait for 10 ns;
                test_read_id;

                test_runner_cleanup(runner);
            end if;
        end loop;
    end process;

    test_runner_watchdog(runner, 10 ms);

end tb;
