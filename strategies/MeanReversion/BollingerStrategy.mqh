//+------------------------------------------------------------------+
//|                                        BollingerStrategy.mqh    |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __BollingerStrategy_MQH__
#define __BollingerStrategy_MQH__


#include "../../core/SignalGenerator.mqh"
#include "../../utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| 输入参数                                                           |
//+------------------------------------------------------------------+
input int    BB_Period = 20;           // 布林带周期
input double BB_Deviation = 2.0;       // 标准差倍数
input int    BB_AppliedPrice = 0;      // 应用价格
input int    BB_SL_Pips = 20;          // 止损点数
input int    BB_TP_Pips = 40;          // 止盈点数
input bool   BB_ReturnToMean = true;   // 回归中轨止盈

//+------------------------------------------------------------------+
//| 布林带均值回归策略类                                               |
//+------------------------------------------------------------------+
class CBollingerStrategy : public CSignalGenerator
{
private:
   //--- 辅助方法
   bool     GetBBValues(int shift, double& upper, double& middle, double& lower);

public:
   //--- 构造函数/析构函数
   CBollingerStrategy();
   CBollingerStrategy(const string symbol, int timeFrame, int magic);
   virtual ~CBollingerStrategy();

   //--- 重写基类方法
   virtual bool   Init() override;
   virtual void   Deinit() override;
   virtual int    GenerateSignal(double& sl, double& tp) override;
   virtual string GetStrategyName() override { return "Bollinger Bands"; }
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CBollingerStrategy::CBollingerStrategy()
{
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CBollingerStrategy::CBollingerStrategy(const string symbol, int timeFrame, int magic)
{
   m_symbol = symbol;
   m_timeFrame = timeFrame;
   m_magic = magic;
}

//+------------------------------------------------------------------+
//| 析构函数                                                           |
//+------------------------------------------------------------------+
CBollingerStrategy::~CBollingerStrategy()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| 初始化                                                             |
//+------------------------------------------------------------------+
bool CBollingerStrategy::Init()
{
   if(!CSignalGenerator::Init()) return false;

   //--- MT4直接调用指标函数,无需创建句柄
   LOG_INFO(StringFormat("Bollinger Strategy initialized: Period=%d, Dev=%.1f",
                         BB_Period, BB_Deviation));
   return true;
}

//+------------------------------------------------------------------+
//| 反初始化                                                           |
//+------------------------------------------------------------------+
void CBollingerStrategy::Deinit()
{
   //--- MT4无需释放指标句柄
   CSignalGenerator::Deinit();
}

//+------------------------------------------------------------------+
//| 获取布林带值                                                       |
//+------------------------------------------------------------------+
bool CBollingerStrategy::GetBBValues(int shift, double& upper, double& middle, double& lower)
{
   //--- 检查是否有足够的数据
   if(Bars(m_symbol, m_timeFrame) < BB_Period + shift + 1)
   {
      upper = 0;
      middle = 0;
      lower = 0;
      return false;
   }

   //--- MT4风格:直接调用iBands函数
   upper = iBands(m_symbol, m_timeFrame, BB_Period, BB_Deviation, 0, BB_AppliedPrice, MODE_UPPER, shift);
   middle = iBands(m_symbol, m_timeFrame, BB_Period, BB_Deviation, 0, BB_AppliedPrice, MODE_MAIN, shift);
   lower = iBands(m_symbol, m_timeFrame, BB_Period, BB_Deviation, 0, BB_AppliedPrice, MODE_LOWER, shift);

   return (upper != 0 && middle != 0 && lower != 0);
}

//+------------------------------------------------------------------+
//| 生成交易信号                                                       |
//+------------------------------------------------------------------+
int CBollingerStrategy::GenerateSignal(double& sl, double& tp)
{
   if(!m_initialized) return SIGNAL_NONE;

   //--- 获取价格数据
   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(m_symbol, m_timeFrame, 0, 2, close) <= 0) return SIGNAL_NONE;

   //--- 获取布林带值
   double upper0, middle0, lower0;
   double upper1, middle1, lower1;

   if(!GetBBValues(0, upper0, middle0, lower0)) return SIGNAL_NONE;
   if(!GetBBValues(1, upper1, middle1, lower1)) return SIGNAL_NONE;

   //--- 计算点值
   double point = MarketInfo(m_symbol, MODE_POINT);
   int digits = (int)MarketInfo(m_symbol, MODE_DIGITS);
   double pipMultiplier = (digits == 5 || digits == 3) ? 10 : 1;

   int signal = SIGNAL_NONE;

   //--- 均值回归信号
   // 价格触及下轨后反弹
   if(close[1] <= lower1 && close[0] > lower0)
   {
      signal = SIGNAL_BUY;
      sl = NormalizeDouble(Bid - BB_SL_Pips * point * pipMultiplier, digits);

      if(BB_ReturnToMean)
         tp = NormalizeDouble(middle0, digits); // 止盈设在中轨
      else
         tp = NormalizeDouble(Ask + BB_TP_Pips * point * pipMultiplier, digits);

      g_logger.LogSignal(SIGNAL_BUY, "BB Lower Band Bounce");
   }
   // 价格触及上轨后回落
   else if(close[1] >= upper1 && close[0] < upper0)
   {
      signal = SIGNAL_SELL;
      sl = NormalizeDouble(Ask + BB_SL_Pips * point * pipMultiplier, digits);

      if(BB_ReturnToMean)
         tp = NormalizeDouble(middle0, digits); // 止盈设在中轨
      else
         tp = NormalizeDouble(Bid - BB_TP_Pips * point * pipMultiplier, digits);

      g_logger.LogSignal(SIGNAL_SELL, "BB Upper Band Rejection");
   }

   return signal;
}

//+------------------------------------------------------------------+
#endif // __BollingerStrategy_MQH__
