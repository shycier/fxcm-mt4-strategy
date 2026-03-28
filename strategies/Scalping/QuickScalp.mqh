//+------------------------------------------------------------------+
//|                                           QuickScalp.mqh        |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __QuickScalp_MQH__
#define __QuickScalp_MQH__


#include "../../core/SignalGenerator.mqh"
#include "../../utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| 输入参数                                                           |
//+------------------------------------------------------------------+
input int    QS_FastMA = 5;            // 快速MA周期
input int    QS_SlowMA = 13;           // 慢速MA周期
input int    QS_RSI_Period = 7;        // RSI周期
input int    QS_RSI_Level = 50;        // RSI过滤水平
input int    QS_SL_Pips = 10;          // 止损点数(小)
input int    QS_TP_Pips = 15;          // 止盈点数(小)
input int    QS_MaxSpread = 3;         // 最大允许点差
input bool   QS_FilterSpread = true;   // 过滤高点差

//+------------------------------------------------------------------+
//| 快速剥头皮策略类                                                   |
//+------------------------------------------------------------------+
class CQuickScalp : public CSignalGenerator
{
private:
   int      m_fastMAHandle;     // 快速MA句柄
   int      m_slowMAHandle;     // 慢速MA句柄
   int      m_rsiHandle;        // RSI句柄

   datetime m_lastTradeTime;    // 上次交易时间
   int      m_minTradeInterval; // 最小交易间隔(秒)

   //--- 辅助方法
   bool     CheckSpread();
   bool     CheckTradeInterval();
   double   GetMAValue(int handle, int shift);
   double   GetRSIValue(int shift);

public:
   //--- 构造函数/析构函数
   CQuickScalp();
   CQuickScalp(const string& symbol, int timeFrame, int magic);
   virtual ~CQuickScalp();

   //--- 重写基类方法
   virtual bool   Init() override;
   virtual void   Deinit() override;
   virtual int    GenerateSignal(double& sl, double& tp) override;
   virtual string GetStrategyName() override { return "Quick Scalp"; }

   //--- 配置方法
   void     SetMinTradeInterval(int seconds) { m_minTradeInterval = seconds; }
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CQuickScalp::CQuickScalp() :
   CSignalGenerator(),
   m_fastMAHandle(INVALID_HANDLE),
   m_slowMAHandle(INVALID_HANDLE),
   m_rsiHandle(INVALID_HANDLE),
   m_lastTradeTime(0),
   m_minTradeInterval(30)
{
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CQuickScalp::CQuickScalp(const string& symbol, int timeFrame, int magic) :
   CSignalGenerator(symbol, timeFrame, magic),
   m_fastMAHandle(INVALID_HANDLE),
   m_slowMAHandle(INVALID_HANDLE),
   m_rsiHandle(INVALID_HANDLE),
   m_lastTradeTime(0),
   m_minTradeInterval(30)
{
}

//+------------------------------------------------------------------+
//| 析构函数                                                           |
//+------------------------------------------------------------------+
CQuickScalp::~CQuickScalp()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| 初始化                                                             |
//+------------------------------------------------------------------+
bool CQuickScalp::Init()
{
   if(!CSignalGenerator::Init()) return false;

   //--- 创建指标
   m_fastMAHandle = iMA(m_symbol, m_timeFrame, QS_FastMA, 0, MODE_EMA, PRICE_CLOSE);
   m_slowMAHandle = iMA(m_symbol, m_timeFrame, QS_SlowMA, 0, MODE_EMA, PRICE_CLOSE);
   m_rsiHandle = iRSI(m_symbol, m_timeFrame, QS_RSI_Period, PRICE_CLOSE);

   if(m_fastMAHandle == INVALID_HANDLE || m_slowMAHandle == INVALID_HANDLE || m_rsiHandle == INVALID_HANDLE)
   {
      LOG_ERROR("Failed to create indicators for scalping");
      return false;
   }

   LOG_INFO(StringFormat("Quick Scalp initialized: FastMA=%d, SlowMA=%d, RSI=%d",
                         QS_FastMA, QS_SlowMA, QS_RSI_Period));
   return true;
}

//+------------------------------------------------------------------+
//| 反初始化                                                           |
//+------------------------------------------------------------------+
void CQuickScalp::Deinit()
{
   if(m_fastMAHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_fastMAHandle);
      m_fastMAHandle = INVALID_HANDLE;
   }

   if(m_slowMAHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_slowMAHandle);
      m_slowMAHandle = INVALID_HANDLE;
   }

   if(m_rsiHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_rsiHandle);
      m_rsiHandle = INVALID_HANDLE;
   }

   CSignalGenerator::Deinit();
}

//+------------------------------------------------------------------+
//| 检查点差                                                           |
//+------------------------------------------------------------------+
bool CQuickScalp::CheckSpread()
{
   if(!QS_FilterSpread) return true;

   double spread = MarketInfo(m_symbol, MODE_SPREAD);
   int digits = (int)MarketInfo(m_symbol, MODE_DIGITS);

   // 5位或3位小数的品种
   double spreadPips = (digits == 5 || digits == 3) ? spread / 10.0 : spread;

   return (spreadPips <= QS_MaxSpread);
}

//+------------------------------------------------------------------+
//| 检查交易间隔                                                       |
//+------------------------------------------------------------------+
bool CQuickScalp::CheckTradeInterval()
{
   if(m_minTradeInterval <= 0) return true;

   int elapsed = (int)(TimeCurrent() - m_lastTradeTime);
   return (elapsed >= m_minTradeInterval);
}

//+------------------------------------------------------------------+
//| 获取MA值                                                           |
//+------------------------------------------------------------------+
double CQuickScalp::GetMAValue(int handle, int shift)
{
   double buffer[];
   ArraySetAsSeries(buffer, true);

   if(CopyBuffer(handle, 0, shift, 1, buffer) <= 0)
      return 0;

   return buffer[0];
}

//+------------------------------------------------------------------+
//| 获取RSI值                                                          |
//+------------------------------------------------------------------+
double CQuickScalp::GetRSIValue(int shift)
{
   double buffer[];
   ArraySetAsSeries(buffer, true);

   if(CopyBuffer(m_rsiHandle, 0, shift, 1, buffer) <= 0)
      return 50;

   return buffer[0];
}

//+------------------------------------------------------------------+
//| 生成交易信号                                                       |
//+------------------------------------------------------------------+
int CQuickScalp::GenerateSignal(double& sl, double& tp)
{
   if(!m_initialized) return SIGNAL_NONE;

   //--- 检查交易条件
   if(!CheckSpread())
   {
      LOG_DEBUG("Spread too high for scalping");
      return SIGNAL_NONE;
   }

   if(!CheckTradeInterval())
   {
      return SIGNAL_NONE;
   }

   //--- 获取指标值
   double fastMA0 = GetMAValue(m_fastMAHandle, 0);
   double fastMA1 = GetMAValue(m_fastMAHandle, 1);
   double slowMA0 = GetMAValue(m_slowMAHandle, 0);
   double slowMA1 = GetMAValue(m_slowMAHandle, 1);
   double rsi = GetRSIValue(0);

   if(fastMA0 == 0 || fastMA1 == 0 || slowMA0 == 0 || slowMA1 == 0)
      return SIGNAL_NONE;

   //--- 计算点值
   double point = MarketInfo(m_symbol, MODE_POINT);
   int digits = (int)MarketInfo(m_symbol, MODE_DIGITS);
   double pipMultiplier = (digits == 5 || digits == 3) ? 10 : 1;

   int signal = SIGNAL_NONE;

   //--- 剥头皮信号 - 快速MA交叉 + RSI过滤
   // 买入信号: 快MA上穿慢MA + RSI > 50 (趋势确认)
   if(fastMA1 <= slowMA1 && fastMA0 > slowMA0 && rsi > QS_RSI_Level)
   {
      signal = SIGNAL_BUY;
      sl = NormalizeDouble(Bid - QS_SL_Pips * point * pipMultiplier, digits);
      tp = NormalizeDouble(Ask + QS_TP_Pips * point * pipMultiplier, digits);

      m_lastTradeTime = TimeCurrent();
      g_logger.LogSignal(SIGNAL_BUY, StringFormat("Scalp Buy (RSI: %.1f)", rsi));
   }
   // 卖出信号: 快MA下穿慢MA + RSI < 50
   else if(fastMA1 >= slowMA1 && fastMA0 < slowMA0 && rsi < QS_RSI_Level)
   {
      signal = SIGNAL_SELL;
      sl = NormalizeDouble(Ask + QS_SL_Pips * point * pipMultiplier, digits);
      tp = NormalizeDouble(Bid - QS_TP_Pips * point * pipMultiplier, digits);

      m_lastTradeTime = TimeCurrent();
      g_logger.LogSignal(SIGNAL_SELL, StringFormat("Scalp Sell (RSI: %.1f)", rsi));
   }

   return signal;
}

//+------------------------------------------------------------------+
#endif // __QuickScalp_MQH__
