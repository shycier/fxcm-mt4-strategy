//+------------------------------------------------------------------+
//|                                          PositionSizer.mqh       |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __PositionSizer_MQH__
#define __PositionSizer_MQH__


#include "../include/Constants.mqh"
#include "../include/Types.mqh"
#include "../core/Logger.mqh"

//+------------------------------------------------------------------+
//| 仓位计算器类                                                       |
//+------------------------------------------------------------------+
class CPositionSizer
{
private:
   RiskParams m_riskParams;     // 风险参数

   //--- 私有方法
   double     GetPipValue(const string symbol);

public:
   //--- 构造函数
   CPositionSizer();
   CPositionSizer(RiskParams &params);

   //--- 设置风险参数
   void       SetRiskParams(RiskParams &params) { m_riskParams = params; }
   void       SetRiskPercent(double percent);
   void       SetMinMaxLots(double minLot, double maxLot);

   //--- 计算仓位大小
   double     CalculateLotSize(double riskPercent, double stopLossPips, const string symbol = "");
   double     CalculateLotSizeByAmount(double riskAmount, double stopLossPips, const string symbol = "");
   double     CalculateLotSizeByATR(double riskPercent, int atrPeriod, int atrMultiplier, const string symbol = "", int timeFrame = PERIOD_H1);

   //--- 辅助计算
   double     CalculateRiskAmount(double accountBalance, double riskPercent);
   double     CalculateStopLossValue(double lots, double stopLossPips, const string symbol = "");

   //--- 验证
   bool       ValidateLotSize(double& lots, const string symbol = "");
   double     GetMaxAllowedLots(const string symbol = "");
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CPositionSizer::CPositionSizer()
{
   m_riskParams.riskPercent = DEFAULT_RISK_PERCENT;
   m_riskParams.maxDailyLoss = MAX_DAILY_LOSS;
   m_riskParams.maxWeeklyLoss = MAX_WEEKLY_LOSS;
   m_riskParams.maxDrawdown = MAX_DRAWDOWN;
   m_riskParams.maxDailyTrades = MAX_DAILY_TRADES;
   m_riskParams.maxPositions = MAX_OPEN_POSITIONS;
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CPositionSizer::CPositionSizer(RiskParams &params) : m_riskParams(params)
{
}

//+------------------------------------------------------------------+
//| 设置风险百分比                                                     |
//+------------------------------------------------------------------+
void CPositionSizer::SetRiskPercent(double percent)
{
   if(percent < MIN_RISK_PERCENT) percent = MIN_RISK_PERCENT;
   if(percent > MAX_RISK_PERCENT) percent = MAX_RISK_PERCENT;
   m_riskParams.riskPercent = percent;
}

//+------------------------------------------------------------------+
//| 设置最小最大仓位                                                   |
//+------------------------------------------------------------------+
void CPositionSizer::SetMinMaxLots(double minLot, double maxLot)
{
   m_riskParams.minLotSize = minLot;
   m_riskParams.maxLotSize = maxLot;
}

//+------------------------------------------------------------------+
//| 获取点值                                                           |
//+------------------------------------------------------------------+
double CPositionSizer::GetPipValue(const string symbol)
{
   string sym = (symbol == "") ? Symbol() : symbol;

   double tickValue = MarketInfo(sym, MODE_TICKVALUE);
   double tickSize = MarketInfo(sym, MODE_TICKSIZE);
   double point = MarketInfo(sym, MODE_POINT);
   int digits = (int)MarketInfo(sym, MODE_DIGITS);

   double pipValue = 0;

   if(tickSize > 0 && point > 0)
   {
      pipValue = tickValue * (point / tickSize);

      // 5位或3位小数的品种
      if(digits == 5 || digits == 3)
         pipValue *= 10;
   }

   return pipValue;
}

//+------------------------------------------------------------------+
//| 根据风险百分比计算仓位                                             |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateLotSize(double riskPercent, double stopLossPips, const string symbol)
{
   string sym = (symbol == "") ? Symbol() : symbol;

   //--- 验证输入
   if(riskPercent <= 0 || stopLossPips <= 0)
   {
      LOG_ERROR("Invalid risk percent or stop loss");
      return 0;
   }

   //--- 限制风险百分比
   riskPercent = Clamp(riskPercent, MIN_RISK_PERCENT, MAX_RISK_PERCENT);

   //--- 计算风险金额
   double accountBalance = AccountBalance();
   double riskAmount = CalculateRiskAmount(accountBalance, riskPercent);

   //--- 获取点值
   double pipValue = GetPipValue(sym);
   if(pipValue <= 0)
   {
      LOG_ERROR("Failed to get pip value");
      return 0;
   }

   //--- 计算仓位: LotSize = RiskAmount / (StopLossPips * PipValue)
   double lots = riskAmount / (stopLossPips * pipValue);

   //--- 验证并标准化
   if(!ValidateLotSize(lots, sym))
      return 0;

   return lots;
}

//+------------------------------------------------------------------+
//| 根据固定金额计算仓位                                               |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateLotSizeByAmount(double riskAmount, double stopLossPips, const string symbol)
{
   string sym = (symbol == "") ? Symbol() : symbol;

   if(riskAmount <= 0 || stopLossPips <= 0)
   {
      LOG_ERROR("Invalid risk amount or stop loss");
      return 0;
   }

   double pipValue = GetPipValue(sym);
   if(pipValue <= 0) return 0;

   double lots = riskAmount / (stopLossPips * pipValue);

   if(!ValidateLotSize(lots, sym))
      return 0;

   return lots;
}

//+------------------------------------------------------------------+
//| 根据ATR计算仓位                                                   |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateLotSizeByATR(double riskPercent, int atrPeriod, int atrMultiplier,
                                             const string symbol, int timeFrame)
{
   string sym = (symbol == "") ? Symbol() : symbol;

   //--- 计算ATR
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   int count = atrPeriod + 1;
   if(CopyHigh(sym, timeFrame, 0, count, high) <= 0) return 0;
   if(CopyLow(sym, timeFrame, 0, count, low) <= 0) return 0;
   if(CopyClose(sym, timeFrame, 0, count, close) <= 0) return 0;

   double atrSum = 0;
   double point = MarketInfo(sym, MODE_POINT);

   for(int i = 0; i < atrPeriod; i++)
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

   double atr = atrSum / atrPeriod;
   double atrPips = atr / point;

   // 5位或3位小数的品种
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   if(digits == 5 || digits == 3)
      atrPips /= 10;

   double stopLossPips = atrPips * atrMultiplier;

   return CalculateLotSize(riskPercent, stopLossPips, sym);
}

//+------------------------------------------------------------------+
//| 计算风险金额                                                       |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateRiskAmount(double accountBalance, double riskPercent)
{
   return accountBalance * riskPercent / 100.0;
}

//+------------------------------------------------------------------+
//| 计算止损价值                                                       |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateStopLossValue(double lots, double stopLossPips, const string symbol)
{
   string sym = (symbol == "") ? Symbol() : symbol;
   double pipValue = GetPipValue(sym);
   return lots * stopLossPips * pipValue;
}

//+------------------------------------------------------------------+
//| 验证仓位大小                                                       |
//+------------------------------------------------------------------+
bool CPositionSizer::ValidateLotSize(double& lots, const string symbol)
{
   string sym = (symbol == "") ? Symbol() : symbol;

   double minLot = MarketInfo(sym, MODE_MINLOT);
   double maxLot = MarketInfo(sym, MODE_MAXLOT);
   double lotStep = MarketInfo(sym, MODE_LOTSTEP);

   if(minLot <= 0 || maxLot <= 0)
   {
      LOG_ERROR("Invalid lot limits");
      return false;
   }

   //--- 调整到步长的整数倍
   if(lotStep > 0)
      lots = MathFloor(lots / lotStep) * lotStep;

   //--- 限制范围
   if(lots < minLot)
   {
      LOG_WARNING(StringFormat("Lot size %.2f is below minimum %.2f", lots, minLot));
      lots = minLot;
   }

   if(lots > maxLot)
   {
      LOG_WARNING(StringFormat("Lot size %.2f is above maximum %.2f", lots, maxLot));
      lots = maxLot;
   }

   //--- 检查保证金
   double marginRequired = MarketInfo(sym, MODE_MARGINREQUIRED) * lots;
   double freeMargin = AccountFreeMargin();

   if(marginRequired > freeMargin)
   {
      LOG_ERROR(StringFormat("Insufficient margin: Required=%.2f, Available=%.2f", marginRequired, freeMargin));
      // 尝试计算可用保证金允许的最大仓位
      lots = MathFloor(freeMargin / MarketInfo(sym, MODE_MARGINREQUIRED) / lotStep) * lotStep;
      if(lots < minLot)
      {
         LOG_ERROR("Cannot afford minimum lot size");
         return false;
      }
   }

   lots = NormalizeDouble(lots, 2);
   return true;
}

//+------------------------------------------------------------------+
//| 获取允许的最大仓位                                                 |
//+------------------------------------------------------------------+
double CPositionSizer::GetMaxAllowedLots(const string symbol)
{
   string sym = (symbol == "") ? Symbol() : symbol;

   double freeMargin = AccountFreeMargin();
   double marginRequired = MarketInfo(sym, MODE_MARGINREQUIRED);
   double maxLot = MarketInfo(sym, MODE_MAXLOT);
   double lotStep = MarketInfo(sym, MODE_LOTSTEP);

   if(marginRequired <= 0) return 0;

   double lots = freeMargin / marginRequired;
   lots = MathFloor(lots / lotStep) * lotStep;

   if(lots > maxLot) lots = maxLot;

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
#endif // __PositionSizer_MQH__
