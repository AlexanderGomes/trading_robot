#include <Trade/Trade.mqh>
CTrade trade;

enum trade_options {
 sell = 0,
 buy = 1,
 all = 2,
}; 

// user inputs
input trade_options trade_choices = all; 
input double line_1 = 0; 
input double line_2 = 0; 
input int pips_outside_zona_neutra = 0;
input int pips_above_zero_zero = 0;
input int take_levels = 1;
input double lote = 0;


// program inputs
double channel_size_points = NormalizeDouble(MathAbs(line_1 - line_2) / _Point * _Point,_Digits);
double reference_line_1 = line_1;
double reference_line_2 = line_2;
double zero_zero;
bool change_sl = false;
int position_type;
ulong ticket_id;


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
     if(ticket_id <= 0 && (trade_choices == 1 || trade_choices == 2)) {
     OpenOrder(zona_neutra,isBuying);
   }

   
    reference_line_2 = reference_line_1;
    reference_line_1 = next_reference_line;
   }
   
   if(last_candle_close_price < zona_neutra) {
     reference_line_1 = zona_neutra;
   }
   
  if(ticket_id > 0 && last_candle_close_price > zero_zero  && position_type == POSITION_TYPE_BUY) {
   change_sl = true;
   ModifyPositionSLAndTP(ticket_id,isBuying);
  }
   
   
 } else {
 
   if(last_candle_close_price < reference_line_1) {
  
    if(ticket_id <= 0 && (trade_choices == 0 || trade_choices == 2)) {
      OpenOrder(zona_neutra,isBuying);
    }
    reference_line_2 = reference_line_1;
    reference_line_1 = next_reference_line;
   }
 
   if(last_candle_close_price > zona_neutra) {
     reference_line_1 = zona_neutra;
    }
    
  if(ticket_id > 0 && last_candle_close_price < zero_zero && position_type == POSITION_TYPE_SELL) {
   change_sl = true;
   ModifyPositionSLAndTP(ticket_id,isBuying);
  }
 }


// optmize function, being called even when values haven't changed
 CreatLines(reference_line_1,reference_line_2,zona_neutra,channel_size_points,zero_zero);
}

// find a way to create text at the right place
void CreatLines(double value1, double value2, double value3, double channelsize, double zero) {
  ObjectCreate(0,"first line", OBJ_HLINE,0,0,value1);
  ObjectCreate(0,"second line", OBJ_HLINE,0,0,value2);
  ObjectCreate(0,"neutral line", OBJ_HLINE,0,0,value3);
  ObjectCreate(0,"zero_zero", OBJ_HLINE,0,0, zero);
  
  ObjectSetInteger(0,"first line",OBJPROP_COLOR,clrBlue);
  ObjectSetInteger(0,"second line",OBJPROP_COLOR,clrBlue);
  ObjectSetInteger(0,"neutral line",OBJPROP_COLOR,clrGold);
  ObjectSetInteger(0,"zero_zero",OBJPROP_COLOR,clrAqua);
}

// set period of client choise instead current period, other wise you have to open a new chart to change the timeframe, can't change the timeframe after initiating the robot
double GetLastClosePrice () {
   MqlRates princeInfo[];
   ArraySetAsSeries(princeInfo,true);
   int price_data = CopyRates(_Symbol,_Period,1,1,princeInfo); // depending on what time frame, you have to specify, time frames have different close times
   return princeInfo[0].close;
}


void OpenOrder(double neutro, bool buying)
{
    double info = SymbolInfoDouble(_Symbol, buying ? SYMBOL_ASK : SYMBOL_BID);
    double sl;

    if (buying)
    {
        sl = NormalizeDouble(neutro - pips_outside_zona_neutra * _Point, _Digits);
        trade.Buy(lote, _Symbol, info, sl, NULL);
        ticket_id = trade.ResultOrder();
    }
    else
    {
        sl = NormalizeDouble(neutro + pips_outside_zona_neutra * _Point, _Digits);
        trade.Sell(lote, _Symbol, info, sl, NULL);
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
          }
             
        trade.PositionModify(ticket_id, old_sl, tp);
    }
}
