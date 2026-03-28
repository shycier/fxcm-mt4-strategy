//+------------------------------------------------------------------+
//|                                                  Logger.mqh       |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#ifndef __Logger_MQH__
#define __Logger_MQH__


#include "../include/Constants.mqh"
#include "../include/Types.mqh"

//+------------------------------------------------------------------+
//| 日志管理类                                                         |
//+------------------------------------------------------------------+
class CLogger
{
private:
   int      m_logLevel;        // 当前日志级别
   string   m_logFile;         // 日志文件名
   bool     m_writeToFile;     // 是否写入文件
   bool     m_writeToConsole;  // 是否输出到控制台
   string   m_prefix;          // 日志前缀

   //--- 私有方法
   void     WriteLog(int level, const string message, const string function = "", int line = 0);

public:
   //--- 构造函数
   CLogger();
   CLogger(int logLevel, bool toFile = true, bool toConsole = true);

   //--- 配置方法
   void     SetLogLevel(int level)       { m_logLevel = level; }
   void     SetPrefix(const string prefix) { m_prefix = prefix; }
   void     EnableFileLogging(bool enable) { m_writeToFile = enable; }
   void     EnableConsoleLogging(bool enable) { m_writeToConsole = enable; }

   //--- 日志方法
   void     Error(const string message, const string function = "", int line = 0);
   void     Warning(const string message, const string function = "", int line = 0);
   void     Info(const string message, const string function = "", int line = 0);
   void     Debug(const string message, const string function = "", int line = 0);

   //--- 格式化日志
   void     LogTrade(const string action, double lots, const string symbol,
                     double price, double sl, double tp, const string comment = "");
   void     LogSignal(int signalType, const string reason);
   void     LogError(int errorCode, const string description);

   //--- 工具方法
   string   GetLevelName(int level);
   string   GetTimeString();
   void     ClearLogFile();
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CLogger::CLogger() :
   m_logLevel(LOG_LEVEL_INFO),
   m_logFile("trader.log"),
   m_writeToFile(true),
   m_writeToConsole(true),
   m_prefix("TRADER")
{
}

//+------------------------------------------------------------------+
//| 带参数构造函数                                                     |
//+------------------------------------------------------------------+
CLogger::CLogger(int logLevel, bool toFile, bool toConsole) :
   m_logLevel(logLevel),
   m_logFile("trader.log"),
   m_writeToFile(toFile),
   m_writeToConsole(toConsole),
   m_prefix("TRADER")
{
}

//+------------------------------------------------------------------+
//| 写入日志                                                           |
//+------------------------------------------------------------------+
void CLogger::WriteLog(int level, const string message, const string function, int line)
{
   if(level > m_logLevel) return;

   string levelName = GetLevelName(level);
   string timeStr = GetTimeString();
   string logMessage;

   //--- 构建日志消息
   if(function != "" && line > 0)
      logMessage = StringFormat("[%s] [%s] %s: %s (at %s:%d)",
                                timeStr, levelName, m_prefix, message, function, line);
   else
      logMessage = StringFormat("[%s] [%s] %s: %s",
                                timeStr, levelName, m_prefix, message);

   //--- 输出到控制台
   if(m_writeToConsole)
      Print(logMessage);

   //--- 写入文件
   if(m_writeToFile)
   {
      int handle = FileOpen(m_logFile, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI);
      if(handle != INVALID_HANDLE)
      {
         FileSeek(handle, 0, SEEK_END);
         FileWrite(handle, logMessage);
         FileClose(handle);
      }
   }
}

//+------------------------------------------------------------------+
//| 错误日志                                                           |
//+------------------------------------------------------------------+
void CLogger::Error(const string message, const string function, int line)
{
   WriteLog(LOG_LEVEL_ERROR, message, function, line);
}

//+------------------------------------------------------------------+
//| 警告日志                                                           |
//+------------------------------------------------------------------+
void CLogger::Warning(const string message, const string function, int line)
{
   WriteLog(LOG_LEVEL_WARNING, message, function, line);
}

//+------------------------------------------------------------------+
//| 信息日志                                                           |
//+------------------------------------------------------------------+
void CLogger::Info(const string message, const string function, int line)
{
   WriteLog(LOG_LEVEL_INFO, message, function, line);
}

//+------------------------------------------------------------------+
//| 调试日志                                                           |
//+------------------------------------------------------------------+
void CLogger::Debug(const string message, const string function, int line)
{
   WriteLog(LOG_LEVEL_DEBUG, message, function, line);
}

//+------------------------------------------------------------------+
//| 交易日志                                                           |
//+------------------------------------------------------------------+
void CLogger::LogTrade(const string action, double lots, const string symbol,
                       double price, double sl, double tp, const string comment)
{
   string message = StringFormat("TRADE: %s %.2f %s @ %s, SL: %s, TP: %s%s%s",
                                 action, lots, symbol,
                                 FormatPrice(price, symbol),
                                 FormatPrice(sl, symbol),
                                 FormatPrice(tp, symbol),
                                 (comment != "") ? ", Comment: " : "",
                                 comment);
   Info(message);
}

//+------------------------------------------------------------------+
//| 信号日志                                                           |
//+------------------------------------------------------------------+
void CLogger::LogSignal(int signalType, const string reason)
{
   string signalName;
   switch(signalType)
   {
      case SIGNAL_BUY:  signalName = "BUY"; break;
      case SIGNAL_SELL: signalName = "SELL"; break;
      default:          signalName = "NONE"; break;
   }

   Info(StringFormat("SIGNAL: %s - %s", signalName, reason));
}

//+------------------------------------------------------------------+
//| 错误日志                                                           |
//+------------------------------------------------------------------+
void CLogger::LogError(int errorCode, const string description)
{
   Error(StringFormat("Error %d: %s", errorCode, description));
}

//+------------------------------------------------------------------+
//| 获取级别名称                                                       |
//+------------------------------------------------------------------+
string CLogger::GetLevelName(int level)
{
   switch(level)
   {
      case LOG_LEVEL_ERROR:   return "ERROR";
      case LOG_LEVEL_WARNING: return "WARN";
      case LOG_LEVEL_INFO:    return "INFO";
      case LOG_LEVEL_DEBUG:   return "DEBUG";
      default:                return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| 获取时间字符串                                                     |
//+------------------------------------------------------------------+
string CLogger::GetTimeString()
{
   datetime now = TimeCurrent();
   return TimeToString(now, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| 清空日志文件                                                       |
//+------------------------------------------------------------------+
void CLogger::ClearLogFile()
{
   int handle = FileOpen(m_logFile, FILE_WRITE | FILE_CSV | FILE_ANSI);
   if(handle != INVALID_HANDLE)
      FileClose(handle);
}

//+------------------------------------------------------------------+
//| 全局日志实例                                                       |
//+------------------------------------------------------------------+
CLogger g_logger;
#define LOG_ERROR(msg) g_logger.Error(msg, __FUNCTION__, __LINE__)
#define LOG_WARNING(msg) g_logger.Warning(msg, __FUNCTION__, __LINE__)
#define LOG_INFO(msg) g_logger.Info(msg, __FUNCTION__, __LINE__)
#define LOG_DEBUG(msg) g_logger.Debug(msg, __FUNCTION__, __LINE__)
//+------------------------------------------------------------------+
#endif // __Logger_MQH__
