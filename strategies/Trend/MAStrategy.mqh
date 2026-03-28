//+------------------------------------------------------------------+
//|                                              MAStrategy.mqh     |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __MAStrategy_MQH__
#define __MAStrategy_MQH__


#include "../../core/SignalGenerator.mqh"
#include "../../utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| 输入参数                                                           |
//+------------------------------------------------------------------+
input int    MA_FastPeriod = 10;       // 快速MA周期
input int    MA_SlowPeriod = 20;       // 慢速MA周期
input int    MA_Method = 0;            // MA方法 (0=SMA, 1=EMA, 2=SMMA, 3=LWMA)
input int    MA_AppliedPrice = 0;      // 应用价格 (0=Close)
input int    MA_SL_Pips = 30;          // 止损点数
input int    MA_TP_Pips = 60;          // 止盈点数
input bool   MA_UseTrailing = false;   // 使用移动止损
input int    MA_TrailPips = 20;        // 移动止损点数

//+------------------------------------------------------------------+
//| MA交叉策略类                                                       |
//+------------------------------------------------------------------+
class CMAStrategy : public CSignalGenerator
{
private:
   int      m_fastHandle;       // 快速MA句柄
   int      m_slowHandle;       // 慢速MA句柄
   double   m_fastMA[];         // 快速MA值
   double   m_slowMA[];         // 慢速MA值
   int      m_prevSignal;       // 上一个信号

   //--- 方法
   double   GetMAValue(int handle, int shift);

public:
   //--- 构造函数/析构函数
   CMAStrategy();
   CMAStrategy(const string symbol, int timeFrame, int magic);
   virtual ~CMAStrategy();

   //--- 重写基类方法
   virtual bool   Init() override;
   virtual void   Deinit() override;
   virtual int    GenerateSignal(double& sl, double& tp) override;
   virtual string GetStrategyName() override { return "MA Cross"; }
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CMAStrategy::CMAStrategy() :
   CSignalGenerator(),
   m_fastHandle(INVALID_HANDLE),
   m_slowHandle(INVALID_HANDLE),
   m_prevSignal(SIGNAL_NONE)
{
   ArraySetAsSeries(m_fastMA, true);
   ArraySetAsSeries(m_slowMA, true);
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CMAStrategy::CMAStrategy(const string symbol, int timeFrame, int magic) :
   CSignalGenerator(symbol, timeFrame, magic),
   m_fastHandle(INVALID_HANDLE),
   m_slowHandle(INVALID_HANDLE),
   m_prevSignal(SIGNAL_NONE)
{
   ArraySetAsSeries(m_fastMA, true);
   ArraySetAsSeries(m_slowMA, true);
}

//+------------------------------------------------------------------+
//| 析构函数                                                           |
//+------------------------------------------------------------------+
CMAStrategy::~CMAStrategy()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| 初始化                                                             |
//+------------------------------------------------------------------+
bool CMAStrategy::Init()
{
   if(!CSignalGenerator::Init()) return false;

   //--- 创建MA指标
   m_fastHandle = iMA(m_symbol, m_timeFrame, MA_FastPeriod, 0, MA_Method, MA_AppliedPrice);
   m_slowHandle = iMA(m_symbol, m_timeFrame, MA_SlowPeriod, 0, MA_Method, MA_AppliedPrice);

   if(m_fastHandle == INVALID_HANDLE || m_slowHandle == INVALID_HANDLE)
   {
      LOG_ERROR("Failed to create MA indicators");
      return false;
   }

   LOG_INFO(StringFormat("MA Strategy initialized: Fast=%d, Slow=%d", MA_FastPeriod, MA_SlowPeriod));
   return true;
}

//+------------------------------------------------------------------+
//| 反初始化                                                           |
//+------------------------------------------------------------------+
void CMAStrategy::Deinit()
{
   if(m_fastHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_fastHandle);
      m_fastHandle = INVALID_HANDLE;
   }

   if(m_slowHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_slowHandle);
      m_slowHandle = INVALID_HANDLE;
   }

   CSignalGenerator::Deinit();
}

//+------------------------------------------------------------------+
//| 获取MA值                                                           |
//+------------------------------------------------------------------+
double CMAStrategy::GetMAValue(int handle, int shift)
{
   double value[];
   ArraySetAsSeries(value, true);

   if(CopyBuffer(handle, 0, shift, 1, value) <= 0)
      return 0;

   return value[0];
}

//+------------------------------------------------------------------+
//| 生成交易信号                                                       |
//+------------------------------------------------------------------+
int CMAStrategy::GenerateSignal(double& sl, double& tp)
{
   if(!m_initialized) return SIGNAL_NONE;

   //--- 获取MA值
   double fastMA0 = GetMAValue(m_fastHandle, 0);
   double fastMA1 = GetMAValue(m_fastHandle, 1);
   double slowMA0 = GetMAValue(m_slowHandle, 0);
   double slowMA1 = GetMAValue(m_slowHandle, 1);

   if(fastMA0 == 0 || fastMA1 == 0 || slowMA0 == 0 || slowMA1 == 0)
      return SIGNAL_NONE;

   //--- 计算点值
   double point = MarketInfo(m_symbol, MODE_POINT);
   int digits = (int)MarketInfo(m_symbol, MODE_DIGITS);
   double pipMultiplier = (digits == 5 || digits == 3) ? 10 : 1;

   int signal = SIGNAL_NONE;

   //--- 检查交叉
   // 金叉: 快线从下向上穿越慢线
   if(fastMA1 <= slowMA1 && fastMA0 > slowMA0)
   {
      signal = SIGNAL_BUY;
      sl = NormalizeDouble(Bid - MA_SL_Pips * point * pipMultiplier, digits);
      tp = NormalizeDouble(Ask + MA_TP_Pips * point * pipMultiplier, digits);
      g_logger.LogSignal(SIGNAL_BUY, "MA Golden Cross");
   }
   // 死叉: 快线从上向下穿越慢线
   else if(fastMA1 >= slowMA1 && fastMA0 < slowMA0)
   {
      signal = SIGNAL_SELL;
      sl = NormalizeDouble(Ask + MA_SL_Pips * point * pipMultiplier, digits);
      tp = NormalizeDouble(Bid - MA_TP_Pips * point * pipMultiplier, digits);
      g_logger.LogSignal(SIGNAL_SELL, "MA Death Cross");
   }

   m_prevSignal = signal;
   return signal;
}

//+------------------------------------------------------------------+
#endif // __MAStrategy_MQH__
