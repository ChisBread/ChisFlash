library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- chisflash 的实体声明
entity chisflash is
	port (
		GBA_AD : in std_logic_vector(15 downto 0); -- GBA 24位数据-地址总线 高16位读取
		GBA_A : in std_logic_vector(7 downto 0);   -- GBA 24位数据-地址总线 低8位地址
		GBA_CS : in std_logic;                     -- GBA Flash ROM 片选信号
		GBA_CS2 : in std_logic;                    -- GBA SRAM 片选信号
		GBA_RD : in std_logic; 		    		   -- GBA 读取信号
		GBA_WR : in std_logic; 		    		   -- GBA 写入信号
		ROM_A : out std_logic_vector(15 downto 0); -- ROM 锁存高位地址输出
		GBA_BK : out std_logic := '0';             -- GBA SRAM Bank 选择信号
		LED : inout std_logic_vector(1 downto 0) := "ZZ" -- LED指示灯
	);
end chisflash;

-- cart flash地址管理, sram bank选择
architecture cart of chisflash is
	signal GBA_RD_WR : std_logic;                    -- GBA 读写信号
	signal ADDR : std_logic_vector(15 downto 0);     -- ROM 锁存高位地址
	signal BK : std_logic := '0';                    -- GBA SRAM Bank 选择信号
	signal WR_RD_CNT : unsigned(25 downto 0) := (others => '0'); -- GBA 读写计数器
begin
	GBA_RD_WR <= GBA_RD and GBA_WR;
	process (GBA_CS, GBA_RD_WR, GBA_AD) is
	begin
		-- 见: https://github.com/ChisBread/ChisFlash/blob/master/document/1-how-does-the-gba-cart-work.md#%E5%8D%A1%E6%A7%BD%E6%80%BB%E7%BA%BF---%E5%AE%9A%E4%B9%89
		if GBA_CS = '1' then
		-- 这里应该是GBA_CS下降沿时，锁存地址
			ADDR <= GBA_AD;
		elsif rising_edge(GBA_RD_WR) then
		-- GBA_RD或者GBA_WR上升沿时，触发地址自增
			ADDR <= std_logic_vector(unsigned(ADDR) + 1);
			WR_RD_CNT <= WR_RD_CNT + 1;
		end if;
	end process;
	ROM_A <= ADDR;
	process (GBA_CS, GBA_CS2, GBA_WR, ADDR, GBA_A, GBA_AD) is
	begin
		-- Post-Processing 1: GBA SRAM Bank 选择
		if GBA_CS = '0' and falling_edge(GBA_WR) then
		-- D商卡带补丁版 SRAM Bank 选择; 
		--    原理: 0x9000000地址为D商卡带bank选择地址, GBA的0x9000000映射到Flash ROM的0x1000000
		--        由于Flash是16bit输出，所以0x9000000对应的地址为高10000000+低0000000000000000+, 以及16bit中的低8bit
			if ADDR = "0000000000000000" and GBA_A = "10000000" then
				BK <= GBA_AD(0);
			end if;
		-- Post-Processing 2: TODO. 标准版 Flash ROM Backup指令集实现(Pokemon、Sonic原生存档方式)
		end if;
	end process;
	GBA_BK <= BK;
	-- 做读写指示灯用
	process (GBA_CS, GBA_CS2, WR_RD_CNT) is
	begin
		if GBA_CS2 = '0' then
			LED(1) <= '0';
			-- 关闭LED(0)指示灯
			LED(0) <= 'Z';
		else
			LED(1) <= 'Z';
			-- WR_RD_CNT 最高位为1时，亮LED(0)指示灯
			if GBA_CS = '0' AND WR_RD_CNT(25) = '0' then
				-- 实现PWM效果
				if  WR_RD_CNT(24) = '0' AND WR_RD_CNT(23 downto 12) > WR_RD_CNT(11 downto 0) then
					LED(0) <= '0';
				elsif WR_RD_CNT(24) = '1' AND WR_RD_CNT(23 downto 12) < WR_RD_CNT(11 downto 0) then
					LED(0) <= '0';
				else
					LED(0) <= 'Z';
				end if;
			else
				LED(0) <= 'Z';
			end if;
		end if;
	end process;
end cart;