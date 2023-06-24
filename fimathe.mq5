//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
CTrade trade;

enum trade_options
  {
   sell,
   buy,
   all,
  };

enum MY_TIMEFRAME
  {
   M1      =PERIOD_M1,
   M5      =PERIOD_M5,
   M15     =PERIOD_M15,
   M30     =PERIOD_M30,
   H1      =PERIOD_H1,
   H4      =PERIOD_H4,
   CURRENT =PERIOD_CURRENT
  };

// user inputs
input MY_TIMEFRAME inp_timeframe = CURRENT;
input trade_options trade_choices = all;
input double line_1 = 0;
input double line_2 = 0;
input int pips_outside_zona_neutra = 0;
input int pips_above_zero_zero = 0;
input int take_levels = 1;
input double risk_percentage = 0;
input bool can_break_even = false;
input double upper_zone = 1000000;
input double lower_zone = -1;
input int allowed_take_profits = 0;
input int allowed_stop_loss = 0;


// program inputs
double channel_size_points = NormalizeDouble(MathAbs(line_1 - line_2) / _Point * _Point,_Digits);
double reference_line_1 = line_1;
double reference_line_2 = line_2;
double zero_zero = 0.0;


bool change_sl = false;
int position_type;
ulong ticket_id = 0;
double current_stopL;
bool executed = false;

int wins = 0;
int losses = 0;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   ChartSetSymbolPeriod(0, _Symbol, (ENUM_TIMEFRAMES) inp_timeframe);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Remove lines from the chart
   ObjectDelete(0, "first line");
   ObjectDelete(0, "second line");
   ObjectDelete(0, "neutral line");
   ObjectDelete(0, "zero_zero");
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double prev_price = 0;
bool change_price = false;
void OnTick()
  {
   bool isBuying = reference_line_1 > reference_line_2;
   double zona_neutra = isBuying ? NormalizeDouble(reference_line_2 - channel_size_points,_Digits) : NormalizeDouble(reference_line_2 + channel_size_points,_Digits);
   double next_reference_line = isBuying ? NormalizeDouble(reference_line_1 + channel_size_points,_Digits) : NormalizeDouble(reference_line_1 - channel_size_points,_Digits);
   double last_candle_close_price = GetLastClosePrice();
   double current_price_trade = last_trade_value();
   
   if(prev_price != current_price_trade) {
     prev_price = current_price_trade;
     change_price = true;
     check_wins_and_losses();
   }
   
  
   if(!PositionSelectByTicket(ticket_id))
     {
      ticket_id = 0;
     }


   if(isBuying)
     {

      if(last_candle_close_price > reference_line_1)
        {

         bool can_open_order_buy = ticket_id <= 0 && (trade_choices == buy || trade_choices == all)   && (last_candle_close_price > upper_zone || last_candle_close_price < lower_zone || upper_zone == 0) && (wins < allowed_take_profits || allowed_take_profits == 0) && (losses < allowed_stop_loss || allowed_stop_loss == 0);
         if(can_open_order_buy)
           {
            current_stopL = NormalizeDouble(zona_neutra - pips_outside_zona_neutra * _Point, _Digits);
            OpenOrder(current_stopL,isBuying);
           }

         reference_line_2 = reference_line_1;
         reference_line_1 = next_reference_line;
        }

      bool can_invert_lines_buy = last_candle_close_price < zona_neutra;
      if(can_invert_lines_buy)
        {
         reference_line_1 = zona_neutra;
        }

      bool can_breakeven_buy = ticket_id > 0 && last_candle_close_price > zero_zero  && position_type == POSITION_TYPE_BUY && can_break_even;
      if(can_breakeven_buy)
        {
         if(!executed)
           {
            change_sl = true;
            executed = true;
            ModifyPositionSLAndTP(ticket_id,isBuying);
           }
        }
      else
        {
         executed = false;
        }


     }
   else
     {

      if(last_candle_close_price < reference_line_1)
        {

         bool can_open_order_sell = ticket_id <= 0 && (trade_choices == sell || trade_choices == all) && (last_candle_close_price < lower_zone || last_candle_close_price > upper_zone || lower_zone == 0) && (wins < allowed_take_profits || allowed_take_profits == 0) && (losses < allowed_stop_loss || allowed_stop_loss == 0);
         if(can_open_order_sell)
           {
            current_stopL = NormalizeDouble(zona_neutra + pips_outside_zona_neutra * _Point, _Digits);
            OpenOrder(current_stopL,isBuying);
           }

         reference_line_2 = reference_line_1;
         reference_line_1 = next_reference_line;
        }

      bool can_invert_lines_sell = last_candle_close_price > zona_neutra;
      if(can_invert_lines_sell)
        {
         reference_line_1 = zona_neutra;
        }


      bool can_breakeven_sell = ticket_id > 0 && last_candle_close_price < zero_zero && position_type == POSITION_TYPE_SELL && can_break_even;
      if(can_breakeven_sell)
        {
         if(!executed)
           {
            change_sl = true;
            executed = true;
            ModifyPositionSLAndTP(ticket_id,isBuying);
           }
        }
      else
        {
         executed = false;
        }

     }

   CreateLines(reference_line_1, reference_line_2, zona_neutra, zero_zero);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateLines(double value1, double value2, double value3, double zero)
  {
   if(ObjectGetDouble(0, "first line", OBJPROP_PRICE) != value1)
      ObjectCreate(0,"first line", OBJ_HLINE,0,0,value1);
   ObjectSetInteger(0,"first line",OBJPROP_COLOR,clrBlue);

   if(ObjectGetDouble(0, "second line", OBJPROP_PRICE) != value2)
      ObjectCreate(0,"second line", OBJ_HLINE,0,0,value2);
   ObjectSetInteger(0,"second line",OBJPROP_COLOR,clrBlue);

   if(ObjectGetDouble(0, "neutral line", OBJPROP_PRICE) != value3)
      ObjectCreate(0,"neutral line", OBJ_HLINE,0,0, value3);
   ObjectSetInteger(0,"neutral line",OBJPROP_COLOR,clrGold);

   if(ObjectGetDouble(0, "zero_zero", OBJPROP_PRICE) != zero)
      ObjectCreate(0,"zero_zero", OBJ_HLINE,0,0, zero);
   ObjectSetInteger(0,"zero_zero",OBJPROP_COLOR,clrAqua);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetLastClosePrice()
  {
   return iClose(_Symbol, _Period, 0);
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenOrder(double calculated_sl, bool buying)
  {
   check_wins_and_losses();
   double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double stop_loss_distance = NormalizeDouble(MathAbs(calculated_sl - (buying ? bid : ask)),_Digits);
   double lote = NormalizeDouble(account_equity * risk_percentage / ((stop_loss_distance / _Point) + spread), _Digits);

   if(buying)
     {
      trade.Buy(lote, _Symbol, ask, calculated_sl, NULL);
      ticket_id = trade.ResultOrder();
     }
   else
     {
      trade.Sell(lote, _Symbol, bid, calculated_sl, NULL);
      ticket_id = trade.ResultOrder();
     }

   ModifyPositionSLAndTP(ticket_id, buying);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyPositionSLAndTP(ulong ticket, bool buying)
  {

   if(PositionSelectByTicket(ticket))
     {
      position_type = (int)PositionGetInteger(POSITION_TYPE);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double old_sl = PositionGetDouble(POSITION_SL);
      double old_tp = PositionGetDouble(POSITION_TP);
      double tp_size = NormalizeDouble(MathAbs(open_price - old_sl) / _Point * _Point, _Digits);
      double tp;


      if(buying)
        {
         tp = NormalizeDouble(open_price + (tp_size * take_levels), _Digits);
         zero_zero = NormalizeDouble(open_price + (tp_size / 2), _Digits);
        }
      else
        {
         tp = NormalizeDouble(open_price - (tp_size * take_levels), _Digits);
         zero_zero = NormalizeDouble(open_price - (tp_size / 2), _Digits);
        }

      if(change_sl)
        {
         old_sl = buying ? NormalizeDouble(open_price + (pips_above_zero_zero * _Point),_Digits) : NormalizeDouble(open_price - (pips_above_zero_zero * _Point),_Digits);
         tp = old_tp;
         change_sl = false;
         zero_zero = 0;
        }

      trade.PositionModify(ticket_id,old_sl,tp);
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double last_trade_value()
  {
   uint total_orders = HistoryDealsTotal();
   HistorySelect(0,TimeCurrent());
   ulong ticket_number = 0;
   double profit = 0;
   string symbol;

   for(uint i = 0; i < total_orders; i++)
     {
      if((ticket_number=HistoryDealGetTicket(i))>0)
        {
         symbol=HistoryDealGetString(ticket_number,DEAL_SYMBOL);

         if(symbol == _Symbol)
           {
            profit = HistoryDealGetDouble(ticket_number,DEAL_PROFIT);
           }
        }
     }       
        return profit ;
  }

//+------------------------------------------------------------------+

void check_wins_and_losses() {
 double profit = last_trade_value();

 if(profit > 0 && change_price)
     {
      wins++;
     }
   else
      if(profit < 0 && change_price)
        {
         losses++;
}

change_price = false;
}