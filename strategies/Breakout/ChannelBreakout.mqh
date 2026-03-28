//+------------------------------------------------------------------+
//|                                       ChannelBreakout.mqh       |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __ChannelBreakout_MQH__
#define __ChannelBreakout_MQH__


#include "../../core/SignalGenerator.mqh"
#include "../../utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| 输入参数                                                           |
//+------------------------------------------------------------------+
input int    CB_ChannelPeriod = 20;    // 通道周期
input int    CB_EntryOffset = 0;       // 入场偏移点数
input int    CB_SL_Pips = 30;          // 止损点数
input int    CB_TP_Pips = 60;          // 止盈点数
input bool   CB_UseATR_SL = false;     // 使用ATR止损
input int    CB_ATR_Period = 14;       // ATR周期
input double CB_ATR_Multiplier = 2.0;  // ATR倍数

//+------------------------------------------------------------------+
//| 通道突破策略类                                                     |
//+------------------------------------------------------------------+
class CChannelBreakout : public CSignalGenerator
{
private:
   double   m_channelHigh;      // 通道高点
   double   m_channelLow;       // 通道低点
   datetime m_lastBreakTime;    // 上次突破时间
   int      m_breakCooldown;    // 突破冷却时间(分钟)

   //--- 辅助方法
   void     CalculateChannel();

public:
   //--- 构造函数/析构函数
   CChannelBreakout();
   CChannelBreakout(const string symbol, int timeFrame, int magic);
   virtual ~CChannelBreakout();

   //--- 重写基类方法
   virtual bool   Init() override;
   virtual void   Deinit() override;
   virtual int    GenerateSignal(double& sl, double& tp) override;
   virtual string GetStrategyName() override { return "Channel Breakout"; }

   //--- 配置方法
   void     SetBreakCooldown(int minutes) { m_breakCooldown = minutes; }
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CChannelBreakout::CChannelBreakout()
{
   m_channelHigh = 0;
   m_channelLow = 0;
   m_lastBreakTime = 0;
   m_breakCooldown = 60;
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CChannelBreakout::CChannelBreakout(const string symbol, int timeFrame, int magic)
{
   m_symbol = symbol;
   m_timeFrame = timeFrame;
   m_magic = magic;
   m_channelHigh = 0;
   m_channelLow = 0;
   m_lastBreakTime = 0;
   m_breakCooldown = 60;
}

//+------------------------------------------------------------------+
//| 析构函数                                                           |
//+------------------------------------------------------------------+
CChannelBreakout::~CChannelBreakout()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| 初始化                                                             |
//+------------------------------------------------------------------+
bool CChannelBreakout::Init()
{
   if(!CSignalGenerator::Init()) return false;

   CalculateChannel();

   LOG_INFO(StringFormat("Channel Breakout initialized: Period=%d", CB_ChannelPeriod));
   return true;
}

//+------------------------------------------------------------------+
//| 反初始化                                                           |
//+------------------------------------------------------------------+
void CChannelBreakout::Deinit()
{
   CSignalGenerator::Deinit();
}

//+------------------------------------------------------------------+
//| 计算通道                                                           |
//+------------------------------------------------------------------+
void CChannelBreakout::CalculateChannel()
{
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   // 从第1根K线开始(跳过当前K线)
   int copiedHigh = CopyHigh(m_symbol, m_timeFrame, 1, CB_ChannelPeriod, high);
   int copiedLow = CopyLow(m_symbol, m_timeFrame, 1, CB_ChannelPeriod, low);

   // 检查是否成功复制了足够的数据
   if(copiedHigh < CB_ChannelPeriod || copiedLow < CB_ChannelPeriod) return;

   // 检查数组大小
   if(ArraySize(high) < CB_ChannelPeriod || ArraySize(low) < CB_ChannelPeriod) return;

   m_channelHigh = high[ArrayMaximum(high, CB_ChannelPeriod, 0)];
   m_channelLow = low[ArrayMinimum(low, CB_ChannelPeriod, 0)];
}

//+------------------------------------------------------------------+
//| 生成交易信号                                                       |
//+------------------------------------------------------------------+
int CChannelBreakout::GenerateSignal(double& sl, double& tp)
{
   if(!m_initialized) return SIGNAL_NONE;

   //--- 检查冷却时间
   if(m_breakCooldown > 0)
   {
      int minutesSinceBreak = (int)(TimeCurrent() - m_lastBreakTime) / 60;
      if(minutesSinceBreak < m_breakCooldown)
         return SIGNAL_NONE;
   }

   //--- 更新通道
   CalculateChannel();

   if(m_channelHigh == 0 || m_channelLow == 0) return SIGNAL_NONE;

   //--- 获取当前价格
   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(m_symbol, m_timeFrame, 0, 1, close) <= 0) return SIGNAL_NONE;

   double currentClose = close[0];

   //--- 计算点值
   double point = MarketInfo(m_symbol, MODE_POINT);
   int digits = (int)MarketInfo(m_symbol, MODE_DIGITS);
   double pipMultiplier = (digits == 5 || digits == 3) ? 10 : 1;

   //--- 计算ATR止损
   double atrSL = 0;
   if(CB_UseATR_SL)
   {
      double atr = CalculateATR(m_symbol, m_timeFrame, CB_ATR_Period);
      atrSL = atr * CB_ATR_Multiplier;
   }

   int signal = SIGNAL_NONE;

   //--- 向上突破通道高点
   if(currentClose > m_channelHigh + CB_EntryOffset * point * pipMultiplier)
   {
      signal = SIGNAL_BUY;

      if(CB_UseATR_SL && atrSL > 0)
         sl = NormalizeDouble(Bid - atrSL, digits);
      else
         sl = NormalizeDouble(Bid - CB_SL_Pips * point * pipMultiplier, digits);

      tp = NormalizeDouble(Ask + CB_TP_Pips * point * pipMultiplier, digits);

      m_lastBreakTime = TimeCurrent();
      g_logger.LogSignal(SIGNAL_BUY, StringFormat("Upper Channel Break (%.5f)", m_channelHigh));
   }
   //--- 向下突破通道低点
   else if(currentClose < m_channelLow - CB_EntryOffset * point * pipMultiplier)
   {
      signal = SIGNAL_SELL;

      if(CB_UseATR_SL && atrSL > 0)
         sl = NormalizeDouble(Ask + atrSL, digits);
      else
         sl = NormalizeDouble(Ask + CB_SL_Pips * point * pipMultiplier, digits);

      tp = NormalizeDouble(Bid - CB_TP_Pips * point * pipMultiplier, digits);

      m_lastBreakTime = TimeCurrent();
      g_logger.LogSignal(SIGNAL_SELL, StringFormat("Lower Channel Break (%.5f)", m_channelLow));
   }

   return signal;
}

//+------------------------------------------------------------------+
#endif // __ChannelBreakout_MQH__
