//+------------------------------------------------------------------+
//|                                      SupportResistance.mqh     |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __SupportResistance_MQH__
#define __SupportResistance_MQH__


#include "../../core/SignalGenerator.mqh"
#include "../../utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| 输入参数                                                           |
//+------------------------------------------------------------------+
input int    SR_Lookback = 50;         // 回溯K线数
input int    SR_TouchCount = 2;        // 最小触及次数
input double SR_ProximityPips = 10;    // 近距离判断点数
input int    SR_SL_Pips = 25;          // 止损点数
input int    SR_TP_Pips = 50;          // 止盈点数

//+------------------------------------------------------------------+
//| 支撑阻力突破策略类                                                 |
//+------------------------------------------------------------------+
class CSupportResistance : public CSignalGenerator
{
private:
   double   m_resistanceLevel;  // 阻力位
   double   m_supportLevel;     // 支撑位
   int      m_resistanceTouches; // 阻力位触及次数
   int      m_supportTouches;   // 支撑位触及次数

   //--- 辅助方法
   void     FindLevels();
   int      CountTouches(double level, double tolerance);
   bool     IsNearLevel(double price, double level, double tolerance);

public:
   //--- 构造函数/析构函数
   CSupportResistance();
   CSupportResistance(const string symbol, int timeFrame, int magic);
   virtual ~CSupportResistance();

   //--- 重写基类方法
   virtual bool   Init() override;
   virtual void   Deinit() override;
   virtual int    GenerateSignal(double& sl, double& tp) override;
   virtual string GetStrategyName() override { return "Support/Resistance"; }
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CSupportResistance::CSupportResistance()
{
   m_resistanceLevel = 0;
   m_supportLevel = 0;
   m_resistanceTouches = 0;
   m_supportTouches = 0;
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CSupportResistance::CSupportResistance(const string symbol, int timeFrame, int magic)
{
   m_symbol = symbol;
   m_timeFrame = timeFrame;
   m_magic = magic;
   m_resistanceLevel = 0;
   m_supportLevel = 0;
   m_resistanceTouches = 0;
   m_supportTouches = 0;
}

//+------------------------------------------------------------------+
//| 析构函数                                                           |
//+------------------------------------------------------------------+
CSupportResistance::~CSupportResistance()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| 初始化                                                             |
//+------------------------------------------------------------------+
bool CSupportResistance::Init()
{
   if(!CSignalGenerator::Init()) return false;

   FindLevels();

   LOG_INFO(StringFormat("S/R Strategy initialized: Lookback=%d", SR_Lookback));
   return true;
}

//+------------------------------------------------------------------+
//| 反初始化                                                           |
//+------------------------------------------------------------------+
void CSupportResistance::Deinit()
{
   CSignalGenerator::Deinit();
}

//+------------------------------------------------------------------+
//| 查找支撑阻力位                                                     |
//+------------------------------------------------------------------+
void CSupportResistance::FindLevels()
{
   //--- 检查是否有足够的数据
   if(Bars(m_symbol, m_timeFrame) < SR_Lookback + 1)
   {
      m_resistanceLevel = 0;
      m_supportLevel = 0;
      return;
   }

   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   int copiedHigh = CopyHigh(m_symbol, m_timeFrame, 0, SR_Lookback, high);
   int copiedLow = CopyLow(m_symbol, m_timeFrame, 0, SR_Lookback, low);
   int copiedClose = CopyClose(m_symbol, m_timeFrame, 0, SR_Lookback, close);

   // 检查是否成功复制了足够的数据
   if(copiedHigh < SR_Lookback || copiedLow < SR_Lookback || copiedClose < SR_Lookback)
   {
      m_resistanceLevel = 0;
      m_supportLevel = 0;
      return;
   }

   //--- 找出最高和最低点
   int highestIdx = ArrayMaximum(high, 0, SR_Lookback);
   int lowestIdx = ArrayMinimum(low, 0, SR_Lookback);

   if(highestIdx < 0 || highestIdx >= ArraySize(high) || lowestIdx < 0 || lowestIdx >= ArraySize(low))
   {
      m_resistanceLevel = 0;
      m_supportLevel = 0;
      return;
   }

   m_resistanceLevel = high[highestIdx];
   m_supportLevel = low[lowestIdx];

   //--- 计算触及次数
   double point = MarketInfo(m_symbol, MODE_POINT);
   double tolerance = SR_ProximityPips * point * ((MarketInfo(m_symbol, MODE_DIGITS) == 5) ? 10 : 1);

   m_resistanceTouches = CountTouches(m_resistanceLevel, tolerance);
   m_supportTouches = CountTouches(m_supportLevel, tolerance);
}

//+------------------------------------------------------------------+
//| 计算触及次数                                                       |
//+------------------------------------------------------------------+
int CSupportResistance::CountTouches(double level, double tolerance)
{
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   if(CopyHigh(m_symbol, m_timeFrame, 0, SR_Lookback, high) <= 0) return 0;
   if(CopyLow(m_symbol, m_timeFrame, 0, SR_Lookback, low) <= 0) return 0;

   int touches = 0;

   for(int i = 1; i < SR_Lookback; i++)
   {
      // 检查是否触及该水平
      if(MathAbs(high[i] - level) <= tolerance || MathAbs(low[i] - level) <= tolerance)
      {
         touches++;
      }
   }

   return touches;
}

//+------------------------------------------------------------------+
//| 检查是否接近水平                                                   |
//+------------------------------------------------------------------+
bool CSupportResistance::IsNearLevel(double price, double level, double tolerance)
{
   return (MathAbs(price - level) <= tolerance);
}

//+------------------------------------------------------------------+
//| 生成交易信号                                                       |
//+------------------------------------------------------------------+
int CSupportResistance::GenerateSignal(double& sl, double& tp)
{
   if(!m_initialized) return SIGNAL_NONE;

   //--- 更新支撑阻力位
   FindLevels();

   if(m_resistanceLevel == 0 || m_supportLevel == 0) return SIGNAL_NONE;

   //--- 获取价格数据
   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(m_symbol, m_timeFrame, 0, 2, close) <= 0) return SIGNAL_NONE;

   //--- 计算点值
   double point = MarketInfo(m_symbol, MODE_POINT);
   int digits = (int)MarketInfo(m_symbol, MODE_DIGITS);
   double pipMultiplier = (digits == 5 || digits == 3) ? 10 : 1;
   double tolerance = SR_ProximityPips * point * pipMultiplier;

   int signal = SIGNAL_NONE;

   //--- 检查阻力位突破 (需要足够的触及次数确认该水平有效)
   if(m_resistanceTouches >= SR_TouchCount)
   {
      // 价格突破阻力位
      if(close[1] < m_resistanceLevel && close[0] > m_resistanceLevel)
      {
         signal = SIGNAL_BUY;
         sl = NormalizeDouble(Bid - SR_SL_Pips * point * pipMultiplier, digits);
         tp = NormalizeDouble(Ask + SR_TP_Pips * point * pipMultiplier, digits);

         g_logger.LogSignal(SIGNAL_BUY, StringFormat("Resistance Break (%.5f)", m_resistanceLevel));
      }
   }

   //--- 检查支撑位突破
   if(signal == SIGNAL_NONE && m_supportTouches >= SR_TouchCount)
   {
      // 价格突破支撑位
      if(close[1] > m_supportLevel && close[0] < m_supportLevel)
      {
         signal = SIGNAL_SELL;
         sl = NormalizeDouble(Ask + SR_SL_Pips * point * pipMultiplier, digits);
         tp = NormalizeDouble(Bid - SR_TP_Pips * point * pipMultiplier, digits);

         g_logger.LogSignal(SIGNAL_SELL, StringFormat("Support Break (%.5f)", m_supportLevel));
      }
   }

   return signal;
}

//+------------------------------------------------------------------+
#endif // __SupportResistance_MQH__
