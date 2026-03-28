//+------------------------------------------------------------------+
//|                                            RiskManager.mqh       |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __RiskManager_MQH__
#define __RiskManager_MQH__


#include "../include/Constants.mqh"
#include "../include/Types.mqh"
#include "../core/Logger.mqh"

//+------------------------------------------------------------------+
//| 风险管理器类                                                       |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   RiskParams      m_riskParams;        // 风险参数
   AccountStats    m_accountStats;      // 账户统计

   //--- 跟踪数据
   double          m_startBalance;      // 初始余额(日)
   double          m_weeklyStartBalance; // 初始余额(周)
   double          m_peakEquity;        // 最高净值
   double          m_currentDrawdown;   // 当前回撤

   int             m_dailyTrades;       // 日交易次数
   int             m_dailyWins;         // 日盈利次数
   int             m_dailyLosses;       // 日亏损次数
   double          m_dailyPL;           // 日盈亏
   double          m_weeklyPL;          // 周盈亏

   datetime        m_lastTradeDay;      // 上次交易日
   datetime        m_lastTradeWeek;     // 上次交易周

   //--- 私有方法
   void            UpdateDailyStats();
   void            UpdateWeeklyStats();
   void            UpdateDrawdown();
   bool            IsNewDay();
   bool            IsNewWeek();

public:
   //--- 构造函数
   CRiskManager();
   CRiskManager(RiskParams &params);

   //--- 设置参数
   void            SetRiskParams(RiskParams &params) { m_riskParams = params; }
   void            SetMaxDailyLoss(double percent) { m_riskParams.maxDailyLoss = percent; }
   void            SetMaxWeeklyLoss(double percent) { m_riskParams.maxWeeklyLoss = percent; }
   void            SetMaxDrawdown(double percent) { m_riskParams.maxDrawdown = percent; }
   void            SetMaxDailyTrades(int count) { m_riskParams.maxDailyTrades = count; }
   void            SetMaxPositions(int count) { m_riskParams.maxPositions = count; }

   //--- 更新统计
   void            Update();

   //--- 风险检查
   bool            CheckDailyLoss();
   bool            CheckWeeklyLoss();
   bool            CheckDrawdown();
   bool            CheckDailyTrades();
   bool            CheckMaxPositions(int currentPositions);
   bool            CanTrade();

   //--- 记录交易
   void            RecordTrade(double profit);
   void            IncrementDailyTrades() { m_dailyTrades++; }

   //--- 获取统计
   double          GetDailyPL() const { return m_dailyPL; }
   double          GetWeeklyPL() const { return m_weeklyPL; }
   double          GetCurrentDrawdown() const { return m_currentDrawdown; }
   int             GetDailyTrades() const { return m_dailyTrades; }
   int             GetDailyWins() const { return m_dailyWins; }
   int             GetDailyLosses() const { return m_dailyLosses; }
   double          GetPeakEquity() const { return m_peakEquity; }

   //--- 重置
   void            ResetDailyStats();
   void            ResetWeeklyStats();
   void            ResetAll();
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager() :
   m_startBalance(0),
   m_weeklyStartBalance(0),
   m_peakEquity(0),
   m_currentDrawdown(0),
   m_dailyTrades(0),
   m_dailyWins(0),
   m_dailyLosses(0),
   m_dailyPL(0),
   m_weeklyPL(0),
   m_lastTradeDay(0),
   m_lastTradeWeek(0)
{
   m_riskParams.riskPercent = DEFAULT_RISK_PERCENT;
   m_riskParams.maxDailyLoss = MAX_DAILY_LOSS;
   m_riskParams.maxWeeklyLoss = MAX_WEEKLY_LOSS;
   m_riskParams.maxDrawdown = MAX_DRAWDOWN;
   m_riskParams.maxDailyTrades = MAX_DAILY_TRADES;
   m_riskParams.maxPositions = MAX_OPEN_POSITIONS;

   //--- 初始化
   m_startBalance = AccountBalance();
   m_weeklyStartBalance = m_startBalance;
   m_peakEquity = AccountEquity();
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(RiskParams &params)
{
   m_riskParams = params;
   m_startBalance = 0;
   m_weeklyStartBalance = 0;
   m_peakEquity = 0;
   m_currentDrawdown = 0;
   m_dailyTrades = 0;
   m_dailyWins = 0;
   m_dailyLosses = 0;
   m_dailyPL = 0;
   m_weeklyPL = 0;
   m_lastTradeDay = 0;
   m_lastTradeWeek = 0;

   m_startBalance = AccountBalance();
   m_weeklyStartBalance = m_startBalance;
   m_peakEquity = AccountEquity();
}

//+------------------------------------------------------------------+
//| 更新统计数据                                                       |
//+------------------------------------------------------------------+
void CRiskManager::Update()
{
   //--- 检查是否新的一天/周
   UpdateDailyStats();
   UpdateWeeklyStats();

   //--- 更新回撤
   UpdateDrawdown();

   //--- 更新账户统计
   m_accountStats.Update();
}

//+------------------------------------------------------------------+
//| 更新日统计                                                         |
//+------------------------------------------------------------------+
void CRiskManager::UpdateDailyStats()
{
   if(IsNewDay())
   {
      ResetDailyStats();
      m_startBalance = AccountBalance();
      m_lastTradeDay = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| 更新周统计                                                         |
//+------------------------------------------------------------------+
void CRiskManager::UpdateWeeklyStats()
{
   if(IsNewWeek())
   {
      ResetWeeklyStats();
      m_weeklyStartBalance = AccountBalance();
      m_lastTradeWeek = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| 更新回撤                                                           |
//+------------------------------------------------------------------+
void CRiskManager::UpdateDrawdown()
{
   double equity = AccountEquity();

   //--- 更新峰值
   if(equity > m_peakEquity)
      m_peakEquity = equity;

   //--- 计算回撤
   if(m_peakEquity > 0)
   {
      m_currentDrawdown = (m_peakEquity - equity) / m_peakEquity * 100.0;
      if(m_currentDrawdown < 0) m_currentDrawdown = 0;
   }
}

//+------------------------------------------------------------------+
//| 检查是否新的一天                                                   |
//+------------------------------------------------------------------+
bool CRiskManager::IsNewDay()
{
   datetime current = TimeCurrent();
   int currentDay = TimeDayOfYear(current);
   int lastDay = TimeDayOfYear(m_lastTradeDay);

   return (currentDay != lastDay);
}

//+------------------------------------------------------------------+
//| 检查是否新的一周                                                   |
//+------------------------------------------------------------------+
bool CRiskManager::IsNewWeek()
{
   datetime current = TimeCurrent();
   int currentWeek = TimeMonth(current) * 100 + TimeDay(current) / 7;
   int lastWeek = TimeMonth(m_lastTradeWeek) * 100 + TimeDay(m_lastTradeWeek) / 7;

   return (currentWeek != lastWeek);
}

//+------------------------------------------------------------------+
//| 检查日亏损限制                                                     |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDailyLoss()
{
   if(m_riskParams.maxDailyLoss <= 0) return true;

   double dailyLossPercent = MathAbs(m_dailyPL) / m_startBalance * 100.0;

   if(dailyLossPercent >= m_riskParams.maxDailyLoss)
   {
      LOG_WARNING(StringFormat("Daily loss limit reached: %.2f%% >= %.2f%%",
                               dailyLossPercent, m_riskParams.maxDailyLoss));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| 检查周亏损限制                                                     |
//+------------------------------------------------------------------+
bool CRiskManager::CheckWeeklyLoss()
{
   if(m_riskParams.maxWeeklyLoss <= 0) return true;

   double weeklyLossPercent = MathAbs(m_weeklyPL) / m_weeklyStartBalance * 100.0;

   if(weeklyLossPercent >= m_riskParams.maxWeeklyLoss)
   {
      LOG_WARNING(StringFormat("Weekly loss limit reached: %.2f%% >= %.2f%%",
                               weeklyLossPercent, m_riskParams.maxWeeklyLoss));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| 检查最大回撤                                                       |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDrawdown()
{
   if(m_riskParams.maxDrawdown <= 0) return true;

   UpdateDrawdown();

   if(m_currentDrawdown >= m_riskParams.maxDrawdown)
   {
      LOG_WARNING(StringFormat("Max drawdown reached: %.2f%% >= %.2f%%",
                               m_currentDrawdown, m_riskParams.maxDrawdown));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| 检查日交易次数                                                     |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDailyTrades()
{
   if(m_riskParams.maxDailyTrades <= 0) return true;

   if(m_dailyTrades >= m_riskParams.maxDailyTrades)
   {
      LOG_WARNING(StringFormat("Daily trade limit reached: %d >= %d",
                               m_dailyTrades, m_riskParams.maxDailyTrades));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| 检查最大持仓数                                                     |
//+------------------------------------------------------------------+
bool CRiskManager::CheckMaxPositions(int currentPositions)
{
   if(m_riskParams.maxPositions <= 0) return true;

   if(currentPositions >= m_riskParams.maxPositions)
   {
      LOG_WARNING(StringFormat("Max positions reached: %d >= %d",
                               currentPositions, m_riskParams.maxPositions));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| 检查是否可以交易                                                   |
//+------------------------------------------------------------------+
bool CRiskManager::CanTrade()
{
   if(!CheckDailyLoss()) return false;
   if(!CheckWeeklyLoss()) return false;
   if(!CheckDrawdown()) return false;
   if(!CheckDailyTrades()) return false;

   return true;
}

//+------------------------------------------------------------------+
//| 记录交易结果                                                       |
//+------------------------------------------------------------------+
void CRiskManager::RecordTrade(double profit)
{
   m_dailyTrades++;
   m_dailyPL += profit;
   m_weeklyPL += profit;

   if(profit > 0)
      m_dailyWins++;
   else if(profit < 0)
      m_dailyLosses++;

   LOG_INFO(StringFormat("Trade recorded: P/L=%.2f, Daily=%.2f, Weekly=%.2f",
                         profit, m_dailyPL, m_weeklyPL));
}

//+------------------------------------------------------------------+
//| 重置日统计                                                         |
//+------------------------------------------------------------------+
void CRiskManager::ResetDailyStats()
{
   m_dailyTrades = 0;
   m_dailyWins = 0;
   m_dailyLosses = 0;
   m_dailyPL = 0;
   LOG_DEBUG("Daily stats reset");
}

//+------------------------------------------------------------------+
//| 重置周统计                                                         |
//+------------------------------------------------------------------+
void CRiskManager::ResetWeeklyStats()
{
   m_weeklyPL = 0;
   LOG_DEBUG("Weekly stats reset");
}

//+------------------------------------------------------------------+
//| 重置所有统计                                                       |
//+------------------------------------------------------------------+
void CRiskManager::ResetAll()
{
   ResetDailyStats();
   ResetWeeklyStats();
   m_peakEquity = AccountEquity();
   m_currentDrawdown = 0;
   m_startBalance = AccountBalance();
   m_weeklyStartBalance = m_startBalance;
   LOG_DEBUG("All stats reset");
}

//+------------------------------------------------------------------+
#endif // __RiskManager_MQH__
