//+------------------------------------------------------------------+
//|                                            MACDStrategy.mqh     |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __MACDStrategy_MQH__
#define __MACDStrategy_MQH__


#include "../../core/SignalGenerator.mqh"
#include "../../utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| 输入参数                                                           |
//+------------------------------------------------------------------+
input int    MACD_Fast = 12;           // MACD快线周期
input int    MACD_Slow = 26;           // MACD慢线周期
input int    MACD_Signal = 9;          // MACD信号线周期
input int    MACD_AppliedPrice = 0;    // 应用价格
input double MACD_SignalThreshold = 0; // 信号阈值
input int    MACD_SL_Pips = 40;        // 止损点数
input int    MACD_TP_Pips = 80;        // 止盈点数

//+------------------------------------------------------------------+
//| MACD策略类                                                         |
//+------------------------------------------------------------------+
class CMACDStrategy : public CSignalGenerator
{
private:
   int      m_macdHandle;       // MACD句柄
   double   m_macdMain[];       // MACD主线
   double   m_macdSignal[];     // MACD信号线

   //--- 辅助方法
   bool     GetMACDValues(int shift, double& main, double& signal);

public:
   //--- 构造函数/析构函数
   CMACDStrategy();
   CMACDStrategy(const string& symbol, int timeFrame, int magic);
   virtual ~CMACDStrategy();

   //--- 重写基类方法
   virtual bool   Init() override;
   virtual void   Deinit() override;
   virtual int    GenerateSignal(double& sl, double& tp) override;
   virtual string GetStrategyName() override { return "MACD"; }
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CMACDStrategy::CMACDStrategy() :
   CSignalGenerator(),
   m_macdHandle(INVALID_HANDLE)
{
   ArraySetAsSeries(m_macdMain, true);
   ArraySetAsSeries(m_macdSignal, true);
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CMACDStrategy::CMACDStrategy(const string& symbol, int timeFrame, int magic) :
   CSignalGenerator(symbol, timeFrame, magic),
   m_macdHandle(INVALID_HANDLE)
{
   ArraySetAsSeries(m_macdMain, true);
   ArraySetAsSeries(m_macdSignal, true);
}

//+------------------------------------------------------------------+
//| 析构函数                                                           |
//+------------------------------------------------------------------+
CMACDStrategy::~CMACDStrategy()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| 初始化                                                             |
//+------------------------------------------------------------------+
bool CMACDStrategy::Init()
{
   if(!CSignalGenerator::Init()) return false;

   //--- 创建MACD指标
   m_macdHandle = iMACD(m_symbol, m_timeFrame, MACD_Fast, MACD_Slow, MACD_Signal, MACD_AppliedPrice);

   if(m_macdHandle == INVALID_HANDLE)
   {
      LOG_ERROR("Failed to create MACD indicator");
      return false;
   }

   LOG_INFO(StringFormat("MACD Strategy initialized: Fast=%d, Slow=%d, Signal=%d",
                         MACD_Fast, MACD_Slow, MACD_Signal));
   return true;
}

//+------------------------------------------------------------------+
//| 反初始化                                                           |
//+------------------------------------------------------------------+
void CMACDStrategy::Deinit()
{
   if(m_macdHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_macdHandle);
      m_macdHandle = INVALID_HANDLE;
   }

   CSignalGenerator::Deinit();
}

//+------------------------------------------------------------------+
//| 获取MACD值                                                         |
//+------------------------------------------------------------------+
bool CMACDStrategy::GetMACDValues(int shift, double& main, double& signal)
{
   double mainBuffer[];
   double signalBuffer[];

   ArraySetAsSeries(mainBuffer, true);
   ArraySetAsSeries(signalBuffer, true);

   if(CopyBuffer(m_macdHandle, 0, shift, 1, mainBuffer) <= 0)
      return false;

   if(CopyBuffer(m_macdHandle, 1, shift, 1, signalBuffer) <= 0)
      return false;

   main = mainBuffer[0];
   signal = signalBuffer[0];

   return true;
}

//+------------------------------------------------------------------+
//| 生成交易信号                                                       |
//+------------------------------------------------------------------+
int CMACDStrategy::GenerateSignal(double& sl, double& tp)
{
   if(!m_initialized) return SIGNAL_NONE;

   //--- 获取MACD值
   double main0, signal0, main1, signal1;

   if(!GetMACDValues(0, main0, signal0)) return SIGNAL_NONE;
   if(!GetMACDValues(1, main1, signal1)) return SIGNAL_NONE;

   //--- 计算点值
   double point = MarketInfo(m_symbol, MODE_POINT);
   int digits = (int)MarketInfo(m_symbol, MODE_DIGITS);
   double pipMultiplier = (digits == 5 || digits == 3) ? 10 : 1;

   int signal = SIGNAL_NONE;

   //--- MACD信号线交叉
   // 买入信号: MACD从下向上穿越信号线,且在零轴下方
   if(main1 <= signal1 && main0 > signal0 && main0 < MACD_SignalThreshold)
   {
      signal = SIGNAL_BUY;
      sl = NormalizeDouble(Bid - MACD_SL_Pips * point * pipMultiplier, digits);
      tp = NormalizeDouble(Ask + MACD_TP_Pips * point * pipMultiplier, digits);
      g_logger.LogSignal(SIGNAL_BUY, "MACD Bullish Cross");
   }
   // 卖出信号: MACD从上向下穿越信号线,且在零轴上方
   else if(main1 >= signal1 && main0 < signal0 && main0 > -MACD_SignalThreshold)
   {
      signal = SIGNAL_SELL;
      sl = NormalizeDouble(Ask + MACD_SL_Pips * point * pipMultiplier, digits);
      tp = NormalizeDouble(Bid - MACD_TP_Pips * point * pipMultiplier, digits);
      g_logger.LogSignal(SIGNAL_SELL, "MACD Bearish Cross");
   }

   return signal;
}

//+------------------------------------------------------------------+
#endif // __MACDStrategy_MQH__
