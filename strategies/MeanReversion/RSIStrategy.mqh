//+------------------------------------------------------------------+
//|                                              RSIStrategy.mqh    |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __RSIStrategy_MQH__
#define __RSIStrategy_MQH__


#include "../../core/SignalGenerator.mqh"
#include "../../utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| 输入参数                                                           |
//+------------------------------------------------------------------+
input int    RSI_Period = 14;          // RSI周期
input int    RSI_AppliedPrice = 0;     // 应用价格
input int    RSI_Overbought = 70;      // 超买阈值
input int    RSI_Oversold = 30;        // 超卖阈值
input int    RSI_SL_Pips = 25;         // 止损点数
input int    RSI_TP_Pips = 50;         // 止盈点数
input bool   RSI_UseConfirmation = true; // 使用确认信号

//+------------------------------------------------------------------+
//| RSI均值回归策略类                                                  |
//+------------------------------------------------------------------+
class CRSIStrategy : public CSignalGenerator
{
private:
   double   m_prevRSI;          // 上一个RSI值

   //--- 辅助方法
   double   GetRSIValue(int shift);

public:
   //--- 构造函数/析构函数
   CRSIStrategy();
   CRSIStrategy(const string symbol, int timeFrame, int magic);
   virtual ~CRSIStrategy();

   //--- 重写基类方法
   virtual bool   Init() override;
   virtual void   Deinit() override;
   virtual int    GenerateSignal(double& sl, double& tp) override;
   virtual string GetStrategyName() override { return "RSI Mean Reversion"; }
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CRSIStrategy::CRSIStrategy()
{
   m_prevRSI = 50;
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CRSIStrategy::CRSIStrategy(const string symbol, int timeFrame, int magic)
{
   m_symbol = symbol;
   m_timeFrame = timeFrame;
   m_magic = magic;
   m_prevRSI = 50;
}

//+------------------------------------------------------------------+
//| 析构函数                                                           |
//+------------------------------------------------------------------+
CRSIStrategy::~CRSIStrategy()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| 初始化                                                             |
//+------------------------------------------------------------------+
bool CRSIStrategy::Init()
{
   if(!CSignalGenerator::Init()) return false;

   //--- MT4直接调用指标函数,无需创建句柄
   LOG_INFO(StringFormat("RSI Strategy initialized: Period=%d, OB=%d, OS=%d",
                         RSI_Period, RSI_Overbought, RSI_Oversold));
   return true;
}

//+------------------------------------------------------------------+
//| 反初始化                                                           |
//+------------------------------------------------------------------+
void CRSIStrategy::Deinit()
{
   //--- MT4无需释放指标句柄
   CSignalGenerator::Deinit();
}

//+------------------------------------------------------------------+
//| 获取RSI值                                                          |
//+------------------------------------------------------------------+
double CRSIStrategy::GetRSIValue(int shift)
{
   //--- MT4风格:直接调用iRSI函数返回RSI值
   double rsi = iRSI(m_symbol, m_timeFrame, RSI_Period, RSI_AppliedPrice, shift);

   // 如果返回0(错误),返回中性值50
   if(rsi == 0)
      return 50;

   return rsi;
}

//+------------------------------------------------------------------+
//| 生成交易信号                                                       |
//+------------------------------------------------------------------+
int CRSIStrategy::GenerateSignal(double& sl, double& tp)
{
   if(!m_initialized) return SIGNAL_NONE;

   //--- 获取RSI值
   double rsi0 = GetRSIValue(0);
   double rsi1 = GetRSIValue(1);

   if(rsi0 == 50 && rsi1 == 50) return SIGNAL_NONE;

   //--- 计算点值
   double point = MarketInfo(m_symbol, MODE_POINT);
   int digits = (int)MarketInfo(m_symbol, MODE_DIGITS);
   double pipMultiplier = (digits == 5 || digits == 3) ? 10 : 1;

   int signal = SIGNAL_NONE;

   //--- 均值回归信号
   if(RSI_UseConfirmation)
   {
      // 使用确认模式: RSI从超卖区回升
      if(rsi1 <= RSI_Oversold && rsi0 > RSI_Oversold && rsi0 > m_prevRSI)
      {
         signal = SIGNAL_BUY;
         sl = NormalizeDouble(Bid - RSI_SL_Pips * point * pipMultiplier, digits);
         tp = NormalizeDouble(Ask + RSI_TP_Pips * point * pipMultiplier, digits);
         g_logger.LogSignal(SIGNAL_BUY, StringFormat("RSI Oversold Bounce (%.1f)", rsi0));
      }
      // RSI从超买区回落
      else if(rsi1 >= RSI_Overbought && rsi0 < RSI_Overbought && rsi0 < m_prevRSI)
      {
         signal = SIGNAL_SELL;
         sl = NormalizeDouble(Ask + RSI_SL_Pips * point * pipMultiplier, digits);
         tp = NormalizeDouble(Bid - RSI_TP_Pips * point * pipMultiplier, digits);
         g_logger.LogSignal(SIGNAL_SELL, StringFormat("RSI Overbought Drop (%.1f)", rsi0));
      }
   }
   else
   {
      // 简单模式: 直接在极值区入场
      if(rsi0 <= RSI_Oversold)
      {
         signal = SIGNAL_BUY;
         sl = NormalizeDouble(Bid - RSI_SL_Pips * point * pipMultiplier, digits);
         tp = NormalizeDouble(Ask + RSI_TP_Pips * point * pipMultiplier, digits);
      }
      else if(rsi0 >= RSI_Overbought)
      {
         signal = SIGNAL_SELL;
         sl = NormalizeDouble(Ask + RSI_SL_Pips * point * pipMultiplier, digits);
         tp = NormalizeDouble(Bid - RSI_TP_Pips * point * pipMultiplier, digits);
      }
   }

   m_prevRSI = rsi0;
   return signal;
}

//+------------------------------------------------------------------+
#endif // __RSIStrategy_MQH__
