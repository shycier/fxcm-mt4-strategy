//+------------------------------------------------------------------+
//|                                                Config.mqh        |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __Config_MQH__
#define __Config_MQH__


#include "../include/Constants.mqh"
#include "../include/Types.mqh"

//+------------------------------------------------------------------+
//| 配置管理类                                                         |
//+------------------------------------------------------------------+
class CConfig
{
private:
   string   m_fileName;       // 配置文件名
   string   m_section;        // 当前节

   //--- 内部存储
   string   m_keys[];         // 键数组
   string   m_values[];       // 值数组
   int      m_count;          // 条目数量

   //--- 私有方法
   int      FindKey(const string& key);
   void     TrimString(string& str);

public:
   //--- 构造函数
   CConfig();
   CConfig(const string& fileName);
   ~CConfig();

   //--- 文件操作
   bool     Load(const string& fileName = "");
   bool     Save(const string& fileName = "");

   //--- 节操作
   void     SetSection(const string& section) { m_section = section; }
   string   GetSection() const { return m_section; }

   //--- 读写方法
   void     SetString(const string& key, const string& value);
   string   GetString(const string& key, const string& defaultValue = "");

   void     SetInt(const string& key, int value);
   int      GetInt(const string& key, int defaultValue = 0);

   void     SetDouble(const string& key, double value);
   double   GetDouble(const string& key, double defaultValue = 0.0);

   void     SetBool(const string& key, bool value);
   bool     GetBool(const string& key, bool defaultValue = false);

   //--- 工具方法
   void     Clear();
   int      GetCount() const { return m_count; }
   bool     HasKey(const string& key);
   bool     RemoveKey(const string& key);

   //--- 枚举
   bool     GetFirstKey(string& key, string& value);
   bool     GetNextKey(string& key, string& value);
};

//+------------------------------------------------------------------+
//| 静态配置键定义                                                     |
//+------------------------------------------------------------------+
class CConfigKeys
{
public:
   //--- 风险参数
   static const string RISK_PERCENT;
   static const string MAX_DAILY_LOSS;
   static const string MAX_WEEKLY_LOSS;
   static const string MAX_DRAWDOWN;
   static const string MAX_DAILY_TRADES;
   static const string MAX_POSITIONS;

   //--- 策略参数
   static const string TIME_FRAME;
   static const string MA_PERIOD;
   static const string MA_METHOD;
   static const string RSI_PERIOD;
   static const string RSI_OVERBOUGHT;
   static const string RSI_OVERSOLD;
   static const string MACD_FAST;
   static const string MACD_SLOW;
   static const string MACD_SIGNAL;
   static const string ATR_PERIOD;
   static const string SL_PIPS;
   static const string TP_PIPS;

   //--- 交易设置
   static const string MAGIC_NUMBER;
   static const string SLIPPAGE;
   static const string TRAILING_STOP;
   static const string TRAILING_STEP;
   static const string MIN_TRADE_INTERVAL;

   //--- 日志设置
   static const string LOG_LEVEL;
   static const string LOG_TO_FILE;
   static const string LOG_TO_CONSOLE;
};

const string CConfigKeys::RISK_PERCENT    = "RiskPercent";
const string CConfigKeys::MAX_DAILY_LOSS  = "MaxDailyLoss";
const string CConfigKeys::MAX_WEEKLY_LOSS = "MaxWeeklyLoss";
const string CConfigKeys::MAX_DRAWDOWN    = "MaxDrawdown";
const string CConfigKeys::MAX_DAILY_TRADES = "MaxDailyTrades";
const string CConfigKeys::MAX_POSITIONS   = "MaxPositions";

const string CConfigKeys::TIME_FRAME      = "TimeFrame";
const string CConfigKeys::MA_PERIOD       = "MAPeriod";
const string CConfigKeys::MA_METHOD       = "MAMethod";
const string CConfigKeys::RSI_PERIOD      = "RSIPeriod";
const string CConfigKeys::RSI_OVERBOUGHT  = "RSIOverbought";
const string CConfigKeys::RSI_OVERSOLD    = "RSIOversold";
const string CConfigKeys::MACD_FAST       = "MACDFast";
const string CConfigKeys::MACD_SLOW       = "MACDSlow";
const string CConfigKeys::MACD_SIGNAL     = "MACDSignal";
const string CConfigKeys::ATR_PERIOD      = "ATRPeriod";
const string CConfigKeys::SL_PIPS         = "SLPips";
const string CConfigKeys::TP_PIPS         = "TPPips";

const string CConfigKeys::MAGIC_NUMBER    = "MagicNumber";
const string CConfigKeys::SLIPPAGE        = "Slippage";
const string CConfigKeys::TRAILING_STOP   = "TrailingStop";
const string CConfigKeys::TRAILING_STEP   = "TrailingStep";
const string CConfigKeys::MIN_TRADE_INTERVAL = "MinTradeInterval";

const string CConfigKeys::LOG_LEVEL       = "LogLevel";
const string CConfigKeys::LOG_TO_FILE     = "LogToFile";
const string CConfigKeys::LOG_TO_CONSOLE  = "LogToConsole";

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CConfig::CConfig() :
   m_fileName("config.ini"),
   m_section("General"),
   m_count(0)
{
   ArrayResize(m_keys, 100);
   ArrayResize(m_values, 100);
}

//+------------------------------------------------------------------+
//| 带文件名构造函数                                                   |
//+------------------------------------------------------------------+
CConfig::CConfig(const string& fileName) :
   m_fileName(fileName),
   m_section("General"),
   m_count(0)
{
   ArrayResize(m_keys, 100);
   ArrayResize(m_values, 100);
   Load();
}

//+------------------------------------------------------------------+
//| 析构函数                                                           |
//+------------------------------------------------------------------+
CConfig::~CConfig()
{
}

//+------------------------------------------------------------------+
//| 加载配置文件                                                       |
//+------------------------------------------------------------------+
bool CConfig::Load(const string& fileName)
{
   if(fileName != "") m_fileName = fileName;

   int handle = FileOpen(m_fileName, FILE_READ | FILE_CSV | FILE_ANSI);
   if(handle == INVALID_HANDLE) return false;

   Clear();

   string line;
   while(!FileIsEnding(handle))
   {
      line = FileReadString(handle);
      TrimString(line);

      //--- 跳过空行和注释
      if(line == "" || StringGetChar(line, 0) == '#' || StringGetChar(line, 0) == ';')
         continue;

      //--- 处理节
      if(StringGetChar(line, 0) == '[')
      {
         int end = StringFind(line, "]");
         if(end > 1)
         {
            m_section = StringSubstr(line, 1, end - 1);
         }
         continue;
      }

      //--- 处理键值对
      int pos = StringFind(line, "=");
      if(pos > 0)
      {
         string key = StringSubstr(line, 0, pos);
         string value = StringSubstr(line, pos + 1);

         TrimString(key);
         TrimString(value);

         //--- 添加到存储
         string fullKey = m_section + "." + key;
         SetString(fullKey, value);
      }
   }

   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| 保存配置文件                                                       |
//+------------------------------------------------------------------+
bool CConfig::Save(const string& fileName)
{
   if(fileName != "") m_fileName = fileName;

   int handle = FileOpen(m_fileName, FILE_WRITE | FILE_CSV | FILE_ANSI);
   if(handle == INVALID_HANDLE) return false;

   string currentSection = "";
   string key, value;

   for(int i = 0; i < m_count; i++)
   {
      //--- 解析完整键名
      int pos = StringFind(m_keys[i], ".");
      if(pos > 0)
      {
         string section = StringSubstr(m_keys[i], 0, pos);
         string keyName = StringSubstr(m_keys[i], pos + 1);

         //--- 写入节头
         if(section != currentSection)
         {
            currentSection = section;
            FileWrite(handle, "");
            FileWrite(handle, StringFormat("[%s]", section));
         }

         //--- 写入键值对
         FileWrite(handle, StringFormat("%s=%s", keyName, m_values[i]));
      }
   }

   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| 查找键索引                                                         |
//+------------------------------------------------------------------+
int CConfig::FindKey(const string& key)
{
   for(int i = 0; i < m_count; i++)
   {
      if(m_keys[i] == key)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| 去除字符串两端空白                                                 |
//+------------------------------------------------------------------+
void CConfig::TrimString(string& str)
{
   str = StringTrimLeft(str);
   str = StringTrimRight(str);
}

//+------------------------------------------------------------------+
//| 设置字符串值                                                       |
//+------------------------------------------------------------------+
void CConfig::SetString(const string& key, const string& value)
{
   int index = FindKey(key);

   if(index >= 0)
   {
      m_values[index] = value;
   }
   else
   {
      if(m_count >= ArraySize(m_keys))
      {
         ArrayResize(m_keys, m_count + 100);
         ArrayResize(m_values, m_count + 100);
      }

      m_keys[m_count] = key;
      m_values[m_count] = value;
      m_count++;
   }
}

//+------------------------------------------------------------------+
//| 获取字符串值                                                       |
//+------------------------------------------------------------------+
string CConfig::GetString(const string& key, const string& defaultValue)
{
   int index = FindKey(key);
   if(index >= 0)
      return m_values[index];
   return defaultValue;
}

//+------------------------------------------------------------------+
//| 设置整数值                                                         |
//+------------------------------------------------------------------+
void CConfig::SetInt(const string& key, int value)
{
   SetString(key, IntegerToString(value));
}

//+------------------------------------------------------------------+
//| 获取整数值                                                         |
//+------------------------------------------------------------------+
int CConfig::GetInt(const string& key, int defaultValue)
{
   string value = GetString(key);
   if(value == "") return defaultValue;
   return (int)StringToInteger(value);
}

//+------------------------------------------------------------------+
//| 设置浮点值                                                         |
//+------------------------------------------------------------------+
void CConfig::SetDouble(const string& key, double value)
{
   SetString(key, DoubleToString(value, 8));
}

//+------------------------------------------------------------------+
//| 获取浮点值                                                         |
//+------------------------------------------------------------------+
double CConfig::GetDouble(const string& key, double defaultValue)
{
   string value = GetString(key);
   if(value == "") return defaultValue;
   return StringToDouble(value);
}

//+------------------------------------------------------------------+
//| 设置布尔值                                                         |
//+------------------------------------------------------------------+
void CConfig::SetBool(const string& key, bool value)
{
   SetString(key, value ? "true" : "false");
}

//+------------------------------------------------------------------+
//| 获取布尔值                                                         |
//+------------------------------------------------------------------+
bool CConfig::GetBool(const string& key, bool defaultValue)
{
   string value = GetString(key);
   if(value == "") return defaultValue;
   return (value == "true" || value == "1" || value == "yes");
}

//+------------------------------------------------------------------+
//| 清空配置                                                           |
//+------------------------------------------------------------------+
void CConfig::Clear()
{
   m_count = 0;
}

//+------------------------------------------------------------------+
//| 检查键是否存在                                                     |
//+------------------------------------------------------------------+
bool CConfig::HasKey(const string& key)
{
   return (FindKey(key) >= 0);
}

//+------------------------------------------------------------------+
//| 删除键                                                             |
//+------------------------------------------------------------------+
bool CConfig::RemoveKey(const string& key)
{
   int index = FindKey(key);
   if(index < 0) return false;

   //--- 移动后续元素
   for(int i = index; i < m_count - 1; i++)
   {
      m_keys[i] = m_keys[i + 1];
      m_values[i] = m_values[i + 1];
   }

   m_count--;
   return true;
}

//+------------------------------------------------------------------+
//| 获取第一个键                                                       |
//+------------------------------------------------------------------+
bool CConfig::GetFirstKey(string& key, string& value)
{
   if(m_count == 0) return false;

   key = m_keys[0];
   value = m_values[0];
   return true;
}

//+------------------------------------------------------------------+
//| 获取下一个键                                                       |
//+------------------------------------------------------------------+
bool CConfig::GetNextKey(string& key, string& value)
{
   static int currentIndex = 0;

   currentIndex++;
   if(currentIndex >= m_count)
   {
      currentIndex = 0;
      return false;
   }

   key = m_keys[currentIndex];
   value = m_values[currentIndex];
   return true;
}

//+------------------------------------------------------------------+
#endif // __Config_MQH__
