//+------------------------------------------------------------------+
//|                                        BreakoutTrader.mq4       |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, FXCM Trader"
#property link      "https://www.fxcm.com"
#property version   "1.00"
#property strict

#include "../core/TradeEngine.mqh"
#include "../strategies/Breakout/ChannelBreakout.mqh"
#include "../strategies/Breakout/SupportResistance.mqh"

//+------------------------------------------------------------------+
//| 输入参数                                                           |
//+------------------------------------------------------------------+
//--- 策略选择
input int    BO_Strategy = 0;             // 策略类型 (0=通道突破, 1=支撑阻力)

//--- 通用参数
input string BO_Symbol = "";              // 交易品种(留空=当前)
input int    BO_TimeFrame = PERIOD_H4;    // 时间框架
input int    BO_Magic = MAGIC_BREAKOUT;   // 魔术数字

//--- 风险参数
input double BO_RiskPercent = 1.5;        // 风险百分比
input double BO_MaxDailyLoss = 5.0;       // 日最大亏损%
input double BO_MaxDrawdown = 15.0;       // 最大回撤%
input int    BO_MaxDailyTrades = 3;       // 日最大交易次数 (突破策略减少频率)
input int    BO_MaxPositions = 2;         // 最大持仓数

//--- 移动止损
input bool   BO_UseTrailing = true;       // 使用移动止损
input int    BO_TrailStart = 30;          // 移动止损启动点数
input int    BO_TrailStep = 15;           // 移动止损步长

//--- 其他设置
input bool   BO_EnableTrading = true;     // 启用交易
input int    BO_LogLevel = LOG_LEVEL_INFO;// 日志级别

//+------------------------------------------------------------------+
//| 全局变量                                                           |
//+------------------------------------------------------------------+
CTradeEngine*     g_tradeEngine = NULL;
CSignalGenerator* g_strategy = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- 设置日志级别
   g_logger.SetLogLevel(BO_LogLevel);
   g_logger.SetPrefix("BREAKOUT");

   //--- 确定交易品种
   string symbol = (BO_Symbol == "") ? Symbol() : BO_Symbol;

   //--- 创建策略
   switch(BO_Strategy)
   {
      case 0:
         g_strategy = new CChannelBreakout(symbol, BO_TimeFrame, BO_Magic);
         break;
      case 1:
         g_strategy = new CSupportResistance(symbol, BO_TimeFrame, BO_Magic);
         break;
      default:
         g_strategy = new CChannelBreakout(symbol, BO_TimeFrame, BO_Magic);
   }

   if(g_strategy == NULL)
   {
      Print("Failed to create strategy");
      return INIT_FAILED;
   }

   //--- 创建交易引擎
   g_tradeEngine = new CTradeEngine(symbol, BO_TimeFrame, BO_Magic);

   if(g_tradeEngine == NULL)
   {
      Print("Failed to create trade engine");
      delete g_strategy;
      return INIT_FAILED;
   }

   //--- 配置风险参数
   RiskParams riskParams;
   riskParams.riskPercent = BO_RiskPercent;
   riskParams.maxDailyLoss = BO_MaxDailyLoss;
   riskParams.maxDrawdown = BO_MaxDrawdown;
   riskParams.maxDailyTrades = BO_MaxDailyTrades;
   riskParams.maxPositions = BO_MaxPositions;
   g_tradeEngine.SetRiskParams(riskParams);

   //--- 配置移动止损
   g_tradeEngine.SetTrailingStop(BO_UseTrailing, BO_TrailStart, BO_TrailStep);

   //--- 配置交易状态
   g_tradeEngine.SetEnabled(BO_EnableTrading);

   //--- 初始化交易引擎
   if(!g_tradeEngine.Init(g_strategy))
   {
      Print("Failed to initialize trade engine");
      delete g_tradeEngine;
      delete g_strategy;
      return INIT_FAILED;
   }

   //--- 显示信息
   Print("========================================");
   Print("Breakout Trader EA Initialized");
   Print("Symbol: ", symbol);
   Print("TimeFrame: ", EnumToString((ENUM_TIMEFRAMES)BO_TimeFrame));
   Print("Strategy: ", g_strategy.GetStrategyName());
   Print("Magic: ", BO_Magic);
   Print("Risk: ", BO_RiskPercent, "%");
   Print("========================================");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- 清理
   if(g_tradeEngine != NULL)
   {
      g_tradeEngine.Deinit();
      delete g_tradeEngine;
      g_tradeEngine = NULL;
   }

   if(g_strategy != NULL)
   {
      delete g_strategy;
      g_strategy = NULL;
   }

   Print("Breakout Trader EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_tradeEngine == NULL) return;

   //--- 更新交易引擎
   g_tradeEngine.OnTick();
}

//+------------------------------------------------------------------+
//| Timer function                                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_tradeEngine == NULL) return;

   g_tradeEngine.OnTimer();
}

//+------------------------------------------------------------------+
//| Chart event function                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string sparam)
{
   //--- 处理图表事件
   if(id == CHARTEVENT_KEYDOWN)
   {
      switch((int)lparam)
      {
         case 'C':
            if(g_tradeEngine != NULL)
            {
               g_tradeEngine.CloseAllPositions();
               Print("All positions closed by user");
            }
            break;

         case 'D':
            if(g_tradeEngine != NULL)
            {
               bool enabled = !g_tradeEngine.IsEnabled();
               g_tradeEngine.SetEnabled(enabled);
               Print("Trading ", enabled ? "ENABLED" : "DISABLED");
            }
            break;
      }
   }
}

//+------------------------------------------------------------------+