//+------------------------------------------------------------------+
//|                                        MeanReversion.mq4        |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, FXCM Trader"
#property link      "https://www.fxcm.com"
#property version   "1.00"
#property strict

#include "../core/TradeEngine.mqh"
#include "../strategies/MeanReversion/RSIStrategy.mqh"
#include "../strategies/MeanReversion/BollingerStrategy.mqh"

//+------------------------------------------------------------------+
//| 输入参数                                                           |
//+------------------------------------------------------------------+
//--- 策略选择
input int    MR_Strategy = 0;             // 策略类型 (0=RSI, 1=布林带)

//--- 通用参数
input string MR_Symbol = "";              // 交易品种(留空=当前)
input int    MR_TimeFrame = PERIOD_H4;    // 时间框架 (H4更适合均值回归)
input int    MR_Magic = MAGIC_MEAN_REVERSION; // 魔术数字

//--- 风险参数
input double MR_RiskPercent = 1.0;        // 风险百分比 (保守)
input double MR_MaxDailyLoss = 4.0;       // 日最大亏损%
input double MR_MaxDrawdown = 12.0;       // 最大回撤%
input int    MR_MaxDailyTrades = 4;       // 日最大交易次数
input int    MR_MaxPositions = 2;         // 最大持仓数

//--- 移动止损
input bool   MR_UseTrailing = false;      // 使用移动止损
input int    MR_TrailStart = 15;          // 移动止损启动点数
input int    MR_TrailStep = 8;            // 移动止损步长

//--- 其他设置
input bool   MR_EnableTrading = true;     // 启用交易
input int    MR_LogLevel = LOG_LEVEL_INFO;// 日志级别

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
   g_logger.SetLogLevel(MR_LogLevel);
   g_logger.SetPrefix("MEAN_REV");

   //--- 确定交易品种
   string symbol = (MR_Symbol == "") ? Symbol() : MR_Symbol;

   //--- 创建策略
   switch(MR_Strategy)
   {
      case 0:
         g_strategy = new CRSIStrategy(symbol, MR_TimeFrame, MR_Magic);
         break;
      case 1:
         g_strategy = new CBollingerStrategy(symbol, MR_TimeFrame, MR_Magic);
         break;
      default:
         g_strategy = new CRSIStrategy(symbol, MR_TimeFrame, MR_Magic);
   }

   if(g_strategy == NULL)
   {
      Print("Failed to create strategy");
      return INIT_FAILED;
   }

   //--- 创建交易引擎
   g_tradeEngine = new CTradeEngine(symbol, MR_TimeFrame, MR_Magic);

   if(g_tradeEngine == NULL)
   {
      Print("Failed to create trade engine");
      delete g_strategy;
      return INIT_FAILED;
   }

   //--- 配置风险参数
   RiskParams riskParams;
   riskParams.riskPercent = MR_RiskPercent;
   riskParams.maxDailyLoss = MR_MaxDailyLoss;
   riskParams.maxDrawdown = MR_MaxDrawdown;
   riskParams.maxDailyTrades = MR_MaxDailyTrades;
   riskParams.maxPositions = MR_MaxPositions;
   g_tradeEngine->SetRiskParams(riskParams);

   //--- 配置移动止损
   g_tradeEngine->SetTrailingStop(MR_UseTrailing, MR_TrailStart, MR_TrailStep);

   //--- 配置交易状态
   (*g_tradeEngine).SetEnabled(MR_EnableTrading);

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
   Print("Mean Reversion EA Initialized");
   Print("Symbol: ", symbol);
   Print("TimeFrame: ", EnumToString((ENUM_TIMEFRAMES)MR_TimeFrame));
   Print("Strategy: ", g_strategy->GetStrategyName());
   Print("Magic: ", MR_Magic);
   Print("Risk: ", MR_RiskPercent, "%");
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
      g_tradeEngine->Deinit();
      delete g_tradeEngine;
      g_tradeEngine = NULL;
   }

   if(g_strategy != NULL)
   {
      delete g_strategy;
      g_strategy = NULL;
   }

   Print("Mean Reversion EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_tradeEngine == NULL) return;

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
               (*g_tradeEngine).CloseAllPositions();
               Print("All positions closed by user");
            }
            break;

         case 'D':
            if(g_tradeEngine != NULL)
            {
               bool enabled = !(*g_tradeEngine).IsEnabled();
               (*g_tradeEngine).SetEnabled(enabled);
               Print("Trading ", enabled ? "ENABLED" : "DISABLED");
            }
            break;
      }
   }
}

//+------------------------------------------------------------------+