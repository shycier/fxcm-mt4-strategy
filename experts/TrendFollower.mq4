//+------------------------------------------------------------------+
//|                                          TrendFollower.mq4      |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, FXCM Trader"
#property link      "https://www.fxcm.com"
#property version   "1.00"
#property strict

#include "../core/TradeEngine.mqh"
#include "../strategies/Trend/MAStrategy.mqh"
#include "../strategies/Trend/MACDStrategy.mqh"

//+------------------------------------------------------------------+
//| 输入参数                                                           |
//+------------------------------------------------------------------+
//--- 策略选择
input int    TF_Strategy = 0;             // 策略类型 (0=MA交叉, 1=MACD)

//--- 通用参数
input string TF_Symbol = "";              // 交易品种(留空=当前)
input int    TF_TimeFrame = PERIOD_H1;    // 时间框架
input int    TF_Magic = MAGIC_TREND;      // 魔术数字

//--- 风险参数
input double TF_RiskPercent = 1.5;        // 风险百分比
input double TF_MaxDailyLoss = 5.0;       // 日最大亏损%
input double TF_MaxDrawdown = 15.0;       // 最大回撤%
input int    TF_MaxDailyTrades = 5;       // 日最大交易次数
input int    TF_MaxPositions = 2;         // 最大持仓数

//--- 移动止损
input bool   TF_UseTrailing = true;       // 使用移动止损
input int    TF_TrailStart = 20;          // 移动止损启动点数
input int    TF_TrailStep = 10;           // 移动止损步长

//--- 其他设置
input bool   TF_EnableTrading = true;     // 启用交易
input int    TF_LogLevel = LOG_LEVEL_INFO;// 日志级别

//+------------------------------------------------------------------+
//| 全局变量                                                           |
//+------------------------------------------------------------------+
CTradeEngine*   g_tradeEngine = NULL;
CSignalGenerator* g_strategy = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- 设置日志级别
   g_logger.SetLogLevel(TF_LogLevel);
   g_logger.SetPrefix("TREND");

   //--- 确定交易品种
   string symbol = (TF_Symbol == "") ? Symbol() : TF_Symbol;

   //--- 创建策略
   switch(TF_Strategy)
   {
      case 0:
         g_strategy = new CMAStrategy(symbol, TF_TimeFrame, TF_Magic);
         break;
      case 1:
         g_strategy = new CMACDStrategy(symbol, TF_TimeFrame, TF_Magic);
         break;
      default:
         g_strategy = new CMAStrategy(symbol, TF_TimeFrame, TF_Magic);
   }

   if(g_strategy == NULL)
   {
      Print("Failed to create strategy");
      return INIT_FAILED;
   }

   //--- 创建交易引擎
   g_tradeEngine = new CTradeEngine(symbol, TF_TimeFrame, TF_Magic);

   if(g_tradeEngine == NULL)
   {
      Print("Failed to create trade engine");
      delete g_strategy;
      return INIT_FAILED;
   }

   //--- 配置风险参数
   RiskParams riskParams;
   riskParams.riskPercent = TF_RiskPercent;
   riskParams.maxDailyLoss = TF_MaxDailyLoss;
   riskParams.maxDrawdown = TF_MaxDrawdown;
   riskParams.maxDailyTrades = TF_MaxDailyTrades;
   riskParams.maxPositions = TF_MaxPositions;
   g_tradeEngine->SetRiskParams(riskParams);

   //--- 配置移动止损
   g_tradeEngine->SetTrailingStop(TF_UseTrailing, TF_TrailStart, TF_TrailStep);

   //--- 配置交易状态
   g_tradeEngine->SetEnabled(TF_EnableTrading);

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
   Print("Trend Follower EA Initialized");
   Print("Symbol: ", symbol);
   Print("TimeFrame: ", EnumToString((ENUM_TIMEFRAMES)TF_TimeFrame));
   Print("Strategy: ", g_strategy->GetStrategyName());
   Print("Magic: ", TF_Magic);
   Print("Risk: ", TF_RiskPercent, "%");
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

   Print("Trend Follower EA Deinitialized. Reason: ", reason);
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
      //--- 按键处理
      switch((int)lparam)
      {
         case 'C': // C键 - 平掉所有仓位
            if(g_tradeEngine != NULL)
            {
               g_tradeEngine->CloseAllPositions();
               Print("All positions closed by user");
            }
            break;

         case 'D': // D键 - 禁用/启用交易
            if(g_tradeEngine != NULL)
            {
               bool enabled = !g_tradeEngine->IsEnabled();
               g_tradeEngine->SetEnabled(enabled);
               Print("Trading ", enabled ? "ENABLED" : "DISABLED");
            }
            break;
      }
   }
}

//+------------------------------------------------------------------+