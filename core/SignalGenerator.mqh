//+------------------------------------------------------------------+
//|                                            SignalGenerator.mqh   |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#pragma once

#include "../include/Constants.mqh"
#include "../include/Types.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| 信号生成器基类                                                     |
//+------------------------------------------------------------------+
class CSignalGenerator
{
protected:
   string         m_symbol;        // 交易品种
   int            m_timeFrame;     // 时间框架
   int            m_magic;         // 魔术数字
   StrategyParams m_params;        // 策略参数
   bool           m_initialized;   // 是否已初始化

   //--- 历史数据缓存
   double         m_high[];        // 最高价
   double         m_low[];         // 最低价
   double         m_close[];       // 收盘价
   double         m_open[];        // 开盘价
   long           m_volume[];      // 成交量

   //--- 辅助方法
   bool           UpdateData(int bars = 500);
   double         GetHighest(int start, int count);
   double         GetLowest(int start, int count);
   double         GetClose(int shift);
   double         GetOpen(int shift);
   double         GetHigh(int shift);
   double         GetLow(int shift);

public:
   //--- 构造函数/析构函数
   CSignalGenerator();
   CSignalGenerator(const string& symbol, int timeFrame, int magic);
   virtual ~CSignalGenerator();

   //--- 初始化方法
   virtual bool   Init() { m_initialized = true; return true; }
   virtual void   Deinit() { m_initialized = false; }

   //--- 设置方法
   void           SetSymbol(const string& symbol) { m_symbol = symbol; }
   void           SetTimeFrame(int tf) { m_timeFrame = tf; }
   void           SetMagic(int magic) { m_magic = magic; }
   void           SetParams(const StrategyParams& params) { m_params = params; }

   //--- 获取方法
   string         GetSymbol() const { return m_symbol; }
   int            GetTimeFrame() const { return m_timeFrame; }
   int            GetMagic() const { return m_magic; }
   bool           IsInitialized() const { return m_initialized; }

   //--- 核心方法 (子类必须重写)
   virtual int    GenerateSignal(double& sl, double& tp);
   virtual string GetStrategyName() { return "Base"; }

   //--- 信号验证
   bool           ValidateSignal(TradeSignal& signal);
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CSignalGenerator::CSignalGenerator() :
   m_symbol(Symbol()),
   m_timeFrame(PERIOD_H1),
   m_magic(0),
   m_initialized(false)
{
   ArraySetAsSeries(m_high, true);
   ArraySetAsSeries(m_low, true);
   ArraySetAsSeries(m_close, true);
   ArraySetAsSeries(m_open, true);
   ArraySetAsSeries(m_volume, true);
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CSignalGenerator::CSignalGenerator(const string& symbol, int timeFrame, int magic) :
   m_symbol(symbol),
   m_timeFrame(timeFrame),
   m_magic(magic),
   m_initialized(false)
{
   ArraySetAsSeries(m_high, true);
   ArraySetAsSeries(m_low, true);
   ArraySetAsSeries(m_close, true);
   ArraySetAsSeries(m_open, true);
   ArraySetAsSeries(m_volume, true);
}

//+------------------------------------------------------------------+
//| 析构函数                                                           |
//+------------------------------------------------------------------+
CSignalGenerator::~CSignalGenerator()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| 更新历史数据                                                       |
//+------------------------------------------------------------------+
bool CSignalGenerator::UpdateData(int bars)
{
   //--- 复制价格数据
   if(CopyHigh(m_symbol, m_timeFrame, 0, bars, m_high) <= 0) return false;
   if(CopyLow(m_symbol, m_timeFrame, 0, bars, m_low) <= 0) return false;
   if(CopyClose(m_symbol, m_timeFrame, 0, bars, m_close) <= 0) return false;
   if(CopyOpen(m_symbol, m_timeFrame, 0, bars, m_open) <= 0) return false;
   if(CopyTickVolume(m_symbol, m_timeFrame, 0, bars, m_volume) <= 0) return false;

   return true;
}

//+------------------------------------------------------------------+
//| 获取最高价                                                         |
//+------------------------------------------------------------------+
double CSignalGenerator::GetHighest(int start, int count)
{
   double highest = m_high[start];
   for(int i = start; i < start + count && i < ArraySize(m_high); i++)
   {
      if(m_high[i] > highest)
         highest = m_high[i];
   }
   return highest;
}

//+------------------------------------------------------------------+
//| 获取最低价                                                         |
//+------------------------------------------------------------------+
double CSignalGenerator::GetLowest(int start, int count)
{
   double lowest = m_low[start];
   for(int i = start; i < start + count && i < ArraySize(m_low); i++)
   {
      if(m_low[i] < lowest)
         lowest = m_low[i];
   }
   return lowest;
}

//+------------------------------------------------------------------+
//| 获取收盘价                                                         |
//+------------------------------------------------------------------+
double CSignalGenerator::GetClose(int shift)
{
   if(shift < 0 || shift >= ArraySize(m_close)) return 0;
   return m_close[shift];
}

//+------------------------------------------------------------------+
//| 获取开盘价                                                         |
//+------------------------------------------------------------------+
double CSignalGenerator::GetOpen(int shift)
{
   if(shift < 0 || shift >= ArraySize(m_open)) return 0;
   return m_open[shift];
}

//+------------------------------------------------------------------+
//| 获取最高价                                                         |
//+------------------------------------------------------------------+
double CSignalGenerator::GetHigh(int shift)
{
   if(shift < 0 || shift >= ArraySize(m_high)) return 0;
   return m_high[shift];
}

//+------------------------------------------------------------------+
//| 获取最低价                                                         |
//+------------------------------------------------------------------+
double CSignalGenerator::GetLow(int shift)
{
   if(shift < 0 || shift >= ArraySize(m_low)) return 0;
   return m_low[shift];
}

//+------------------------------------------------------------------+
//| 生成信号 (基类默认无信号)                                          |
//+------------------------------------------------------------------+
int CSignalGenerator::GenerateSignal(double& sl, double& tp)
{
   if(!m_initialized) return SIGNAL_NONE;

   if(!UpdateData())
   {
      LOG_ERROR("Failed to update price data");
      return SIGNAL_NONE;
   }

   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| 验证信号                                                           |
//+------------------------------------------------------------------+
bool CSignalGenerator::ValidateSignal(TradeSignal& signal)
{
   //--- 检查信号类型
   if(signal.type != SIGNAL_BUY && signal.type != SIGNAL_SELL)
      return false;

   //--- 检查价格有效性
   if(signal.entryPrice <= 0 || signal.stopLoss <= 0 || signal.takeProfit <= 0)
      return false;

   //--- 检查止损止盈逻辑
   if(signal.type == SIGNAL_BUY)
   {
      if(signal.stopLoss >= signal.entryPrice) return false;
      if(signal.takeProfit <= signal.entryPrice) return false;
   }
   else // SIGNAL_SELL
   {
      if(signal.stopLoss <= signal.entryPrice) return false;
      if(signal.takeProfit >= signal.entryPrice) return false;
   }

   //--- 检查仓位大小
   if(signal.lotSize <= 0) return false;

   return true;
}

//+------------------------------------------------------------------+