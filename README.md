# FXCM MT4 量化交易系统

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-MetaTrader%204-green.svg)](https://www.metaquotes.net/en/metatrader4)

一套模块化的MQL4量化交易框架，为FXCM MT4平台设计，支持多种EA策略并行运行，采用保守型风险管理。

## 特性

- **模块化架构** - 策略、风险、执行分离，易于扩展
- **多策略支持** - 趋势跟踪、均值回归、突破、剥头皮
- **风险管理** - 保守型风控，每笔风险1-2%
- **代码复用** - 通过.mqh头文件实现模块共享
- **预设配置** - 针对不同品种优化参数

## 支持的交易品种

| 类型 | 品种 |
|------|------|
| 外汇 | EURUSD, GBPUSD, USDJPY |
| 贵金属 | XAUUSD (黄金), XAGUSD (白银) |

## 项目结构

```
mt4/
├── experts/          # EA主程序入口
│   ├── TrendFollower.mq4
│   ├── MeanReversion.mq4
│   ├── BreakoutTrader.mq4
│   └── Scalper.mq4
│
├── strategies/       # 策略逻辑模块
│   ├── Trend/       # 趋势跟踪 (MA, MACD)
│   ├── MeanReversion/ # 均值回归 (RSI, 布林带)
│   ├── Breakout/    # 突破策略 (通道, 支撑阻力)
│   └── Scalping/    # 剥头皮策略
│
├── indicators/      # 自定义指标
├── risk/            # 风险管理模块
├── core/            # 核心框架
├── utils/           # 工具函数
├── include/         # 公共头文件
├── presets/         # 参数预设
└── tests/           # 测试脚本
```

## 快速开始

### 环境要求

- MetaTrader 4 终端
- MetaEditor (MT4自带)
- FXCM账户 (实盘或模拟)

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/yourusername/mt4.git
   ```

2. **复制到MT4数据目录**

   打开MT4 → 文件 → 打开数据文件夹，然后复制：
   ```
   mt4/experts/*    → MQL4/Experts/
   mt4/indicators/* → MQL4/Indicators/
   mt4/include/*    → MQL4/Include/
   mt4/presets/*    → MQL4/Presets/
   ```

3. **编译EA**

   在MetaEditor中打开experts目录下的.mq4文件，按F7编译

4. **运行EA**

   在MT4导航器中找到编译后的EA，拖拽到图表上

### 使用预设配置

1. 在EA属性中点击"加载"按钮
2. 选择 `presets/` 目录下对应品种的.set文件
3. 根据需要调整参数

## 策略说明

### 1. 趋势跟踪 (TrendFollower)

使用移动平均线和MACD识别趋势方向，顺势交易。

**适用场景**: 明显趋势行情
**时间框架**: H1, H4
**参数**: MA周期, MACD参数

### 2. 均值回归 (MeanReversion)

利用RSI和布林带识别超买超卖区域，反向交易。

**适用场景**: 震荡行情
**时间框架**: M15, H1
**参数**: RSI周期, 布林带周期

### 3. 突破策略 (BreakoutTrader)

识别价格通道突破和支撑阻力位突破。

**适用场景**: 突破行情
**时间框架**: H1, H4
**参数**: 通道周期, 突破确认K线数

### 4. 剥头皮 (Scalper)

高频短线交易，追求小波动利润。

**适用场景**: 流动性充足时段
**时间框架**: M1, M5
**参数**: 止损点数, 止盈点数

## 风险管理

本系统采用保守型风险管理：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| 单笔风险 | 1.5% | 每笔交易最大风险 |
| 日最大亏损 | 5% | 达到后停止交易 |
| 最大回撤 | 15% | 触发后暂停策略 |
| 日最多交易 | 5笔 | 限制过度交易 |

### 仓位计算公式

```
LotSize = (AccountBalance × RiskPercent) / (StopLossPips × PipValue)
```

## 回测指南

1. 打开策略测试器 (Ctrl+R)
2. 选择EA和交易品种
3. 设置时间范围 (建议至少1年)
4. 选择"每tick"模型
5. 运行并分析结果

**回测指标关注点**:
- 净利润
- 最大回撤
- 盈利因子
- 胜率
- 夏普比率

## 开发指南

### 添加新策略

1. 在 `strategies/` 下创建新目录
2. 继承 `CSignalGenerator` 基类
3. 实现 `GenerateSignal()` 方法
4. 在 `experts/` 创建对应EA入口

### 代码风格

详见 [.claude/claude.md](.claude/claude.md)

## 常见问题

**Q: 编译错误 "cannot open include file"**
> 确保include文件路径正确，检查MQL4/Include目录

**Q: EA不执行交易**
> 检查EA属性中的"允许实时交易"选项

**Q: 回测结果与实盘差异大**
> 考虑滑点、点差变化、执行延迟等因素

## 免责声明

本软件仅供学习和研究目的。量化交易存在风险，过往表现不代表未来收益。使用本系统进行实盘交易需自行承担风险。

## License

MIT License - 详见 [LICENSE](LICENSE) 文件

## 贡献

欢迎提交Issue和Pull Request！

---

**开发者**: Your Name
**更新日期**: 2024