//+------------------------------------------------------------------+
//|                                      DrawdownProtector.mqh      |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __DrawdownProtector_MQH__
#define __DrawdownProtector_MQH__


#include "../include/Constants.mqh"
#include "../include/Types.mqh"
#include "../core/Logger.mqh"

//+------------------------------------------------------------------+
//| 保护模式枚举                                                       |
//+------------------------------------------------------------------+
enum ProtectionMode
{
   PROTECTION_WARNING = 0,    // 仅警告
   PROTECTION_REDUCE_SIZE = 1, // 减小仓位
   PROTECTION_PAUSE = 2,      // 暂停交易
   PROTECTION_CLOSE_ALL = 3   // 平掉所有仓位
};

//+------------------------------------------------------------------+
//| 回撤保护器类                                                       |
//+------------------------------------------------------------------+
class CDrawdownProtector
{
private:
   double          m_maxDrawdown;        // 最大回撤百分比
   double          m_warningLevel;       // 警告级别
   double          m_criticalLevel;      // 临界级别
   ProtectionMode  m_protectionMode;     // 保护模式

   //--- 跟踪数据
   double          m_peakEquity;         // 峰值净值
   double          m_currentDrawdown;    // 当前回撤
   datetime        m_peakTime;           // 峰值时间
   datetime        m_pauseUntil;         // 暂停截止时间
   int             m_pauseDuration;      // 暂停时长(分钟)

   //--- 连续亏损跟踪
   int             m_consecutiveLosses;  // 连续亏损次数
   int             m_maxConsecutiveLosses; // 最大连续亏损
   double          m_lotReductionFactor; // 仓位缩减因子

   //--- 私有方法
   void            UpdatePeak();
   double          CalculateDrawdown();
   void            TriggerProtection();
   void            SendAlert(const string& message);

public:
   //--- 构造函数
   CDrawdownProtector();
   CDrawdownProtector(double maxDrawdown, double warningLevel, double criticalLevel);

   //--- 配置方法
   void            SetMaxDrawdown(double percent);
   void            SetWarningLevel(double percent) { m_warningLevel = percent; }
   void            SetCriticalLevel(double percent) { m_criticalLevel = percent; }
   void            SetProtectionMode(ProtectionMode mode) { m_protectionMode = mode; }
   void            SetPauseDuration(int minutes) { m_pauseDuration = minutes; }
   void            SetMaxConsecutiveLosses(int count) { m_maxConsecutiveLosses = count; }
   void            SetLotReductionFactor(double factor) { m_lotReductionFactor = factor; }

   //--- 更新与检查
   void            Update();
   bool            CheckDrawdown();
   bool            IsPaused();
   bool            CanTrade();

   //--- 获取状态
   double          GetCurrentDrawdown() const { return m_currentDrawdown; }
   double          GetPeakEquity() const { return m_peakEquity; }
   int             GetConsecutiveLosses() const { return m_consecutiveLosses; }
   ProtectionMode  GetProtectionMode() const { return m_protectionMode; }

   //--- 交易事件处理
   void            OnTradeClose(double profit);
   void            ResetConsecutiveLosses() { m_consecutiveLosses = 0; }

   //--- 仓位调整
   double          GetAdjustedLotSize(double originalLotSize);

   //--- 恢复交易
   void            ResumeTrading();
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CDrawdownProtector::CDrawdownProtector() :
   m_maxDrawdown(MAX_DRAWDOWN),
   m_warningLevel(MAX_DRAWDOWN * 0.6),
   m_criticalLevel(MAX_DRAWDOWN * 0.8),
   m_protectionMode(PROTECTION_WARNING),
   m_peakEquity(0),
   m_currentDrawdown(0),
   m_peakTime(0),
   m_pauseUntil(0),
   m_pauseDuration(60),
   m_consecutiveLosses(0),
   m_maxConsecutiveLosses(3),
   m_lotReductionFactor(0.5)
{
   m_peakEquity = AccountEquity();
   m_peakTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CDrawdownProtector::CDrawdownProtector(double maxDrawdown, double warningLevel, double criticalLevel) :
   m_maxDrawdown(maxDrawdown),
   m_warningLevel(warningLevel),
   m_criticalLevel(criticalLevel),
   m_protectionMode(PROTECTION_WARNING),
   m_peakEquity(0),
   m_currentDrawdown(0),
   m_peakTime(0),
   m_pauseUntil(0),
   m_pauseDuration(60),
   m_consecutiveLosses(0),
   m_maxConsecutiveLosses(3),
   m_lotReductionFactor(0.5)
{
   m_peakEquity = AccountEquity();
   m_peakTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| 设置最大回撤                                                       |
//+------------------------------------------------------------------+
void CDrawdownProtector::SetMaxDrawdown(double percent)
{
   m_maxDrawdown = percent;
   m_warningLevel = percent * 0.6;
   m_criticalLevel = percent * 0.8;
}

//+------------------------------------------------------------------+
//| 更新峰值                                                           |
//+------------------------------------------------------------------+
void CDrawdownProtector::UpdatePeak()
{
   double equity = AccountEquity();

   if(equity > m_peakEquity)
   {
      m_peakEquity = equity;
      m_peakTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| 计算回撤                                                           |
//+------------------------------------------------------------------+
double CDrawdownProtector::CalculateDrawdown()
{
   if(m_peakEquity <= 0) return 0;

   double equity = AccountEquity();
   double drawdown = (m_peakEquity - equity) / m_peakEquity * 100.0;

   return (drawdown > 0) ? drawdown : 0;
}

//+------------------------------------------------------------------+
//| 触发保护措施                                                       |
//+------------------------------------------------------------------+
void CDrawdownProtector::TriggerProtection()
{
   string message;

   switch(m_protectionMode)
   {
      case PROTECTION_WARNING:
         message = StringFormat("DRAWDOWN WARNING: %.2f%% (Max: %.2f%%)",
                                m_currentDrawdown, m_maxDrawdown);
         SendAlert(message);
         break;

      case PROTECTION_REDUCE_SIZE:
         message = StringFormat("DRAWDOWN: Reducing lot size by %.0f%% (%.2f%% drawdown)",
                                (1 - m_lotReductionFactor) * 100, m_currentDrawdown);
         SendAlert(message);
         break;

      case PROTECTION_PAUSE:
         m_pauseUntil = TimeCurrent() + m_pauseDuration * 60;
         message = StringFormat("DRAWDOWN: Trading paused for %d minutes (%.2f%% drawdown)",
                                m_pauseDuration, m_currentDrawdown);
         SendAlert(message);
         break;

      case PROTECTION_CLOSE_ALL:
         message = StringFormat("DRAWDOWN CRITICAL: %.2f%% - Consider closing positions", m_currentDrawdown);
         SendAlert(message);
         break;
   }
}

//+------------------------------------------------------------------+
//| 发送警告                                                           |
//+------------------------------------------------------------------+
void CDrawdownProtector::SendAlert(const string& message)
{
   Alert(message);
   LOG_WARNING(message);
}

//+------------------------------------------------------------------+
//| 更新状态                                                           |
//+------------------------------------------------------------------+
void CDrawdownProtector::Update()
{
   UpdatePeak();
   m_currentDrawdown = CalculateDrawdown();

   //--- 检查是否需要触发保护
   if(m_currentDrawdown >= m_warningLevel)
   {
      TriggerProtection();
   }
}

//+------------------------------------------------------------------+
//| 检查回撤状态                                                       |
//+------------------------------------------------------------------+
bool CDrawdownProtector::CheckDrawdown()
{
   Update();

   if(m_currentDrawdown >= m_maxDrawdown)
   {
      LOG_ERROR(StringFormat("Maximum drawdown exceeded: %.2f%% >= %.2f%%",
                             m_currentDrawdown, m_maxDrawdown));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| 检查是否暂停                                                       |
//+------------------------------------------------------------------+
bool CDrawdownProtector::IsPaused()
{
   if(m_pauseUntil == 0) return false;

   if(TimeCurrent() >= m_pauseUntil)
   {
      m_pauseUntil = 0;
      LOG_INFO("Trading resumed after pause");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| 检查是否可以交易                                                   |
//+------------------------------------------------------------------+
bool CDrawdownProtector::CanTrade()
{
   if(!CheckDrawdown()) return false;
   if(IsPaused()) return false;

   return true;
}

//+------------------------------------------------------------------+
//| 处理交易关闭事件                                                   |
//+------------------------------------------------------------------+
void CDrawdownProtector::OnTradeClose(double profit)
{
   if(profit < 0)
   {
      m_consecutiveLosses++;
      LOG_INFO(StringFormat("Consecutive losses: %d", m_consecutiveLosses));

      if(m_consecutiveLosses >= m_maxConsecutiveLosses)
      {
         string message = StringFormat("Max consecutive losses reached: %d - Reducing position size",
                                       m_consecutiveLosses);
         SendAlert(message);
      }
   }
   else
   {
      m_consecutiveLosses = 0;
   }
}

//+------------------------------------------------------------------+
//| 获取调整后的仓位                                                   |
//+------------------------------------------------------------------+
double CDrawdownProtector::GetAdjustedLotSize(double originalLotSize)
{
   double adjustedLot = originalLotSize;

   //--- 根据回撤调整
   if(m_currentDrawdown >= m_warningLevel && m_protectionMode == PROTECTION_REDUCE_SIZE)
   {
      adjustedLot *= m_lotReductionFactor;
   }

   //--- 根据连续亏损调整
   if(m_consecutiveLosses >= m_maxConsecutiveLosses)
   {
      adjustedLot *= m_lotReductionFactor;
   }

   return adjustedLot;
}

//+------------------------------------------------------------------+
//| 恢复交易                                                           |
//+------------------------------------------------------------------+
void CDrawdownProtector::ResumeTrading()
{
   m_pauseUntil = 0;
   m_consecutiveLosses = 0;
   LOG_INFO("Trading protection reset, trading resumed");
}

//+------------------------------------------------------------------+
#endif // __DrawdownProtector_MQH__
