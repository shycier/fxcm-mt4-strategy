//+------------------------------------------------------------------+
//|                                                  Types.mqh        |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#pragma once

#include "Constants.mqh"

//+------------------------------------------------------------------+
//| 交易信号结构体                                                     |
//+------------------------------------------------------------------+
struct TradeSignal
{
   int      type;           // 信号类型 (SIGNAL_BUY, SIGNAL_SELL, SIGNAL_NONE)
   double   entryPrice;     // 入场价格
   double   stopLoss;       // 止损价格
   double   takeProfit;     // 止盈价格
   double   lotSize;        // 仓位大小
   string   comment;        // 信号说明
   datetime time;           // 信号生成时间

   //--- 构造函数
   TradeSignal() : type(SIGNAL_NONE), entryPrice(0), stopLoss(0),
                   takeProfit(0), lotSize(0), comment(""), time(0) {}
};

//+------------------------------------------------------------------+
//| 订单信息结构体                                                     |
//+------------------------------------------------------------------+
struct OrderInfo
{
   int      ticket;         // 订单编号
   string   symbol;         // 交易品种
   int      type;           // 订单类型
   double   lots;           // 仓位
   double   openPrice;      // 开仓价格
   double   closePrice;     // 平仓价格
   double   stopLoss;       // 止损
   double   takeProfit;     // 止盈
   double   profit;         // 盈亏
   double   swap;           // 过夜利息
   double   commission;     // 手续费
   datetime openTime;       // 开仓时间
   datetime closeTime;      // 平仓时间
   string   comment;        // 备注
   int      magic;          // 魔术数字

   //--- 构造函数
   OrderInfo() : ticket(0), symbol(""), type(-1), lots(0), openPrice(0),
                 closePrice(0), stopLoss(0), takeProfit(0), profit(0),
                 swap(0), commission(0), openTime(0), closeTime(0),
                 comment(""), magic(0) {}
};

//+------------------------------------------------------------------+
//| 风险参数结构体                                                     |
//+------------------------------------------------------------------+
struct RiskParams
{
   double   riskPercent;    // 风险百分比
   double   maxDailyLoss;   // 日最大亏损百分比
   double   maxWeeklyLoss;  // 周最大亏损百分比
   double   maxDrawdown;    // 最大回撤百分比
   int      maxDailyTrades; // 日最大交易次数
   int      maxPositions;   // 最大持仓数
   double   minLotSize;     // 最小仓位
   double   maxLotSize;     // 最大仓位

   //--- 构造函数 - 使用默认值
   RiskParams()
   {
      riskPercent   = DEFAULT_RISK_PERCENT;
      maxDailyLoss  = MAX_DAILY_LOSS;
      maxWeeklyLoss = MAX_WEEKLY_LOSS;
      maxDrawdown   = MAX_DRAWDOWN;
      maxDailyTrades = MAX_DAILY_TRADES;
      maxPositions  = MAX_OPEN_POSITIONS;
      minLotSize    = MarketInfo(Symbol(), MODE_MINLOT);
      maxLotSize    = MarketInfo(Symbol(), MODE_MAXLOT);
   }
};

//+------------------------------------------------------------------+
//| 策略参数结构体                                                     |
//+------------------------------------------------------------------+
struct StrategyParams
{
   int      timeFrame;      // 时间框架
   int      period1;        // 周期参数1
   int      period2;        // 周期参数2
   double   threshold1;     // 阈值参数1
   double   threshold2;     // 阈值参数2
   int      slPips;         // 止损点数
   int      tpPips;         // 止盈点数
   bool     useTrailing;    // 是否使用移动止损
   int      trailingPips;   // 移动止损点数

   //--- 构造函数
   StrategyParams() : timeFrame(PERIOD_H1), period1(14), period2(26),
                      threshold1(70), threshold2(30), slPips(50),
                      tpPips(100), useTrailing(false), trailingPips(20) {}
};

//+------------------------------------------------------------------+
//| 账户统计结构体                                                     |
//+------------------------------------------------------------------+
struct AccountStats
{
   double   balance;        // 余额
   double   equity;         // 净值
   double   margin;         // 已用保证金
   double   freeMargin;     // 可用保证金
   double   marginLevel;    // 保证金水平
   double   profit;         // 浮动盈亏
   int      openTrades;     // 持仓数量
   double   dailyPL;        // 日盈亏
   double   weeklyPL;       // 周盈亏
   double   maxDrawdown;    // 最大回撤

   //--- 构造函数
   AccountStats() : balance(0), equity(0), margin(0), freeMargin(0),
                    marginLevel(0), profit(0), openTrades(0),
                    dailyPL(0), weeklyPL(0), maxDrawdown(0) {}

   //--- 更新统计数据
   void Update()
   {
      balance    = AccountBalance();
      equity     = AccountEquity();
      margin     = AccountMargin();
      freeMargin = AccountFreeMargin();
      marginLevel = (margin > 0) ? (equity / margin * 100) : 0;
      profit     = equity - balance;
      openTrades = OrdersTotal();
   }
};

//+------------------------------------------------------------------+
//| 市场数据结构体                                                     |
//+------------------------------------------------------------------+
struct MarketData
{
   string   symbol;         // 品种
   double   bid;            // 买价
   double   ask;            // 卖价
   double   spread;         // 点差
   double   point;          // 最小变动单位
   int      digits;         // 小数位数
   double   pipValue;       // 每点价值
   double   lotSize;        // 标准手大小
   double   high[];         // 最高价数组
   double   low[];          // 最低价数组
   double   close[];        // 收盘价数组
   double   volume[];       // 成交量数组

   //--- 构造函数
   MarketData() : symbol(""), bid(0), ask(0), spread(0), point(0),
                  digits(0), pipValue(0), lotSize(100000) {}
};

//+------------------------------------------------------------------+
//| 日志条目结构体                                                     |
//+------------------------------------------------------------------+
struct LogEntry
{
   int      level;          // 日志级别
   string   message;        // 日志消息
   string   function;       // 函数名
   int      line;           // 行号
   datetime time;           // 时间戳

   //--- 构造函数
   LogEntry() : level(LOG_LEVEL_INFO), message(""), function(""),
                line(0), time(0) {}
};

//+------------------------------------------------------------------+
//| 交易结果枚举                                                       |
//+------------------------------------------------------------------+
enum TradeResult
{
   TRADE_SUCCESS = 0,       // 交易成功
   TRADE_FAILED = -1,       // 交易失败
   TRADE_REJECTED = -2,     // 被拒绝
   TRADE_TIMEOUT = -3,      // 超时
   TRADE_INVALID_PARAMS = -4, // 无效参数
   TRADE_NO_MONEY = -5,     // 资金不足
   TRADE_MARKET_CLOSED = -6, // 市场关闭
   TRADE_TOO_FREQUENT = -7  // 交易过于频繁
};

//+------------------------------------------------------------------+
//| 策略类型枚举                                                       |
//+------------------------------------------------------------------+
enum StrategyType
{
   STRATEGY_TREND = 0,      // 趋势跟踪
   STRATEGY_MEAN_REVERSION = 1, // 均值回归
   STRATEGY_BREAKOUT = 2,   // 突破策略
   STRATEGY_SCALPING = 3    // 剥头皮策略
};

//+------------------------------------------------------------------+
//| 交易时段枚举                                                       |
//+------------------------------------------------------------------+
enum TradingSession
{
   SESSION_NONE = 0,        // 无交易时段
   SESSION_ASIA = 1,        // 亚洲时段
   SESSION_EUROPE = 2,      // 欧洲时段
   SESSION_US = 3,          // 美国时段
   SESSION_OVERLAP_EU_US = 4 // 欧美重叠时段
};

//+------------------------------------------------------------------+