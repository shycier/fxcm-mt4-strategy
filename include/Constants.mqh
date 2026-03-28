//+------------------------------------------------------------------+
//|                                                Constants.mqh     |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __Constants_MQH__
#define __Constants_MQH__


//--- 交易信号类型
#define SIGNAL_NONE    0    // 无信号
#define SIGNAL_BUY     1    // 买入信号
#define SIGNAL_SELL    2    // 卖出信号
#define SIGNAL_CLOSE   3    // 平仓信号

//--- 订单状态
#define ORDER_PENDING  0    // 待处理
#define ORDER_FILLED   1    // 已成交
#define ORDER_CANCELLED 2   // 已取消
#define ORDER_ERROR    3    // 错误

//--- 时间框架
#define TF_M1   PERIOD_M1   // 1分钟
#define TF_M5   PERIOD_M5   // 5分钟
#define TF_M15  PERIOD_M15  // 15分钟
#define TF_M30  PERIOD_M30  // 30分钟
#define TF_H1   PERIOD_H1   // 1小时
#define TF_H4   PERIOD_H4   // 4小时
#define TF_D1   PERIOD_D1   // 日线
#define TF_W1   PERIOD_W1   // 周线
#define TF_MN   PERIOD_MN1  // 月线

//--- 风险管理常量
#define MAX_RISK_PERCENT      2.0    // 单笔最大风险百分比
#define MIN_RISK_PERCENT      0.1    // 单笔最小风险百分比
#define DEFAULT_RISK_PERCENT  1.5    // 默认风险百分比

#define MAX_DAILY_LOSS        5.0    // 日最大亏损百分比
#define MAX_WEEKLY_LOSS       10.0   // 周最大亏损百分比
#define MAX_DRAWDOWN          15.0   // 最大回撤百分比

#define MAX_DAILY_TRADES      5      // 日最大交易次数
#define MAX_OPEN_POSITIONS    3      // 最大持仓数量

//--- 止损止盈常量
#define MIN_STOP_LOSS_PIPS    10     // 最小止损点数
#define MAX_STOP_LOSS_PIPS    500    // 最大止损点数
#define DEFAULT_SL_MULTIPLIER 2.0    // 默认ATR止损倍数

#define MIN_TAKE_PROFIT_PIPS  20     // 最小止盈点数
#define DEFAULT_TP_SL_RATIO   2.0    // 默认盈亏比

//--- 交易时段 (GMT时间)
#define SESSION_ASIA_START    0      // 亚洲时段开始
#define SESSION_ASIA_END      9      // 亚洲时段结束
#define SESSION_EUROPE_START  8      // 欧洲时段开始
#define SESSION_EUROPE_END    17     // 欧洲时段结束
#define SESSION_US_START      13     // 美国时段开始
#define SESSION_US_END        22     // 美国时段结束

//--- 滑点和重试
#define MAX_SLIPPAGE          3      // 最大滑点(点)
#define MAX_RETRIES           3      // 最大重试次数
#define RETRY_DELAY_MS        500    // 重试延迟(毫秒)

//--- 日志级别
#define LOG_LEVEL_NONE        0      // 无日志
#define LOG_LEVEL_ERROR       1      // 仅错误
#define LOG_LEVEL_WARNING     2      // 警告和错误
#define LOG_LEVEL_INFO        3      // 信息、警告和错误
#define LOG_LEVEL_DEBUG       4      // 所有日志

//--- 魔术数字范围
#define MAGIC_BASE            100000 // 魔术数字基数
#define MAGIC_TREND           100001 // 趋势策略
#define MAGIC_MEAN_REVERSION  100002 // 均值回归策略
#define MAGIC_BREAKOUT        100003 // 突破策略
#define MAGIC_SCALPING        100004 // 剥头皮策略

//--- 无效值
#define INVALID_HANDLE        -1     // 无效句柄
#define INVALID_PRICE         0.0    // 无效价格
#define EMPTY_VALUE           0      // 空值

//--- 点值转换
#define POINTS_TO_PIPS(point) ((point) * (Digits == 3 || Digits == 5 ? 10 : 1))
#define PIPS_TO_POINTS(pips)  ((pips) / (Digits == 3 || Digits == 5 ? 10 : 1))

//--- 价格比较精度
#define PRICE_EPSILON         0.00001 // 价格比较精度

//+------------------------------------------------------------------+
#endif // __Constants_MQH__
