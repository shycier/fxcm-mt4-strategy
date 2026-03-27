//+------------------------------------------------------------------+
//|                                            TradeEngine.mqh       |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#pragma once

#include "../include/Constants.mqh"
#include "../include/Types.mqh"
#include "Logger.mqh"
#include "OrderManager.mqh"
#include "SignalGenerator.mqh"
#include "../risk/PositionSizer.mqh"
#include "../risk/RiskManager.mqh"

//+------------------------------------------------------------------+
//| 交易引擎类                                                         |
//+------------------------------------------------------------------+
class CTradeEngine
{
private:
   CSignalGenerator* m_strategy;       // 策略指针
   COrderManager*    m_orderManager;   // 订单管理器
   CPositionSizer*   m_positionSizer;  // 仓位计算器
   CRiskManager*     m_riskManager;    // 风险管理器

   string            m_symbol;         // 交易品种
   int               m_timeFrame;      // 时间框架
   int               m_magic;          // 魔术数字
   RiskParams        m_riskParams;     // 风险参数

   bool              m_enabled;        // 是否启用交易
   bool              m_trailingEnabled;// 是否启用移动止损
   int               m_trailingStart;  // 移动止损开始点数
   int               m_trailingStep;   // 移动止损步长

   datetime          m_lastTradeTime;  // 上次交易时间
   int               m_minTradeInterval; // 最小交易间隔(秒)

   //--- 私有方法
   bool              ValidateConditions();
   bool              CheckRiskLimits();
   void              ProcessSignal(int signal, double sl, double tp);
   void              UpdateTrailingStop();
   bool              CanTrade();

public:
   //--- 构造函数/析构函数
   CTradeEngine();
   CTradeEngine(const string& symbol, int timeFrame, int magic);
   ~CTradeEngine();

   //--- 初始化
   bool              Init(CSignalGenerator* strategy);
   void              Deinit();

   //--- 配置方法
   void              SetSymbol(const string& symbol);
   void              SetTimeFrame(int tf) { m_timeFrame = tf; }
   void              SetMagic(int magic) { m_magic = magic; }
   void              SetRiskParams(const RiskParams& params) { m_riskParams = params; }
   void              SetEnabled(bool enabled) { m_enabled = enabled; }
   void              SetTrailingStop(bool enabled, int startPips, int stepPips);

   //--- 获取方法
   string            GetSymbol() const { return m_symbol; }
   int               GetMagic() const { return m_magic; }
   bool              IsEnabled() const { return m_enabled; }
   COrderManager*    GetOrderManager() { return m_orderManager; }
   CRiskManager*     GetRiskManager() { return m_riskManager; }

   //--- 核心方法
   void              OnTick();
   void              OnTimer();
   void              CloseAllPositions();

   //--- 状态查询
   int               GetOpenPositions();
   double            GetCurrentDrawdown();
   bool              IsTradingAllowed();
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CTradeEngine::CTradeEngine() :
   m_strategy(NULL),
   m_orderManager(NULL),
   m_positionSizer(NULL),
   m_riskManager(NULL),
   m_symbol(Symbol()),
   m_timeFrame(PERIOD_H1),
   m_magic(0),
   m_enabled(true),
   m_trailingEnabled(false),
   m_trailingStart(20),
   m_trailingStep(10),
   m_lastTradeTime(0),
   m_minTradeInterval(60)
{
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CTradeEngine::CTradeEngine(const string& symbol, int timeFrame, int magic) :
   m_strategy(NULL),
   m_orderManager(NULL),
   m_positionSizer(NULL),
   m_riskManager(NULL),
   m_symbol(symbol),
   m_timeFrame(timeFrame),
   m_magic(magic),
   m_enabled(true),
   m_trailingEnabled(false),
   m_trailingStart(20),
   m_trailingStep(10),
   m_lastTradeTime(0),
   m_minTradeInterval(60)
{
}

//+------------------------------------------------------------------+
//| 析构函数                                                           |
//+------------------------------------------------------------------+
CTradeEngine::~CTradeEngine()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| 设置交易品种                                                       |
//+------------------------------------------------------------------+
void CTradeEngine::SetSymbol(const string& symbol)
{
   m_symbol = symbol;
   if(m_orderManager) m_orderManager->SetSymbol(symbol);
}

//+------------------------------------------------------------------+
//| 设置移动止损                                                       |
//+------------------------------------------------------------------+
void CTradeEngine::SetTrailingStop(bool enabled, int startPips, int stepPips)
{
   m_trailingEnabled = enabled;
   m_trailingStart = startPips;
   m_trailingStep = stepPips;
}

//+------------------------------------------------------------------+
//| 初始化交易引擎                                                     |
//+------------------------------------------------------------------+
bool CTradeEngine::Init(CSignalGenerator* strategy)
{
   if(strategy == NULL)
   {
      LOG_ERROR("Strategy is NULL");
      return false;
   }

   m_strategy = strategy;

   //--- 创建订单管理器
   m_orderManager = new COrderManager(m_symbol, m_magic);
   if(m_orderManager == NULL)
   {
      LOG_ERROR("Failed to create order manager");
      return false;
   }

   //--- 创建仓位计算器
   m_positionSizer = new CPositionSizer(m_riskParams);
   if(m_positionSizer == NULL)
   {
      LOG_ERROR("Failed to create position sizer");
      return false;
   }

   //--- 创建风险管理器
   m_riskManager = new CRiskManager(m_riskParams);
   if(m_riskManager == NULL)
   {
      LOG_ERROR("Failed to create risk manager");
      return false;
   }

   //--- 初始化策略
   if(!m_strategy->Init())
   {
      LOG_ERROR("Failed to initialize strategy");
      return false;
   }

   LOG_INFO(StringFormat("Trade engine initialized: %s, Magic=%d", m_symbol, m_magic));
   return true;
}

//+------------------------------------------------------------------+
//| 反初始化                                                           |
//+------------------------------------------------------------------+
void CTradeEngine::Deinit()
{
   if(m_strategy)
   {
      m_strategy->Deinit();
      // 注意: 不删除策略指针,因为它可能由外部管理
      m_strategy = NULL;
   }

   if(m_orderManager)
   {
      delete m_orderManager;
      m_orderManager = NULL;
   }

   if(m_positionSizer)
   {
      delete m_positionSizer;
      m_positionSizer = NULL;
   }

   if(m_riskManager)
   {
      delete m_riskManager;
      m_riskManager = NULL;
   }

   LOG_INFO("Trade engine deinitialized");
}

//+------------------------------------------------------------------+
//| 验证交易条件                                                       |
//+------------------------------------------------------------------+
bool CTradeEngine::ValidateConditions()
{
   //--- 检查是否启用
   if(!m_enabled)
   {
      LOG_DEBUG("Trading is disabled");
      return false;
   }

   //--- 检查连接
   if(!IsConnected())
   {
      LOG_WARNING("Not connected to server");
      return false;
   }

   //--- 检查交易权限
   if(!IsTradeAllowed())
   {
      LOG_WARNING("Trading not allowed");
      return false;
   }

   //--- 检查市场是否开放
   if(!IsMarketOpen())
   {
      LOG_DEBUG("Market is closed");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| 检查风险限制                                                       |
//+------------------------------------------------------------------+
bool CTradeEngine::CheckRiskLimits()
{
   if(m_riskManager == NULL) return true;

   //--- 检查日亏损限制
   if(!m_riskManager->CheckDailyLoss())
   {
      LOG_WARNING("Daily loss limit reached");
      return false;
   }

   //--- 检查周亏损限制
   if(!m_riskManager->CheckWeeklyLoss())
   {
      LOG_WARNING("Weekly loss limit reached");
      return false;
   }

   //--- 检查最大回撤
   if(!m_riskManager->CheckDrawdown())
   {
      LOG_WARNING("Max drawdown reached");
      return false;
   }

   //--- 检查日交易次数
   if(!m_riskManager->CheckDailyTrades())
   {
      LOG_WARNING("Daily trade limit reached");
      return false;
   }

   //--- 检查最大持仓数
   if(!m_riskManager->CheckMaxPositions(m_orderManager->GetOpenOrdersCount()))
   {
      LOG_WARNING("Max positions reached");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| 检查是否可以交易                                                   |
//+------------------------------------------------------------------+
bool CTradeEngine::CanTrade()
{
   //--- 检查最小交易间隔
   if(m_minTradeInterval > 0)
   {
      int elapsed = (int)(TimeCurrent() - m_lastTradeTime);
      if(elapsed < m_minTradeInterval)
      {
         LOG_DEBUG(StringFormat("Trade cooldown: %d seconds remaining", m_minTradeInterval - elapsed));
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| 处理交易信号                                                       |
//+------------------------------------------------------------------+
void CTradeEngine::ProcessSignal(int signal, double sl, double tp)
{
   if(signal == SIGNAL_NONE) return;

   //--- 计算仓位大小
   double riskPercent = m_riskParams.riskPercent;
   double slPips = MathAbs(Bid - sl) / Point;
   if(signal == SIGNAL_SELL) slPips = MathAbs(Ask - sl) / Point;

   double lots = m_positionSizer->CalculateLotSize(riskPercent, slPips, m_symbol);

   if(lots <= 0)
   {
      LOG_ERROR("Invalid lot size calculated");
      return;
   }

   //--- 执行交易
   int ticket = -1;
   if(signal == SIGNAL_BUY)
   {
      ticket = m_orderManager->OpenBuy(lots, sl, tp, "Auto");
   }
   else if(signal == SIGNAL_SELL)
   {
      ticket = m_orderManager->OpenSell(lots, sl, tp, "Auto");
   }

   if(ticket > 0)
   {
      m_lastTradeTime = TimeCurrent();
      m_riskManager->IncrementDailyTrades();
   }
}

//+------------------------------------------------------------------+
//| 更新移动止损                                                       |
//+------------------------------------------------------------------+
void CTradeEngine::UpdateTrailingStop()
{
   if(!m_trailingEnabled) return;
   if(m_orderManager == NULL) return;

   int total = OrdersTotal();
   double point = MarketInfo(m_symbol, MODE_POINT);
   int digits = (int)MarketInfo(m_symbol, MODE_DIGITS);

   for(int i = total - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;

      if(OrderSymbol() != m_symbol) continue;
      if(OrderMagicNumber() != m_magic) continue;

      double openPrice = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      double newSL = 0;

      if(OrderType() == OP_BUY)
      {
         double profitPips = (Bid - openPrice) / point;

         if(profitPips >= m_trailingStart)
         {
            newSL = Bid - m_trailingStep * point;

            if(currentSL == 0 || newSL > currentSL)
            {
               m_orderManager->ModifyOrder(OrderTicket(), newSL, OrderTakeProfit());
            }
         }
      }
      else if(OrderType() == OP_SELL)
      {
         double profitPips = (openPrice - Ask) / point;

         if(profitPips >= m_trailingStart)
         {
            newSL = Ask + m_trailingStep * point;

            if(currentSL == 0 || newSL < currentSL)
            {
               m_orderManager->ModifyOrder(OrderTicket(), newSL, OrderTakeProfit());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| OnTick事件处理                                                     |
//+------------------------------------------------------------------+
void CTradeEngine::OnTick()
{
   //--- 验证基本条件
   if(!ValidateConditions()) return;

   //--- 更新移动止损
   UpdateTrailingStop();

   //--- 检查风险限制
   if(!CheckRiskLimits()) return;

   //--- 检查交易间隔
   if(!CanTrade()) return;

   //--- 检查是否已有持仓
   if(m_orderManager->HasOpenPosition())
   {
      LOG_DEBUG("Already has open position");
      return;
   }

   //--- 生成信号
   double sl = 0, tp = 0;
   int signal = m_strategy->GenerateSignal(sl, tp);

   //--- 处理信号
   ProcessSignal(signal, sl, tp);
}

//+------------------------------------------------------------------+
//| OnTimer事件处理                                                    |
//+------------------------------------------------------------------+
void CTradeEngine::OnTimer()
{
   //--- 定期检查和更新
   UpdateTrailingStop();
}

//+------------------------------------------------------------------+
//| 平掉所有仓位                                                       |
//+------------------------------------------------------------------+
void CTradeEngine::CloseAllPositions()
{
   if(m_orderManager)
   {
      m_orderManager->CloseAllOrders();
      LOG_INFO("All positions closed");
   }
}

//+------------------------------------------------------------------+
//| 获取持仓数量                                                       |
//+------------------------------------------------------------------+
int CTradeEngine::GetOpenPositions()
{
   if(m_orderManager)
      return m_orderManager->GetOpenOrdersCount();
   return 0;
}

//+------------------------------------------------------------------+
//| 获取当前回撤                                                       |
//+------------------------------------------------------------------+
double CTradeEngine::GetCurrentDrawdown()
{
   double balance = AccountBalance();
   double equity = AccountEquity();

   if(balance <= 0) return 0;

   double drawdown = (balance - equity) / balance * 100.0;
   return (drawdown > 0) ? drawdown : 0;
}

//+------------------------------------------------------------------+
//| 检查是否允许交易                                                   |
//+------------------------------------------------------------------+
bool CTradeEngine::IsTradingAllowed()
{
   return ValidateConditions() && CheckRiskLimits();
}

//+------------------------------------------------------------------+