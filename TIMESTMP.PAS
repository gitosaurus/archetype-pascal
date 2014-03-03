{ TIMESTMP.PAS

Description:
  A short & sweet collection of routines for getting and testing a
  unique timestamp.

}

unit timestmp;

interface

  uses Dos;

  type

    timestamp_type = longint;

{ Global Variables }
  var
    GTimeStamp : timestamp_type;

  procedure get_time_stamp(var tstamp : timestamp_type);

implementation

{ get_time_stamp

Description:
  Creates a compressed long integer that contains all the necessary
  time information.  There are enough bits in a 32-bit word to do this:

  Variable      Range                             Bits
  --------      -----                             ----
  Year          0-63                                6
  Month         1-12                                4
  Day           0-31                                5
  Hour          0-23                                5
  Minute        0-59                                6
  Second        0-59                                6

Note that Year does not quite fit comfortably into this scheme.  The
actual returned value is 1980-2099, a span of 119 years; but we are using
only 63.  Year 0 is considered 1992 and the upper limit is 2055 before it
goes back to year 0 (1992) again.

The DayOfWeek information is thrown away because it is redundant, and
the Sec100 information is thrown away because it is unnecessarily precise.

}

procedure get_time_stamp(var tstamp : timestamp_type);

  var
    Year, Month, Day, DayOfWeek : word;
    Hour, Minute, Second, Sec100 : word;

    temp : timestamp_type;

begin

  GetDate(Year, Month, Day, DayOfWeek);
  GetTime(Hour, Minute, Second, Sec100);

{ Normalize the year }
  tstamp := (Year - 1992) mod 64;
  tstamp := tstamp SHL 26;

  temp := Month;
  tstamp := tstamp OR (temp SHL 22);

  temp := Day;
  tstamp := tstamp OR (temp SHL 17);

  temp := Hour;
  tstamp := tstamp OR (temp SHL 12) OR (Minute SHL 6) OR Second

end;  { get_time_stamp }


end. { timestmp }
