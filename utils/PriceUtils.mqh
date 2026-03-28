//+------------------------------------------------------------------+
//|                                              PriceUtils.mqh      |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __PriceUtils_MQH__
#define __PriceUtils_MQH__


#include "../include/Constants.mqh"

//+------------------------------------------------------------------+
//| 价格工具函数                                                       |
//+------------------------------------------------------------------+

//--- 获取当前买价
double GetBid(const string symbol = "")
{
   if(symbol == "") return Bid;
   return MarketInfo(symbol, MODE_BID);
}

//--- 获取当前卖价
double GetAsk(const string symbol = "")
{
   if(symbol == "") return Ask;
   return MarketInfo(symbol, MODE_ASK);
}

//--- 获取点差
double GetSpread(const string symbol = "")
{
   if(symbol == "") symbol = Symbol();
   return MarketInfo(symbol, MODE_SPREAD);
}

//--- 获取点差(以点为单位)
double GetSpreadInPips(const string symbol = "")
{
   if(symbol == "") symbol = Symbol();
   double spread = MarketInfo(symbol, MODE_SPREAD);
   double point = MarketInfo(symbol, MODE_POINT);
   int digits = (int)MarketInfo(symbol, MODE_DIGITS);

   // 5位小数的品种需要除以10
   if(digits == 5 || digits == 3)
      return spread / 10.0;

   return spread;
}

//--- 标准化价格
double NormalizePrice(double price, const string symbol = "")
{
   if(symbol == "") symbol = Symbol();
   int digits = (int)MarketInfo(symbol, MODE_DIGITS);
   return NormalizeDouble(price, digits);
}

//--- 标准化手数
double NormalizeLots(double lots, const string symbol = "")
{
   if(symbol == "") symbol = Symbol();

   double minLot = MarketInfo(symbol, MODE_MINLOT);
   double maxLot = MarketInfo(symbol, MODE_MAXLOT);
   double lotStep = MarketInfo(symbol, MODE_LOTSTEP);

   // 调整到步长的整数倍
   if(lotStep > 0)
      lots = MathFloor(lots / lotStep) * lotStep;

   // 限制在最小最大范围内
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   return NormalizeDouble(lots, 2);
}

//--- 点转换为价格
double PipsToPrice(double pips, const string symbol = "")
{
   if(symbol == "") symbol = Symbol();
   double point = MarketInfo(symbol, MODE_POINT);
   int digits = (int)MarketInfo(symbol, MODE_DIGITS);

   // 5位小数的品种，1点 = 10 point
   if(digits == 5 || digits == 3)
      return pips * 10 * point;

   return pips * point;
}

//--- 价格转换为点
double PriceToPips(double price, const string symbol = "")
{
   if(symbol == "") symbol = Symbol();
   double point = MarketInfo(symbol, MODE_POINT);
   int digits = (int)MarketInfo(symbol, MODE_DIGITS);

   // 5位小数的品种，需要除以10
   if(digits == 5 || digits == 3)
      return price / point / 10.0;

   return price / point;
}

//--- 计算止损价格
double CalculateStopLoss(int orderType, double entryPrice, double slPips, const string symbol = "")
{
   if(symbol == "") symbol = Symbol();

   double slPrice = PipsToPrice(slPips, symbol);

   if(orderType == OP_BUY)
      return NormalizePrice(entryPrice - slPrice, symbol);
   else
      return NormalizePrice(entryPrice + slPrice, symbol);
}

//--- 计算止盈价格
double CalculateTakeProfit(int orderType, double entryPrice, double tpPips, const string symbol = "")
{
   if(symbol == "") symbol = Symbol();

   double tpPrice = PipsToPrice(tpPips, symbol);

   if(orderType == OP_BUY)
      return NormalizePrice(entryPrice + tpPrice, symbol);
   else
      return NormalizePrice(entryPrice - tpPrice, symbol);
}

//--- 获取每点价值
double GetPipValue(const string symbol = "", double lots = 1.0)
{
   if(symbol == "") symbol = Symbol();

   double tickValue = MarketInfo(symbol, MODE_TICKVALUE);
   double tickSize = MarketInfo(symbol, MODE_TICKSIZE);
   double point = MarketInfo(symbol, MODE_POINT);
   int digits = (int)MarketInfo(symbol, MODE_DIGITS);

   double pipValue;

   if(tickSize > 0 && point > 0)
   {
      pipValue = tickValue * (point / tickSize);

      // 5位小数的品种
      if(digits == 5 || digits == 3)
         pipValue *= 10;
   }
   else
   {
      pipValue = 0;
   }

   return pipValue * lots;
}

//--- 获取保证金要求
double GetMarginRequired(double lots, const string symbol = "")
{
   if(symbol == "") symbol = Symbol();
   return MarketInfo(symbol, MODE_MARGINREQUIRED) * lots;
}

//--- 计算盈亏
double CalculateProfit(int orderType, double openPrice, double closePrice, double lots, const string symbol = "")
{
   if(symbol == "") symbol = Symbol();

   double point = MarketInfo(symbol, MODE_POINT);
   double tickValue = MarketInfo(symbol, MODE_TICKVALUE);
   double tickSize = MarketInfo(symbol, MODE_TICKSIZE);

   double priceDiff;

   if(orderType == OP_BUY)
      priceDiff = closePrice - openPrice;
   else
      priceDiff = openPrice - closePrice;

   // 转换为货币
   double profit = priceDiff / tickSize * tickValue * lots;

   return profit;
}

//--- 检查价格是否在范围内
bool IsPriceInRange(double price, double lower, double upper)
{
   return (price >= lower && price <= upper);
}

//--- 获取日内最高价
double GetDailyHigh(const string symbol = "")
{
   if(symbol == "") symbol = Symbol();

   double high[];
   ArraySetAsSeries(high, true);

   if(CopyHigh(symbol, PERIOD_D1, 0, 1, high) > 0)
      return high[0];

   return 0;
}

//--- 获取日内最低价
double GetDailyLow(const string symbol = "")
{
   if(symbol == "") symbol = Symbol();

   double low[];
   ArraySetAsSeries(low, true);

   if(CopyLow(symbol, PERIOD_D1, 0, 1, low) > 0)
      return low[0];

   return 0;
}

//--- 计算日内波动幅度
double GetDailyRange(const string symbol = "")
{
   return GetDailyHigh(symbol) - GetDailyLow(symbol);
}

//--- 计算平均真实波幅
double GetATR(const string symbol, int period, int timeFrame = PERIOD_H1)
{
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   if(CopyHigh(symbol, timeFrame, 0, period + 1, high) <= 0) return 0;
   if(CopyLow(symbol, timeFrame, 0, period + 1, low) <= 0) return 0;
   if(CopyClose(symbol, timeFrame, 0, period + 1, close) <= 0) return 0;

   double atrSum = 0;

   for(int i = 0; i < period; i++)
   {
      double tr = MathMax(
         high[i] - low[i],
         MathMax(
            MathAbs(high[i] - close[i + 1]),
            MathAbs(low[i] - close[i + 1])
         )
      );
      atrSum += tr;
   }

   return atrSum / period;
}

//--- 获取支撑位（基于前期低点）
double FindSupportLevel(const string symbol, int lookback = 20, int timeFrame = PERIOD_H1)
{
   double low[];
   ArraySetAsSeries(low, true);

   if(CopyLow(symbol, timeFrame, 0, lookback, low) <= 0) return 0;

   double minLow = low[0];
   for(int i = 1; i < lookback; i++)
   {
      if(low[i] < minLow)
         minLow = low[i];
   }

   return minLow;
}

//--- 获取阻力位（基于前期高点）
double FindResistanceLevel(const string symbol, int lookback = 20, int timeFrame = PERIOD_H1)
{
   double high[];
   ArraySetAsSeries(high, true);

   if(CopyHigh(symbol, timeFrame, 0, lookback, high) <= 0) return 0;

   double maxHigh = high[0];
   for(int i = 1; i < lookback; i++)
   {
      if(high[i] > maxHigh)
         maxHigh = high[i];
   }

   return maxHigh;
}

//+------------------------------------------------------------------+
#endif // __PriceUtils_MQH__
