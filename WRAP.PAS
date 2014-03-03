{ WRAP.PAS

Description:
  Contains routines for writing things out to screen in a word-wrapped
  fashion, and also for writing errors that will not interrupt the flow.

}

unit wrap;

interface

  uses Crt, misc;

  procedure wrapint(i : integer; terminate : boolean);
  procedure wrapout(s : string; terminate : boolean);
  procedure wraperr(s : string);
  function ReadLine(full_line : boolean) : string_ptr;
  procedure cursor_reset;

  var
    Rows : integer;       { number of the row in the current "screenful" }

implementation

  const

    MAXCOLS = 75;               { leave room for punctuation }
    SAFETY_MARGIN = 3;
    MAXROWS = 24;

    REVERSE_VID = 3;
    BOLDFACE = 8;

  var
    cursor         : integer;

{ wrap_wait

Description:
  The built-in "more" function of Archetype.

}

procedure wrap_wait;

  var ch: char;

begin

  TextColor(BOLDFACE); TextBackground(REVERSE_VID);
  write('Hit any key to continue...');
  ch := ReadKey;
  write(chr(13));
  NormVideo;
  ClrScr;     { or ClrEol if you don't want the whole screen }
  Rows := 0

end;


{ wrapint

Description:
  When we want to wrap a number.

}

procedure wrapint(i : integer; terminate : boolean);

  var s : string;

begin

  str(i, s);
  wrapout(s, terminate)

end;


{ wrapout

Description:
  Given a string, writes it out to screen, making sure that if it exceeds
  the screen columns, it is broken at natural word boundaries (i.e.
  white space).

}

procedure wrapout(s : string; terminate : boolean);

  var
    thisline, maxchars, startnext : integer;

begin

{ 'thisline' starts out as the maximum number of characters that can be
  written before a newline; it gets trimmed back to being the number of
  characters from the string that are actually written on this line. }

  maxchars := MAXCOLS - cursor;

  if s[1] in ['.', ',', ':', ';', ')', '-', '"'] then
    maxchars := maxchars + SAFETY_MARGIN;

  thisline := maxchars;
  while thisline < length(s) do begin
    while (thisline > 0) and (s[thisline] <> ' ') do
      dec(thisline);

{ If we were unable to find a wrapping point then it means one of two
  things:  a) the string is too long to fit on one line, and must be
  split unnaturally; or b) we are near the end of a line and must wrap
  the entire string; i.e. print nothing, finish the line and go on. }

    if (thisline = 0) and (length(s) > MAXCOLS) then
      thisline := maxchars + 1;

    writeln(Copy(s, 1, thisline - 1));
    inc(Rows);
    if Rows >= MAXROWS then wrap_wait;
    startnext := thisline;
    while s[startnext] = ' ' do inc(startnext);
    s := Copy(s, startnext, length(s));
    cursor := 1;
    thisline := MAXCOLS - cursor
  end;
  write(s);
  inc(cursor, length(s));

  if terminate then begin
    writeln;
    inc(Rows);
    if Rows >= MAXROWS then wrap_wait;
    cursor := 1
  end

end;  { wrapout }



{ wraperr

Description:
  Used for printing run-time errors.  It will print the error message on
  a line by itself and pick up the next line at the exact same cursor
  position.

}

procedure wraperr(s : string);

  var i : integer;

begin

  if cursor > 1 then writeln;
  writeln(s);
  for i := 1 to (cursor - 1) do
    write(' ')

end;



{ ReadLine

Description:
  Hides the extra stack space necessary for performing a readln() so that
  it won't affect eval_expr.

}

function ReadLine(full_line : boolean) : string_ptr;

  var
    s : string;

begin

  if full_line then
    readln(s)
  else
    s := ReadKey;
  ReadLine := NewDynStr(s)

end;



{ cursor_reset

Description:
  Used for directly resetting the cursor position by means other than
  physically wrapping it around.

}

procedure cursor_reset;

begin

  cursor := 1

end;



begin

  cursor_reset;
  Rows := 0

end.  { unit wrap }
