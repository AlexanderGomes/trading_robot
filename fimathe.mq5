#include <Trade/Trade.mqh>
CTrade trade;

enum trade_options {
 sell,
 buy,
 all,
}; 

enum MY_TIMEFRAME {
    M1      =PERIOD_M1,            
    M5      =PERIOD_M5,            
    M15     =PERIOD_M15,          
    M30     =PERIOD_M30,           
    H1      =PERIOD_H1,            
    H4      =PERIOD_H4,           
    CURRENT =PERIOD_CURRENT        
}; 

input MY_TIMEFRAME inp_timeframe = CURRENT;

int OnInit()
{
    ChartSetSymbolPeriod(0, _Symbol, (ENUM_TIMEFRAMES) inp_timeframe);
    return INIT_SUCCEEDED;
}


// user inputs
input trade_options trade_choices = all; 
input double line_1 = 0; 
input double line_2 = 0; 
input int pips_outside_zona_neutra = 0;
input int pips_above_zero_zero = 0;
input int take_levels = 1;
input double risk_percentage = 0;


// program inputs
double channel_size_points = NormalizeDouble(MathAbs(line_1 - line_2) / _Point * _Point,_Digits);
double reference_line_1 = line_1;
double reference_line_2 = line_2;
double zero_zero = 0.0;


bool change_sl = false;
int position_type;
ulong ticket_id;
double current_stopL;


//TODO - check if statements and improve how many times they are being fired.
void OnTick() {
bool isBuying = reference_line_1 > reference_line_2;
double zona_neutra = isBuying ? NormalizeDouble(reference_line_2 - channel_size_points,_Digits) : NormalizeDouble(reference_line_2 + channel_size_points,_Digits);
double next_reference_line = isBuying ? NormalizeDouble(reference_line_1 + channel_size_points,_Digits) : NormalizeDouble(reference_line_1 - channel_size_points,_Digits);
double last_candle_close_price = GetLastClosePrice();


if(!PositionSelectByTicket(ticket_id)) {
    ticket_id = 0;
}

 if(isBuying) {

   if(last_candle_close_price > reference_line_1) {
   
    bool can_open_order_buy = ticket_id <= 0 && (trade_choices == buy || trade_choices == all);
    if(can_open_order_buy) {
       current_stopL = NormalizeDouble(zona_neutra - pips_outside_zona_neutra * _Point, _Digits);
       OpenOrder(current_stopL,isBuying);
   }

    reference_line_2 = reference_line_1;
    reference_line_1 = next_reference_line;
   }
   
   bool can_invert_lines_buy = last_candle_close_price < zona_neutra;
   if(can_invert_lines_buy) {
     reference_line_1 = zona_neutra;
   }
   
   bool can_breakeven_buy = ticket_id > 0 && last_candle_close_price > zero_zero  && position_type == POSITION_TYPE_BUY;
   if(can_breakeven_buy) {
   change_sl = true;
   ModifyPositionSLAndTP(ticket_id,isBuying);
  }
   
   
 } else {
 
   if(last_candle_close_price < reference_line_1) {
   
    bool can_open_order_sell = ticket_id <= 0 && (trade_choices == sell || trade_choices == all);
    if(can_open_order_sell) {
     current_stopL = NormalizeDouble(zona_neutra + pips_outside_zona_neutra * _Point, _Digits);
     OpenOrder(current_stopL,isBuying);
    }
    
    reference_line_2 = reference_line_1;
    reference_line_1 = next_reference_line;
   }
   
   bool can_invert_lines_sell = last_candle_close_price > zona_neutra;
   if(can_invert_lines_sell) {
     reference_line_1 = zona_neutra;
    }
    
  bool can_breakeven_sell = ticket_id > 0 && last_candle_close_price < zero_zero && position_type == POSITION_TYPE_SELL;
  if(can_breakeven_sell) {
   change_sl = true;
   ModifyPositionSLAndTP(ticket_id,isBuying);
  }
  
 }

 CreateLines(reference_line_1, reference_line_2, zona_neutra, channel_size_points, zero_zero);
}


void CreateLines(double value1, double value2, double value3, double channelsize, double zero) {
  ObjectCreate(0,"first line", OBJ_HLINE,0,0,value1);
  ObjectCreate(0,"second line", OBJ_HLINE,0,0,value2);
  ObjectCreate(0,"neutral line", OBJ_HLINE,0,0,value3);
  ObjectCreate(0,"zero_zero", OBJ_HLINE,0,0, zero);
  
  ObjectSetInteger(0,"first line",OBJPROP_COLOR,clrBlue);
  ObjectSetInteger(0,"second line",OBJPROP_COLOR,clrBlue);
  ObjectSetInteger(0,"neutral line",OBJPROP_COLOR,clrGold);
  ObjectSetInteger(0,"zero_zero",OBJPROP_COLOR,clrAqua);

}


double GetLastClosePrice () {
   MqlRates princeInfo[];
   ArraySetAsSeries(princeInfo,true);
   int price_data = CopyRates(_Symbol,_Period,1,1,princeInfo);
   return princeInfo[0].close;
}


void OpenOrder(double calculated_sl, bool buying) {
    double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID); 
    int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    double stop_loss_distance = NormalizeDouble(MathAbs(calculated_sl - (buying ? bid : ask)),_Digits);
    double lote = NormalizeDouble(account_equity * risk_percentage / ((stop_loss_distance / _Point) + spread), _Digits);
  
    if (buying)
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


void ModifyPositionSLAndTP(ulong ticket, bool buying)
{

    if (PositionSelectByTicket(ticket))
    {
        position_type = (int)PositionGetInteger(POSITION_TYPE);
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double old_sl = PositionGetDouble(POSITION_SL);
        double old_tp = PositionGetDouble(POSITION_TP);
        double tp_size = NormalizeDouble(MathAbs(open_price - old_sl) / _Point * _Point, _Digits);
        double tp;
        
       
        if (buying) {
           tp = NormalizeDouble(open_price + (tp_size * take_levels), _Digits);
           zero_zero = NormalizeDouble(open_price + (tp_size / 2), _Digits);
        } else {
            tp = NormalizeDouble(open_price - (tp_size * take_levels), _Digits);
            zero_zero = NormalizeDouble(open_price - (tp_size / 2), _Digits);
        }
             
           if(change_sl) {
            old_sl = buying ? NormalizeDouble(open_price + (pips_above_zero_zero * _Point),_Digits) : NormalizeDouble(open_price - (pips_above_zero_zero * _Point),_Digits);
            tp = old_tp;
            change_sl = false;
            zero_zero = 0;
          }
             
        trade.PositionModify(ticket_id,old_sl,tp);
    }
}


double get_last_order_profit() {
uint total_orders = HistoryDealsTotal();
HistorySelect(0,TimeCurrent());
ulong ticket_number = 0;
double profit = 0;
string symbol;

   for(uint i = 0; i <total_orders; i++) {
   if((ticket_number=HistoryDealGetTicket(i))>0) {
   symbol=HistoryDealGetString(ticket_number,DEAL_SYMBOL);
  
  if(symbol == _Symbol) {
   profit = HistoryDealGetDouble(ticket_number,DEAL_PROFIT);
   }
  }
 }
 
return profit;
}