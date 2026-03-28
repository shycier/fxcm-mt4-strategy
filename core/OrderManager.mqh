//+------------------------------------------------------------------+
//|                                            OrderManager.mqh      |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __OrderManager_MQH__
#define __OrderManager_MQH__


#include "../include/Constants.mqh"
#include "../include/Types.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| 订单管理类                                                         |
//+------------------------------------------------------------------+
class COrderManager
{
private:
   string   m_symbol;          // 交易品种
   int      m_magic;           // 魔术数字
   int      m_slippage;        // 滑点
   int      m_maxRetries;      // 最大重试次数
   int      m_retryDelay;      // 重试延迟(毫秒)

   //--- 统计数据
   int      m_totalTrades;     // 总交易次数
   int      m_winningTrades;   // 盈利交易次数
   int      m_losingTrades;    // 亏损交易次数
   double   m_totalProfit;     // 总盈亏
   double   m_totalLoss;       // 总亏损

   //--- 私有方法
   int      ExecuteWithRetry(int cmd, double volume, double price,
                            double sl, double tp, const string comment);
   void     UpdateStats(double profit);
   int      GetLastErrorCode();

public:
   //--- 构造函数
   COrderManager();
   COrderManager(const string symbol, int magic, int slippage = MAX_SLIPPAGE);

   //--- 配置方法
   void     SetSymbol(const string symbol) { m_symbol = symbol; }
   void     SetMagic(int magic) { m_magic = magic; }
   void     SetSlippage(int slippage) { m_slippage = slippage; }
   void     SetMaxRetries(int retries) { m_maxRetries = retries; }

   //--- 订单操作
   int      OpenBuy(double lots, double sl, double tp, const string comment = "");
   int      OpenSell(double lots, double sl, double tp, const string comment = "");
   bool     CloseOrder(int ticket, double lots = 0);
   bool     CloseAllOrders(int orderType = -1); // -1 = all types
   bool     ModifyOrder(int ticket, double sl, double tp, double price = 0);

   //--- 订单查询
   int      GetOpenOrdersCount(int orderType = -1);
   int      GetOrdersByMagic(int magic);
   bool     GetOrderInfo(int ticket, OrderInfo &info);
   int      FindOrderByMagic(int magic);
   bool     HasOpenPosition();

   //--- 统计方法
   int      GetTotalTrades() const { return m_totalTrades; }
   int      GetWinningTrades() const { return m_winningTrades; }
   int      GetLosingTrades() const { return m_losingTrades; }
   double   GetTotalProfit() const { return m_totalProfit; }
   double   GetWinRate() const;
   double   GetAverageProfit() const;

   //--- 重置统计
   void     ResetStats();
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
COrderManager::COrderManager() :
   m_symbol(Symbol()),
   m_magic(0),
   m_slippage(MAX_SLIPPAGE),
   m_maxRetries(MAX_RETRIES),
   m_retryDelay(RETRY_DELAY_MS),
   m_totalTrades(0),
   m_winningTrades(0),
   m_losingTrades(0),
   m_totalProfit(0),
   m_totalLoss(0)
{
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
COrderManager::COrderManager(const string symbol, int magic, int slippage) :
   m_symbol(symbol),
   m_magic(magic),
   m_slippage(slippage),
   m_maxRetries(MAX_RETRIES),
   m_retryDelay(RETRY_DELAY_MS),
   m_totalTrades(0),
   m_winningTrades(0),
   m_losingTrades(0),
   m_totalProfit(0),
   m_totalLoss(0)
{
}

//+------------------------------------------------------------------+
//| 执行交易并重试                                                     |
//+------------------------------------------------------------------+
int COrderManager::ExecuteWithRetry(int cmd, double volume, double price,
                                    double sl, double tp, const string comment)
{
   int ticket = -1;
   int attempts = 0;
   color arrowColor = (cmd == OP_BUY || cmd == OP_BUYLIMIT || cmd == OP_BUYSTOP) ? clrGreen : clrRed;

   while(attempts < m_maxRetries)
   {
      //--- 刷新报价
      RefreshRates();

      //--- 根据订单类型调整价格
      double executePrice = price;
      if(cmd == OP_BUY) executePrice = Ask;
      else if(cmd == OP_SELL) executePrice = Bid;

      //--- 重置错误
      ResetLastError();

      //--- 发送订单
      ticket = OrderSend(m_symbol, cmd, volume, executePrice, m_slippage, sl, tp, comment, m_magic, 0, arrowColor);

      if(ticket > 0)
      {
         LOG_INFO(StringFormat("Order executed: Ticket=%d, Cmd=%d, Vol=%.2f, Price=%.5f", ticket, cmd, volume, executePrice));
         return ticket;
      }

      //--- 处理错误
      int errorCode = GetLastError();
      LOG_WARNING(StringFormat("Order failed (attempt %d/%d): Error %d - %s",
                              attempts + 1, m_maxRetries, errorCode, ErrorDescription(errorCode)));

      //--- 检查是否可重试
      if(errorCode == ERR_TRADE_CONTEXT_BUSY || errorCode == ERR_SERVER_BUSY)
      {
         Sleep(m_retryDelay);
         attempts++;
         continue;
      }

      //--- 不可重试的错误
      break;
   }

   return -1;
}

//+------------------------------------------------------------------+
//| 开多仓                                                             |
//+------------------------------------------------------------------+
int COrderManager::OpenBuy(double lots, double sl, double tp, const string comment)
{
   if(!IsConnected() || !IsTradeAllowed())
   {
      LOG_ERROR("Trading not allowed or not connected");
      return -1;
   }

   //--- 标准化参数
   lots = NormalizeLots(lots, m_symbol);
   sl = NormalizePrice(sl, m_symbol);
   tp = NormalizePrice(tp, m_symbol);

   int ticket = ExecuteWithRetry(OP_BUY, lots, Ask, sl, tp, comment);

   if(ticket > 0)
      g_logger.LogTrade("BUY", lots, m_symbol, Ask, sl, tp, comment);

   return ticket;
}

//+------------------------------------------------------------------+
//| 开空仓                                                             |
//+------------------------------------------------------------------+
int COrderManager::OpenSell(double lots, double sl, double tp, const string comment)
{
   if(!IsConnected() || !IsTradeAllowed())
   {
      LOG_ERROR("Trading not allowed or not connected");
      return -1;
   }

   //--- 标准化参数
   lots = NormalizeLots(lots, m_symbol);
   sl = NormalizePrice(sl, m_symbol);
   tp = NormalizePrice(tp, m_symbol);

   int ticket = ExecuteWithRetry(OP_SELL, lots, Bid, sl, tp, comment);

   if(ticket > 0)
      g_logger.LogTrade("SELL", lots, m_symbol, Bid, sl, tp, comment);

   return ticket;
}

//+------------------------------------------------------------------+
//| 平仓                                                               |
//+------------------------------------------------------------------+
bool COrderManager::CloseOrder(int ticket, double lots)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
   {
      LOG_ERROR(StringFormat("Cannot select order %d", ticket));
      return false;
   }

   //--- 如果未指定手数,平掉全部
   if(lots <= 0) lots = OrderLots();

   double closePrice;
   color closeColor;

   if(OrderType() == OP_BUY)
   {
      closePrice = Bid;
      closeColor = clrOrange;
   }
   else if(OrderType() == OP_SELL)
   {
      closePrice = Ask;
      closeColor = clrOrange;
   }
   else
   {
      //--- 删除挂单
      return OrderDelete(ticket);
   }

   //--- 平仓
   bool result = OrderClose(ticket, lots, closePrice, m_slippage, closeColor);

   if(result)
   {
      double profit = OrderProfit();
      UpdateStats(profit);
      LOG_INFO(StringFormat("Order closed: Ticket=%d, Profit=%.2f", ticket, profit));
   }
   else
   {
      int errorCode = GetLastError();
      LOG_ERROR(StringFormat("Failed to close order %d: Error %d", ticket, errorCode));
   }

   return result;
}

//+------------------------------------------------------------------+
//| 平掉所有订单                                                       |
//+------------------------------------------------------------------+
bool COrderManager::CloseAllOrders(int orderType)
{
   int closed = 0;
   int total = OrdersTotal();

   for(int i = total - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;

      if(OrderSymbol() != m_symbol) continue;
      if(OrderMagicNumber() != m_magic) continue;

      if(orderType >= 0 && OrderType() != orderType) continue;

      if(CloseOrder(OrderTicket()))
         closed++;
   }

   return (closed > 0);
}

//+------------------------------------------------------------------+
//| 修改订单                                                           |
//+------------------------------------------------------------------+
bool COrderManager::ModifyOrder(int ticket, double sl, double tp, double price)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
   {
      LOG_ERROR(StringFormat("Cannot select order %d", ticket));
      return false;
   }

   //--- 标准化价格
   sl = NormalizePrice(sl, m_symbol);
   tp = NormalizePrice(tp, m_symbol);

   //--- 修改订单
   bool result = OrderModify(ticket, price, sl, tp, 0, clrNONE);

   if(result)
   {
      LOG_INFO(StringFormat("Order modified: Ticket=%d, SL=%.5f, TP=%.5f", ticket, sl, tp));
   }
   else
   {
      int errorCode = GetLastError();
      LOG_ERROR(StringFormat("Failed to modify order %d: Error %d", ticket, errorCode));
   }

   return result;
}

//+------------------------------------------------------------------+
//| 获取持仓数量                                                       |
//+------------------------------------------------------------------+
int COrderManager::GetOpenOrdersCount(int orderType)
{
   int count = 0;
   int total = OrdersTotal();

   for(int i = 0; i < total; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;

      if(OrderSymbol() != m_symbol) continue;
      if(OrderMagicNumber() != m_magic) continue;

      if(orderType >= 0 && OrderType() != orderType) continue;

      //--- 只计算实际持仓
      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         count++;
   }

   return count;
}

//+------------------------------------------------------------------+
//| 根据魔术数字获取订单数量                                           |
//+------------------------------------------------------------------+
int COrderManager::GetOrdersByMagic(int magic)
{
   int count = 0;
   int total = OrdersTotal();

   for(int i = 0; i < total; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderMagicNumber() == magic) count++;
   }

   return count;
}

//+------------------------------------------------------------------+
//| 获取订单信息                                                       |
//+------------------------------------------------------------------+
bool COrderManager::GetOrderInfo(int ticket, OrderInfo &info)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;

   info.ticket     = OrderTicket();
   info.symbol     = OrderSymbol();
   info.type       = OrderType();
   info.lots       = OrderLots();
   info.openPrice  = OrderOpenPrice();
   info.closePrice = OrderClosePrice();
   info.stopLoss   = OrderStopLoss();
   info.takeProfit = OrderTakeProfit();
   info.profit     = OrderProfit();
   info.swap       = OrderSwap();
   info.commission = OrderCommission();
   info.openTime   = OrderOpenTime();
   info.closeTime  = OrderCloseTime();
   info.comment    = OrderComment();
   info.magic      = OrderMagicNumber();

   return true;
}

//+------------------------------------------------------------------+
//| 根据魔术数字查找订单                                               |
//+------------------------------------------------------------------+
int COrderManager::FindOrderByMagic(int magic)
{
   int total = OrdersTotal();

   for(int i = 0; i < total; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;

      if(OrderMagicNumber() == magic)
         return OrderTicket();
   }

   return -1;
}

//+------------------------------------------------------------------+
//| 检查是否有持仓                                                     |
//+------------------------------------------------------------------+
bool COrderManager::HasOpenPosition()
{
   return (GetOpenOrdersCount() > 0);
}

//+------------------------------------------------------------------+
//| 更新统计数据                                                       |
//+------------------------------------------------------------------+
void COrderManager::UpdateStats(double profit)
{
   m_totalTrades++;

   if(profit > 0)
   {
      m_winningTrades++;
      m_totalProfit += profit;
   }
   else
   {
      m_losingTrades++;
      m_totalLoss += MathAbs(profit);
   }
}

//+------------------------------------------------------------------+
//| 获取胜率                                                           |
//+------------------------------------------------------------------+
double COrderManager::GetWinRate() const
{
   if(m_totalTrades == 0) return 0;
   return (double)m_winningTrades / m_totalTrades * 100.0;
}

//+------------------------------------------------------------------+
//| 获取平均盈利                                                       |
//+------------------------------------------------------------------+
double COrderManager::GetAverageProfit() const
{
   if(m_totalTrades == 0) return 0;
   return (m_totalProfit + m_totalLoss) / m_totalTrades;
}

//+------------------------------------------------------------------+
//| 重置统计                                                           |
//+------------------------------------------------------------------+
void COrderManager::ResetStats()
{
   m_totalTrades = 0;
   m_winningTrades = 0;
   m_losingTrades = 0;
   m_totalProfit = 0;
   m_totalLoss = 0;
}

//+------------------------------------------------------------------+
#endif // __OrderManager_MQH__
