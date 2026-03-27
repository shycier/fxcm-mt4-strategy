//+------------------------------------------------------------------+
//|                                               TimeUtils.mqh      |
//|                                    Copyright 2024, FXCM Trader   |
//|                                       https://www.fxcm.com       |
//+------------------------------------------------------------------+
#pragma once

#include "../include/Constants.mqh"

//+------------------------------------------------------------------+
//| 时间工具函数                                                       |
//+------------------------------------------------------------------+

//--- 获取当前服务器时间的小时
int GetCurrentHour()
{
   return TimeHour(TimeCurrent());
}

//--- 获取当前服务器时间的分钟
int GetCurrentMinute()
{
   return TimeMinute(TimeCurrent());
}

//--- 获取当前星期几 (0=周日, 1=周一, ..., 6=周六)
int GetCurrentDayOfWeek()
{
   return DayOfWeek();
}

//--- 检查是否在指定时间范围内
bool IsInTimeRange(int startHour, int startMinute, int endHour, int endMinute)
{
   datetime currentTime = TimeCurrent();
   int currentHour = TimeHour(currentTime);
   int currentMinute = TimeMinute(currentTime);

   int currentMinutes = currentHour * 60 + currentMinute;
   int startMinutes = startHour * 60 + startMinute;
   int endMinutes = endHour * 60 + endMinute;

   if(startMinutes <= endMinutes)
   {
      return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
   }
   else // 跨日时段
   {
      return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
   }
}

//--- 检查是否在交易时段
bool IsInTradingSession(int session)
{
   int hour = GetCurrentHour();

   switch(session)
   {
      case SESSION_ASIA:
         return (hour >= SESSION_ASIA_START && hour < SESSION_ASIA_END);

      case SESSION_EUROPE:
         return (hour >= SESSION_EUROPE_START && hour < SESSION_EUROPE_END);

      case SESSION_US:
         return (hour >= SESSION_US_START && hour < SESSION_US_END);

      case SESSION_OVERLAP_EU_US:
         return (hour >= 13 && hour < 17); // 欧美重叠时段

      default:
         return false;
   }
}

//--- 检查是否为交易日
bool IsTradingDay()
{
   int dayOfWeek = DayOfWeek();
   // 周六(6)和周日(0)不交易
   return (dayOfWeek != 0 && dayOfWeek != 6);
}

//--- 检查是否为交易周第一天
bool IsFirstTradingDayOfWeek()
{
   return (DayOfWeek() == 1); // 周一
}

//--- 检查是否为交易周最后一天
bool IsLastTradingDayOfWeek()
{
   return (DayOfWeek() == 5); // 周五
}

//--- 获取本周开始时间
datetime GetWeekStart()
{
   datetime current = TimeCurrent();
   int dayOfWeek = DayOfWeek();
   if(dayOfWeek == 0) dayOfWeek = 7; // 将周日视为第7天

   datetime weekStart = current - (dayOfWeek - 1) * 86400;
   return StringToTime(TimeToString(weekStart, TIME_DATE) + " 00:00:00");
}

//--- 获取今日开始时间
datetime GetDayStart()
{
   return StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 00:00:00");
}

//--- 获取今日结束时间
datetime GetDayEnd()
{
   return StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 23:59:59");
}

//--- 计算两个时间之间的分钟数
int GetMinutesBetween(datetime time1, datetime time2)
{
   return (int)MathAbs((time2 - time1) / 60);
}

//--- 计算两个时间之间的小时数
int GetHoursBetween(datetime time1, datetime time2)
{
   return (int)MathAbs((time2 - time1) / 3600);
}

//--- 计算两个时间之间的天数
int GetDaysBetween(datetime time1, datetime time2)
{
   return (int)MathAbs((time2 - time1) / 86400);
}

//--- 获取下一个整点时间
datetime GetNextHourTime()
{
   datetime current = TimeCurrent();
   int currentHour = TimeHour(current);
   return StringToTime(TimeToString(current, TIME_DATE) + StringFormat(" %02d:00:00", currentHour + 1));
}

//--- 获取下一个交易日开始时间
datetime GetNextTradingDayStart()
{
   datetime current = TimeCurrent();
   int dayOfWeek = DayOfWeek();

   int daysToAdd = 1;
   if(dayOfWeek == 5) daysToAdd = 3; // 周五到下周一
   else if(dayOfWeek == 6) daysToAdd = 2; // 周六到下周一

   return current + daysToAdd * 86400;
}

//--- 检查是否为新闻发布时间前后（简单实现）
bool IsNearNewsTime(int minutesBefore = 30, int minutesAfter = 30)
{
   // 这里需要接入新闻日历API才能实现
   // 目前返回false，实际使用时需要扩展
   return false;
}

//--- 获取当前时区偏移（相对于GMT）
int GetTimeZoneOffset()
{
   // MT4服务器时间通常需要根据经纪商调整
   // 这里返回0，实际使用时需要根据经纪商设置
   return 0;
}

//--- 将服务器时间转换为GMT时间
datetime ServerToGMT(datetime serverTime)
{
   return serverTime - GetTimeZoneOffset() * 3600;
}

//--- 将GMT时间转换为服务器时间
datetime GMTToServer(datetime gmtTime)
{
   return gmtTime + GetTimeZoneOffset() * 3600;
}

//--- 检查是否为假期（简单实现）
bool IsHoliday()
{
   // 需要根据具体假期列表实现
   // 这里检查常见的市场关闭日
   int month = TimeMonth(TimeCurrent());
   int day = TimeDay(TimeCurrent());

   // 新年（1月1日）
   if(month == 1 && day == 1) return true;

   // 圣诞节（12月25日）
   if(month == 12 && day == 25) return true;

   return false;
}

//--- 获取交易时段名称
string GetSessionName(int session)
{
   switch(session)
   {
      case SESSION_ASIA:     return "Asia";
      case SESSION_EUROPE:   return "Europe";
      case SESSION_US:       return "US";
      case SESSION_OVERLAP_EU_US: return "EU-US Overlap";
      default:               return "None";
   }
}

//--- 格式化时间持续时间
string FormatDuration(int seconds)
{
   if(seconds < 60)
      return StringFormat("%d sec", seconds);
   else if(seconds < 3600)
      return StringFormat("%d min %d sec", seconds / 60, seconds % 60);
   else if(seconds < 86400)
      return StringFormat("%d hr %d min", seconds / 3600, (seconds % 3600) / 60);
   else
      return StringFormat("%d day %d hr", seconds / 86400, (seconds % 86400) / 3600);
}

//+------------------------------------------------------------------+