//+------------------------------------------------------------------+
//|                                               MathUtils.mqh      |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __MathUtils_MQH__
#define __MathUtils_MQH__


#include "../include/Constants.mqh"

//+------------------------------------------------------------------+
//| 数学工具函数                                                       |
//+------------------------------------------------------------------+

//--- 计算简单移动平均
double SMA(const double& array[], int period, int shift = 0)
{
   if(period <= 0 || ArraySize(array) < period + shift) return 0;

   double sum = 0;
   for(int i = shift; i < shift + period; i++)
   {
      sum += array[i];
   }

   return sum / period;
}

//--- 计算指数移动平均
double EMA(const double& array[], int period, int shift = 0)
{
   if(period <= 0 || ArraySize(array) < period + shift) return 0;

   double multiplier = 2.0 / (period + 1.0);
   double ema = SMA(array, period, shift + period - 1); // 初始值用SMA

   for(int i = shift + period - 2; i >= shift; i--)
   {
      ema = (array[i] - ema) * multiplier + ema;
   }

   return ema;
}

//--- 计算标准差
double StandardDeviation(const double& array[], int period, int shift = 0)
{
   if(period <= 0 || ArraySize(array) < period + shift) return 0;

   double mean = SMA(array, period, shift);
   double sumSquares = 0;

   for(int i = shift; i < shift + period; i++)
   {
      double diff = array[i] - mean;
      sumSquares += diff * diff;
   }

   return MathSqrt(sumSquares / period);
}

//--- 计算ATR (Average True Range)
double CalculateATR(const string& symbol, int timeFrame, int period, int shift = 0)
{
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   if(CopyHigh(symbol, timeFrame, shift, period + 1, high) <= 0) return 0;
   if(CopyLow(symbol, timeFrame, shift, period + 1, low) <= 0) return 0;
   if(CopyClose(symbol, timeFrame, shift, period + 1, close) <= 0) return 0;

   double trSum = 0;

   for(int i = 0; i < period; i++)
   {
      double tr = high[i] - low[i]; // True Range

      if(i < period) // 计算与前一根K线的关系
      {
         double tr1 = MathAbs(high[i] - close[i + 1]);
         double tr2 = MathAbs(low[i] - close[i + 1]);
         tr = MathMax(tr, MathMax(tr1, tr2));
      }

      trSum += tr;
   }

   return trSum / period;
}

//--- 计算RSI
double CalculateRSI(const double& array[], int period, int shift = 0)
{
   if(period <= 0 || ArraySize(array) < period + shift + 1) return 50;

   double gainSum = 0, lossSum = 0;

   for(int i = shift; i < shift + period; i++)
   {
      double change = array[i] - array[i + 1];
      if(change > 0)
         gainSum += change;
      else
         lossSum -= change;
   }

   if(lossSum == 0) return 100;

   double avgGain = gainSum / period;
   double avgLoss = lossSum / period;

   double rs = avgGain / avgLoss;
   return 100.0 - (100.0 / (1.0 + rs));
}

//--- 计算MACD
void CalculateMACD(const double& array[], int fastPeriod, int slowPeriod, int signalPeriod,
                   double& macdLine, double& signalLine, double& histogram, int shift = 0)
{
   double fastEMA = EMA(array, fastPeriod, shift);
   double slowEMA = EMA(array, slowPeriod, shift);

   macdLine = fastEMA - slowEMA;

   //--- 简化的信号线计算
   double macdArray[];
   ArrayResize(macdArray, signalPeriod);
   ArraySetAsSeries(macdArray, true);

   for(int i = 0; i < signalPeriod; i++)
   {
      double fast = EMA(array, fastPeriod, shift + i);
      double slow = EMA(array, slowPeriod, shift + i);
      macdArray[i] = fast - slow;
   }

   signalLine = SMA(macdArray, signalPeriod, 0);
   histogram = macdLine - signalLine;
}

//--- 计算布林带
void CalculateBollingerBands(const double& array[], int period, double deviation,
                             double& middle, double& upper, double& lower, int shift = 0)
{
   middle = SMA(array, period, shift);
   double stdDev = StandardDeviation(array, period, shift);

   upper = middle + deviation * stdDev;
   lower = middle - deviation * stdDev;
}

//--- 计算支撑阻力位
void CalculateSupportResistance(double& support[], double& resistance[],
                               const string& symbol, int timeFrame, int period, int lookback = 100)
{
   ArrayResize(support, 3);
   ArrayResize(resistance, 3);

   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   if(CopyHigh(symbol, timeFrame, 0, lookback, high) <= 0) return;
   if(CopyLow(symbol, timeFrame, 0, lookback, low) <= 0) return;
   if(CopyClose(symbol, timeFrame, 0, lookback, close) <= 0) return;

   //--- 找出最高和最低点
   double highestHigh = high[ArrayMaximum(high, 0, lookback)];
   double lowestLow = low[ArrayMinimum(low, 0, lookback)];
   double currentClose = close[0];

   //--- 计算斐波那契回撤位
   double range = highestHigh - lowestLow;

   resistance[0] = lowestLow + range * 0.236; // 弱阻力
   resistance[1] = lowestLow + range * 0.382; // 中等阻力
   resistance[2] = lowestLow + range * 0.618; // 强阻力

   support[0] = highestHigh - range * 0.236;  // 弱支撑
   support[1] = highestHigh - range * 0.382;  // 中等支撑
   support[2] = highestHigh - range * 0.618;  // 强支撑
}

//--- 线性插值
double Lerp(double a, double b, double t)
{
   return a + (b - a) * t;
}

//--- 限制范围
double Clamp(double value, double min, double max)
{
   if(value < min) return min;
   if(value > max) return max;
   return value;
}

//--- 平滑过渡
double SmoothStep(double edge0, double edge1, double x)
{
   double t = Clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
   return t * t * (3.0 - 2.0 * t);
}

//--- 计算相关系数
double Correlation(const double& array1[], const double& array2[], int count)
{
   if(count <= 0 || ArraySize(array1) < count || ArraySize(array2) < count) return 0;

   double sum1 = 0, sum2 = 0, sum12 = 0, sum11 = 0, sum22 = 0;

   for(int i = 0; i < count; i++)
   {
      sum1 += array1[i];
      sum2 += array2[i];
      sum12 += array1[i] * array2[i];
      sum11 += array1[i] * array1[i];
      sum22 += array2[i] * array2[i];
   }

   double n = count;
   double numerator = n * sum12 - sum1 * sum2;
   double denominator = MathSqrt((n * sum11 - sum1 * sum1) * (n * sum22 - sum2 * sum2));

   if(denominator == 0) return 0;

   return numerator / denominator;
}

//+------------------------------------------------------------------+
#endif // __MathUtils_MQH__
