//+------------------------------------------------------------------+
//|                                             Scalper.mq4         |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, FXCM Trader"
#property link      "https://www.fxcm.com"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include "core/TradeEngine.mqh"
#include "strategies/Scalping/QuickScalp.mqh"

//+------------------------------------------------------------------+
//| 输入参数                                                           |
//+------------------------------------------------------------------+
//--- 通用参数
input string SC_Symbol = "";              // 交易品种(留空=当前)
input int    SC_TimeFrame = PERIOD_M5;    // 时间框架 (M5更适合剥头皮)
input int    SC_Magic = MAGIC_SCALPING;   // 魔术数字

//--- 风险参数
input double SC_RiskPercent = 1.0;        // 风险百分比 (保守)
input double SC_MaxDailyLoss = 3.0;       // 日最大亏损% (严格)
input double SC_MaxDrawdown = 10.0;       // 最大回撤% (严格)
input int    SC_MaxDailyTrades = 10;      // 日最大交易次数
input int    SC_MaxPositions = 3;         // 最大持仓数

//--- 移动止损
input bool   SC_UseTrailing = true;       // 使用移动止损
input int    SC_TrailStart = 8;           // 移动止损启动点数
input int    SC_TrailStep = 5;            // 移动止损步长

//--- 剥头皮专用设置
input bool   SC_FilterSpread = true;      // 过滤高点差
input int    SC_MaxSpread = 3;            // 最大允许点差
input int    SC_MinTradeInterval = 30;    // 最小交易间隔(秒)

//--- 其他设置
input bool   SC_EnableTrading = true;     // 启用交易
input int    SC_LogLevel = LOG_LEVEL_INFO;// 日志级别

//+------------------------------------------------------------------+
//| 全局变量                                                           |
//+------------------------------------------------------------------+
CTradeEngine*     g_tradeEngine = NULL;
CQuickScalp*      g_strategy = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- 设置日志级别
   g_logger.SetLogLevel(SC_LogLevel);
   g_logger.SetPrefix("SCALPER");

   //--- 确定交易品种
   string symbol = (SC_Symbol == "") ? Symbol() : SC_Symbol;

   //--- 创建策略
   g_strategy = new CQuickScalp(symbol, SC_TimeFrame, SC_Magic);

   if(g_strategy == NULL)
   {
      Print("Failed to create strategy");
      return INIT_FAILED;
   }

   //--- 设置剥头皮专用参数
   g_strategy->SetMinTradeInterval(SC_MinTradeInterval);

   //--- 创建交易引擎
   g_tradeEngine = new CTradeEngine(symbol, SC_TimeFrame, SC_Magic);

   if(g_tradeEngine == NULL)
   {
      Print("Failed to create trade engine");
      delete g_strategy;
      return INIT_FAILED;
   }

   //--- 配置风险参数
   RiskParams riskParams;
   riskParams.riskPercent = SC_RiskPercent;
   riskParams.maxDailyLoss = SC_MaxDailyLoss;
   riskParams.maxDrawdown = SC_MaxDrawdown;
   riskParams.maxDailyTrades = SC_MaxDailyTrades;
   riskParams.maxPositions = SC_MaxPositions;
   g_tradeEngine->SetRiskParams(riskParams);

   //--- 配置移动止损
   g_tradeEngine->SetTrailingStop(SC_UseTrailing, SC_TrailStart, SC_TrailStep);

   //--- 配置交易状态
   g_tradeEngine->SetEnabled(SC_EnableTrading);

   //--- 初始化交易引擎
   if(!g_tradeEngine->Init(g_strategy))
   {
      Print("Failed to initialize trade engine");
      delete g_tradeEngine;
      delete g_strategy;
      return INIT_FAILED;
   }

   //--- 显示信息
   Print("========================================");
   Print("Scalper EA Initialized");
   Print("Symbol: ", symbol);
   Print("TimeFrame: ", EnumToString((ENUM_TIMEFRAMES)SC_TimeFrame));
   Print("Strategy: Quick Scalp");
   Print("Magic: ", SC_Magic);
   Print("Risk: ", SC_RiskPercent, "%");
   Print("Max Spread: ", SC_MaxSpread, " pips");
   Print("Min Interval: ", SC_MinTradeInterval, " sec");
   Print("========================================");

   //--- 设置定时器
   EventSetTimer(1);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- 删除定时器
   EventKillTimer();

   //--- 清理
   if(g_tradeEngine != NULL)
   {
      g_tradeEngine->Deinit();
      delete g_tradeEngine;
      g_tradeEngine = NULL;
   }

   if(g_strategy != NULL)
   {
      delete g_strategy;
      g_strategy = NULL;
   }

   Print("Scalper EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_tradeEngine == NULL) return;

   //--- 检查点差
   if(SC_FilterSpread)
   {
      double spread = MarketInfo(Symbol(), MODE_SPREAD);
      int digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
      double spreadPips = (digits == 5 || digits == 3) ? spread / 10.0 : spread;

      if(spreadPips > SC_MaxSpread)
      {
         return; // 点差过大,跳过
      }
   }

   //--- 更新交易引擎
   g_tradeEngine->OnTick();
}

//+------------------------------------------------------------------+
//| Timer function                                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_tradeEngine == NULL) return;

   g_tradeEngine->OnTimer();
}

//+------------------------------------------------------------------+
//| Chart event function                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   //--- 处理图表事件
   if(id == CHARTEVENT_KEYDOWN)
   {
      switch((int)lparam)
      {
         case 'C':
            if(g_tradeEngine != NULL)
            {
               g_tradeEngine->CloseAllPositions();
               Print("All positions closed by user");
            }
            break;

         case 'D':
            if(g_tradeEngine != NULL)
            {
               bool enabled = !g_tradeEngine->IsEnabled();
               g_tradeEngine->SetEnabled(enabled);
               Print("Trading ", enabled ? "ENABLED" : "DISABLED");
            }
            break;

         case 'S': // S键 - 显示统计
            if(g_tradeEngine != NULL && g_tradeEngine->GetOrderManager() != NULL)
            {
               COrderManager* om = g_tradeEngine->GetOrderManager();
               Print("=== Scalper Statistics ===");
               Print("Total Trades: ", om->GetTotalTrades());
               Print("Win Rate: ", DoubleToString(om->GetWinRate(), 1), "%");
               Print("Total P/L: ", DoubleToString(om->GetTotalProfit(), 2));
               Print("Open Positions: ", g_tradeEngine->GetOpenPositions());
               Print("==========================");
            }
            break;
      }
   }
}

//+------------------------------------------------------------------+