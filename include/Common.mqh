//+------------------------------------------------------------------+
//|                                                  Common.mqh       |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __Common_MQH__
#define __Common_MQH__


#include "Constants.mqh"
#include "Types.mqh"

//+------------------------------------------------------------------+
//| 全局辅助函数                                                       |
//+------------------------------------------------------------------+

//--- 安全比较两个价格
bool PriceEqual(double price1, double price2)
{
   return(MathAbs(price1 - price2) < PRICE_EPSILON);
}

//--- 检查价格是否大于
bool PriceGreater(double price1, double price2)
{
   return(price1 > price2 + PRICE_EPSILON);
}

//--- 检查价格是否小于
bool PriceLess(double price1, double price2)
{
   return(price1 < price2 - PRICE_EPSILON);
}

//--- 获取当前点差
double GetCurrentSpread()
{
   return(MarketInfo(Symbol(), MODE_SPREAD));
}

//--- 获取点值
double GetPipValue(string symbol = "")
{
   if(symbol == "") symbol = Symbol();
   double tickValue = MarketInfo(symbol, MODE_TICKVALUE);
   double tickSize  = MarketInfo(symbol, MODE_TICKSIZE);
   double point     = MarketInfo(symbol, MODE_POINT);

   if(tickSize > 0 && point > 0)
      return(tickValue * (point / tickSize));
   return(0);
}

//--- 标准化手数
double NormalizeLots(double lots, string symbol = "")
{
   if(symbol == "") symbol = Symbol();

   double minLot = MarketInfo(symbol, MODE_MINLOT);
   double maxLot = MarketInfo(symbol, MODE_MAXLOT);
   double lotStep = MarketInfo(symbol, MODE_LOTSTEP);

   if(lotStep > 0)
      lots = MathFloor(lots / lotStep) * lotStep;

   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   return(NormalizeDouble(lots, 2));
}

//--- 标准化价格
double NormalizePrice(double price, string symbol = "")
{
   if(symbol == "") symbol = Symbol();
   int digits = (int)MarketInfo(symbol, MODE_DIGITS);
   return(NormalizeDouble(price, digits));
}

//--- 检查交易时段
bool IsTradingTime(int startHour, int endHour)
{
   int currentHour = TimeHour(TimeCurrent());

   if(startHour <= endHour)
      return(currentHour >= startHour && currentHour < endHour);
   else // 跨日时段
      return(currentHour >= startHour || currentHour < endHour);
}

//--- 获取当前交易时段
int GetCurrentSession()
{
   int hour = TimeHour(TimeCurrent());

   // 欧美重叠时段 (13-17 GMT)
   if(hour >= 13 && hour < 17)
      return SESSION_OVERLAP_EU_US;

   // 欧洲时段 (8-17 GMT)
   if(hour >= 8 && hour < 17)
      return SESSION_EUROPE;

   // 美国时段 (13-22 GMT)
   if(hour >= 13 && hour < 22)
      return SESSION_US;

   // 亚洲时段 (0-9 GMT)
   if(hour >= 0 && hour < 9)
      return SESSION_ASIA;

   return SESSION_NONE;
}

//--- 检查是否为交易日
bool IsTradingDay()
{
   int dayOfWeek = DayOfWeek();
   // 周六(6)和周日(0)不交易
   return(dayOfWeek != 0 && dayOfWeek != 6);
}

//--- 检查市场是否开放
bool IsMarketOpen()
{
   return(IsTradingDay() && IsConnected());
}

//--- 限制值在范围内
double Clamp(double value, double min, double max)
{
   if(value < min) return min;
   if(value > max) return max;
   return value;
}

//--- 百分比计算
double PercentOf(double value, double percent)
{
   return value * percent / 100.0;
}

//--- 安全除法
double SafeDivide(double numerator, double denominator, double defaultValue = 0)
{
   if(MathAbs(denominator) < PRICE_EPSILON)
      return defaultValue;
   return numerator / denominator;
}

//--- 格式化金额字符串
string FormatMoney(double amount)
{
   return StringFormat("%.2f", amount);
}

//--- 格式化百分比字符串
string FormatPercent(double percent)
{
   return StringFormat("%.2f%%", percent);
}

//--- 格式化价格字符串
string FormatPrice(double price, string symbol = "")
{
   if(symbol == "") symbol = Symbol();
   int digits = (int)MarketInfo(symbol, MODE_DIGITS);
   return StringFormat("%.*f", digits, price);
}

//--- 获取错误描述
string ErrorDescription(int errorCode)
{
   switch(errorCode)
   {
      case 0:     return "No error";
      case 1:     return "No error, but result unknown";
      case 2:     return "Common error";
      case 3:     return "Invalid trade parameters";
      case 4:     return "Trade server busy";
      case 5:     return "Old version of client terminal";
      case 6:     return "No connection with trade server";
      case 7:     return "Not enough rights";
      case 8:     return "Too frequent requests";
      case 9:     return "Malfunctional trade operation";
      case 64:    return "Account disabled";
      case 65:    return "Invalid account";
      case 128:   return "Trade timeout";
      case 129:   return "Invalid price";
      case 130:   return "Invalid stops";
      case 131:   return "Invalid trade volume";
      case 132:   return "Market closed";
      case 133:   return "Trade disabled";
      case 134:   return "Not enough money";
      case 135:   return "Price changed";
      case 136:   return "Off quotes";
      case 137:   return "Broker busy";
      case 138:   return "Requote";
      case 139:   return "Order is locked";
      case 140:   return "Long positions only allowed";
      case 141:   return "Too many requests";
      case 145:   return "Modification denied because order is too close to market";
      case 146:   return "Trade context busy";
      case 147:   return "Expirations are denied by broker";
      case 148:   return "Amount of open and pending orders has reached the limit";
      case 149:   return "Hedging is prohibited";
      case 150:   return "Prohibited by FIFO rules";
      default:    return "Unknown error";
   }
}

//+------------------------------------------------------------------+
#endif // __Common_MQH__
