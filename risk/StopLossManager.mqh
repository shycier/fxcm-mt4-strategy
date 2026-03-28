//+------------------------------------------------------------------+
//|                                        StopLossManager.mqh       |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __StopLossManager_MQH__
#define __StopLossManager_MQH__


#include "../include/Constants.mqh"
#include "../include/Types.mqh"
#include "../core/Logger.mqh"
#include "../utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| 止损类型枚举                                                       |
//+------------------------------------------------------------------+
enum StopLossType
{
   SL_FIXED = 0,        // 固定点数止损
   SL_ATR = 1,          // ATR止损
   SL_PERCENT = 2,      // 百分比止损
   SL_SWING = 3,        // 波动止损
   SL_SUPPORT = 4       // 支撑位止损
};

//+------------------------------------------------------------------+
//| 止损管理器类                                                       |
//+------------------------------------------------------------------+
class CStopLossManager
{
private:
   string        m_symbol;          // 交易品种
   int           m_timeFrame;       // 时间框架
   StopLossType  m_slType;          // 止损类型
   double        m_fixedPips;       // 固定点数
   int           m_atrPeriod;       // ATR周期
   double        m_atrMultiplier;   // ATR倍数
   double        m_percentValue;    // 百分比值
   int           m_swingBars;       // 波动K线数

   //--- 私有方法
   double        CalculateATRStop(int direction);
   double        CalculateSwingStop(int direction, int bars);
   double        FindSwingHigh(int bars);
   double        FindSwingLow(int bars);

public:
   //--- 构造函数
   CStopLossManager();
   CStopLossManager(const string& symbol, int timeFrame);

   //--- 配置方法
   void          SetSymbol(const string& symbol) { m_symbol = symbol; }
   void          SetTimeFrame(int tf) { m_timeFrame = tf; }
   void          SetStopLossType(StopLossType type) { m_slType = type; }

   void          SetFixedStop(double pips) { m_slType = SL_FIXED; m_fixedPips = pips; }
   void          SetATRStop(int period, double multiplier) { m_slType = SL_ATR; m_atrPeriod = period; m_atrMultiplier = multiplier; }
   void          SetPercentStop(double percent) { m_slType = SL_PERCENT; m_percentValue = percent; }
   void          SetSwingStop(int bars) { m_slType = SL_SWING; m_swingBars = bars; }

   //--- 计算止损
   double        CalculateStopLoss(int orderType, double entryPrice);
   double        CalculateStopLossPips(int orderType);

   //--- 计算止盈
   double        CalculateTakeProfit(int orderType, double entryPrice, double riskRewardRatio = 2.0);
   double        CalculateTakeProfitPips(double stopLossPips, double riskRewardRatio = 2.0);

   //--- 移动止损
   double        CalculateTrailingStop(int orderType, double currentPrice, double currentSL, double trailPips);
   bool          ShouldTrail(int orderType, double openPrice, double currentPrice, double trailStart);

   //--- 验证
   bool          ValidateStopLoss(int orderType, double entryPrice, double stopLoss);
   bool          ValidateTakeProfit(int orderType, double entryPrice, double takeProfit);

   //--- 工具方法
   double        PipsToPrice(double pips);
   double        PriceToPips(double priceDiff);
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CStopLossManager::CStopLossManager() :
   m_symbol(Symbol()),
   m_timeFrame(PERIOD_H1),
   m_slType(SL_FIXED),
   m_fixedPips(50),
   m_atrPeriod(14),
   m_atrMultiplier(2.0),
   m_percentValue(1.0),
   m_swingBars(10)
{
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CStopLossManager::CStopLossManager(const string& symbol, int timeFrame) :
   m_symbol(symbol),
   m_timeFrame(timeFrame),
   m_slType(SL_FIXED),
   m_fixedPips(50),
   m_atrPeriod(14),
   m_atrMultiplier(2.0),
   m_percentValue(1.0),
   m_swingBars(10)
{
}

//+------------------------------------------------------------------+
//| 点数转价格                                                         |
//+------------------------------------------------------------------+
double CStopLossManager::PipsToPrice(double pips)
{
   double point = MarketInfo(m_symbol, MODE_POINT);
   int digits = (int)MarketInfo(m_symbol, MODE_DIGITS);

   // 5位或3位小数的品种
   if(digits == 5 || digits == 3)
      return pips * 10 * point;

   return pips * point;
}

//+------------------------------------------------------------------+
//| 价格转点数                                                         |
//+------------------------------------------------------------------+
double CStopLossManager::PriceToPips(double priceDiff)
{
   double point = MarketInfo(m_symbol, MODE_POINT);
   int digits = (int)MarketInfo(m_symbol, MODE_DIGITS);

   double pips = priceDiff / point;

   // 5位或3位小数的品种
   if(digits == 5 || digits == 3)
      pips /= 10;

   return MathAbs(pips);
}

//+------------------------------------------------------------------+
//| 计算ATR止损                                                        |
//+------------------------------------------------------------------+
double CStopLossManager::CalculateATRStop(int direction)
{
   double atr = CalculateATR(m_symbol, m_timeFrame, m_atrPeriod);
   return atr * m_atrMultiplier;
}

//+------------------------------------------------------------------+
//| 计算波动止损                                                       |
//+------------------------------------------------------------------+
double CStopLossManager::CalculateSwingStop(int direction, int bars)
{
   if(direction > 0) // 多头
   {
      return FindSwingLow(bars);
   }
   else // 空头
   {
      return FindSwingHigh(bars);
   }
}

//+------------------------------------------------------------------+
//| 查找波动高点                                                       |
//+------------------------------------------------------------------+
double CStopLossManager::FindSwingHigh(int bars)
{
   double high[];
   ArraySetAsSeries(high, true);

   if(CopyHigh(m_symbol, m_timeFrame, 0, bars * 2, high) <= 0)
      return 0;

   double maxHigh = high[0];
   for(int i = 0; i < bars; i++)
   {
      if(high[i] > maxHigh)
         maxHigh = high[i];
   }

   return maxHigh;
}

//+------------------------------------------------------------------+
//| 查找波动低点                                                       |
//+------------------------------------------------------------------+
double CStopLossManager::FindSwingLow(int bars)
{
   double low[];
   ArraySetAsSeries(low, true);

   if(CopyLow(m_symbol, m_timeFrame, 0, bars * 2, low) <= 0)
      return 0;

   double minLow = low[0];
   for(int i = 0; i < bars; i++)
   {
      if(low[i] < minLow)
         minLow = low[i];
   }

   return minLow;
}

//+------------------------------------------------------------------+
//| 计算止损价格                                                       |
//+------------------------------------------------------------------+
double CStopLossManager::CalculateStopLoss(int orderType, double entryPrice)
{
   double slPrice = 0;
   double point = MarketInfo(m_symbol, MODE_POINT);
   int digits = (int)MarketInfo(m_symbol, MODE_DIGITS);

   switch(m_slType)
   {
      case SL_FIXED:
      {
         double slDistance = PipsToPrice(m_fixedPips);
         if(orderType == OP_BUY)
            slPrice = entryPrice - slDistance;
         else
            slPrice = entryPrice + slDistance;
         break;
      }

      case SL_ATR:
      {
         double atr = CalculateATRStop(orderType == OP_BUY ? 1 : -1);
         if(orderType == OP_BUY)
            slPrice = entryPrice - atr;
         else
            slPrice = entryPrice + atr;
         break;
      }

      case SL_PERCENT:
      {
         double slDistance = entryPrice * m_percentValue / 100.0;
         if(orderType == OP_BUY)
            slPrice = entryPrice - slDistance;
         else
            slPrice = entryPrice + slDistance;
         break;
      }

      case SL_SWING:
      {
         if(orderType == OP_BUY)
            slPrice = FindSwingLow(m_swingBars);
         else
            slPrice = FindSwingHigh(m_swingBars);
         break;
      }

      default:
         slPrice = 0;
   }

   //--- 标准化价格
   if(slPrice > 0)
      slPrice = NormalizeDouble(slPrice, digits);

   return slPrice;
}

//+------------------------------------------------------------------+
//| 计算止损点数                                                       |
//+------------------------------------------------------------------+
double CStopLossManager::CalculateStopLossPips(int orderType)
{
   double entryPrice = (orderType == OP_BUY) ? MarketInfo(m_symbol, MODE_ASK) : MarketInfo(m_symbol, MODE_BID);
   double slPrice = CalculateStopLoss(orderType, entryPrice);

   if(slPrice <= 0) return 0;

   double priceDiff = MathAbs(entryPrice - slPrice);
   return PriceToPips(priceDiff);
}

//+------------------------------------------------------------------+
//| 计算止盈价格                                                       |
//+------------------------------------------------------------------+
double CStopLossManager::CalculateTakeProfit(int orderType, double entryPrice, double riskRewardRatio)
{
   double slPrice = CalculateStopLoss(orderType, entryPrice);
   if(slPrice <= 0) return 0;

   double slDistance = MathAbs(entryPrice - slPrice);
   double tpDistance = slDistance * riskRewardRatio;

   double tpPrice;
   if(orderType == OP_BUY)
      tpPrice = entryPrice + tpDistance;
   else
      tpPrice = entryPrice - tpDistance;

   int digits = (int)MarketInfo(m_symbol, MODE_DIGITS);
   return NormalizeDouble(tpPrice, digits);
}

//+------------------------------------------------------------------+
//| 计算止盈点数                                                       |
//+------------------------------------------------------------------+
double CStopLossManager::CalculateTakeProfitPips(double stopLossPips, double riskRewardRatio)
{
   return stopLossPips * riskRewardRatio;
}

//+------------------------------------------------------------------+
//| 计算移动止损                                                       |
//+------------------------------------------------------------------+
double CStopLossManager::CalculateTrailingStop(int orderType, double currentPrice, double currentSL, double trailPips)
{
   double trailDistance = PipsToPrice(trailPips);
   double newSL = 0;

   if(orderType == OP_BUY)
   {
      newSL = currentPrice - trailDistance;
      if(newSL > currentSL)
         return newSL;
   }
   else
   {
      newSL = currentPrice + trailDistance;
      if(currentSL == 0 || newSL < currentSL)
         return newSL;
   }

   return 0; // 不需要更新
}

//+------------------------------------------------------------------+
//| 检查是否应该移动止损                                               |
//+------------------------------------------------------------------+
bool CStopLossManager::ShouldTrail(int orderType, double openPrice, double currentPrice, double trailStart)
{
   double profitPips;

   if(orderType == OP_BUY)
      profitPips = PriceToPips(currentPrice - openPrice);
   else
      profitPips = PriceToPips(openPrice - currentPrice);

   return (profitPips >= trailStart);
}

//+------------------------------------------------------------------+
//| 验证止损                                                           |
//+------------------------------------------------------------------+
bool CStopLossManager::ValidateStopLoss(int orderType, double entryPrice, double stopLoss)
{
   if(stopLoss <= 0)
   {
      LOG_ERROR("Stop loss is zero or negative");
      return false;
   }

   double point = MarketInfo(m_symbol, MODE_POINT);
   double minStop = MarketInfo(m_symbol, MODE_STOPLEVEL) * point;

   if(orderType == OP_BUY)
   {
      if(stopLoss >= entryPrice)
      {
         LOG_ERROR("Buy stop loss must be below entry price");
         return false;
      }
      if(entryPrice - stopLoss < minStop)
      {
         LOG_WARNING("Stop loss too close, adjusting to minimum");
      }
   }
   else
   {
      if(stopLoss <= entryPrice)
      {
         LOG_ERROR("Sell stop loss must be above entry price");
         return false;
      }
      if(stopLoss - entryPrice < minStop)
      {
         LOG_WARNING("Stop loss too close, adjusting to minimum");
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| 验证止盈                                                           |
//+------------------------------------------------------------------+
bool CStopLossManager::ValidateTakeProfit(int orderType, double entryPrice, double takeProfit)
{
   if(takeProfit <= 0)
   {
      LOG_ERROR("Take profit is zero or negative");
      return false;
   }

   double point = MarketInfo(m_symbol, MODE_POINT);
   double minStop = MarketInfo(m_symbol, MODE_STOPLEVEL) * point;

   if(orderType == OP_BUY)
   {
      if(takeProfit <= entryPrice)
      {
         LOG_ERROR("Buy take profit must be above entry price");
         return false;
      }
      if(takeProfit - entryPrice < minStop)
      {
         LOG_WARNING("Take profit too close, adjusting to minimum");
      }
   }
   else
   {
      if(takeProfit >= entryPrice)
      {
         LOG_ERROR("Sell take profit must be below entry price");
         return false;
      }
      if(entryPrice - takeProfit < minStop)
      {
         LOG_WARNING("Take profit too close, adjusting to minimum");
      }
   }

   return true;
}

//+------------------------------------------------------------------+
#endif // __StopLossManager_MQH__
