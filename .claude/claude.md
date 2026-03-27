# FXCM MT4 量化交易系统

## 项目概述

本项目是一个模块化的MQL4量化交易框架，为FXCM MT4平台设计，支持多种EA策略并行运行。

## 项目结构

```
mt4/
├── experts/          # EA主程序入口 (.mq4)
├── strategies/       # 策略逻辑模块 (.mqh)
│   ├── Trend/       # 趋势跟踪策略
│   ├── MeanReversion/ # 均值回归策略
│   ├── Breakout/    # 突破策略
│   └── Scalping/    # 剥头皮策略
├── indicators/      # 自定义指标 (.mq4)
├── risk/            # 风险管理模块 (.mqh)
├── core/            # 核心框架 (.mqh)
├── utils/           # 工具函数 (.mqh)
├── include/         # 公共头文件 (.mqh)
├── presets/         # 参数预设 (.set)
└── tests/           # 测试脚本 (.mq4)
```

## 开发规范

### MQL4 编码风格

1. **命名约定**
   - 类名：PascalCase (例：`TradeEngine`)
   - 函数名：PascalCase (例：`CalculateLotSize`)
   - 变量名：camelCase (例：`lotSize`, `stopLoss`)
   - 常量：UPPER_SNAKE_CASE (例：`MAX_RISK_PERCENT`)
   - 输入参数：使用描述性名称加注释

2. **文件组织**
   - 每个 `.mqh` 文件包含一个主要类或一组相关函数
   - 使用 `#include` 引入依赖，避免 `#import` 混用
   - 头文件使用 `#ifndef` / `#define` / `#endif` 保护

3. **策略开发**
   - 所有策略继承自 `SignalGenerator` 基类
   - 实现 `GenerateSignal()` 方法返回交易信号
   - 在 `OnInit()` 中初始化指标句柄
   - 在 `OnDeinit()` 中释放资源

4. **风险管理**
   - 每笔交易风险限制在 1-2%
   - 使用 `PositionSizer` 计算仓位
   - 必须设置止损 (StopLoss)
   - 遵守最大回撤限制

### 代码模板

```mql4
//+------------------------------------------------------------------+
//|                                                StrategyName.mqh |
//|                                    Copyright 2024, Your Name     |
//|                                       https://www.yoursite.com   |
//+------------------------------------------------------------------+
#pragma once

#include "../../core/SignalGenerator.mqh"
#include "../../include/Constants.mqh"

//--- 策略参数
input int    Param1 = 14;       // 参数1描述
input double Param2 = 1.5;      // 参数2描述

//+------------------------------------------------------------------+
//| 策略类定义                                                        |
//+------------------------------------------------------------------+
class CStrategyName : public CSignalGenerator
{
private:
   int m_handle;                // 指标句柄

public:
   //--- 构造/析构
   CStrategyName();
  ~CStrategyName();

   //--- 重写基类方法
   bool Init() override;
   void Deinit() override;
   int  GenerateSignal(double& sl, double& tp) override;
};

//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
CStrategyName::CStrategyName() : CSignalGenerator(),
   m_handle(INVALID_HANDLE)
{
}

//+------------------------------------------------------------------+
//| 析构函数                                                          |
//+------------------------------------------------------------------+
CStrategyName::~CStrategyName()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| 初始化                                                            |
//+------------------------------------------------------------------+
bool CStrategyName::Init()
{
   // 初始化指标
   return (m_handle != INVALID_HANDLE);
}

//+------------------------------------------------------------------+
//| 反初始化                                                          |
//+------------------------------------------------------------------+
void CStrategyName::Deinit()
{
   if (m_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_handle);
      m_handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| 生成交易信号                                                      |
//+------------------------------------------------------------------+
int CStrategyName::GenerateSignal(double& sl, double& tp)
{
   // 返回 SIGNAL_BUY, SIGNAL_SELL, 或 SIGNAL_NONE
   return SIGNAL_NONE;
}
```

## 编译与部署

### MetaEditor 编译

1. 在MT4中打开 MetaEditor (F4)
2. 打开 `experts/` 目录下的 .mq4 文件
3. 按 F7 编译
4. 编译后的 .ex4 文件位于同目录

### 部署到MT4

1. 复制文件到MT4数据目录：
   - EA: `MQL4/Experts/`
   - 指标: `MQL4/Indicators/`
   - 头文件: `MQL4/Include/`
   - 预设: `MQL4/Presets/`

2. 刷新MT4导航器 (右键 → 刷新)

3. 拖拽EA到图表并配置参数

## 回测指南

1. 打开 Strategy Tester (Ctrl+R)
2. 选择EA和交易品种
3. 设置时间范围和模型
4. 运行回测并分析结果

## Git 工作流

```bash
# 查看状态
git status

# 添加修改
git add .

# 提交更改
git commit -m "feat: 添加新策略模块"

# 查看历史
git log --oneline
```

## 常见问题

**Q: 编译时出现 "cannot open include file"**
A: 确保 include 文件路径正确，使用相对路径从项目根目录开始

**Q: EA不执行交易**
A: 检查 "允许实时交易" 选项和 "允许DLL导入" 设置

**Q: 回测结果不理想**
A: 检查参数优化、时间框架适配性、以及交易成本设置