{ TOKEN

  Description:
    Contains variables and routines having to do with returning a
    stream of tokens from an .ACL file.

}
{$V-}

unit token;

interface

  uses misc, xarray, id_table, keywords;

{ Constants }
  const
    White_Space = [chr(32), chr(9), NEWLINE_CH];
    Literal_Type = [chr(34), chr(39)];
    Letters = ['A'..'Z', 'a'..'z'];
    Digits = ['0'..'9'];
    ID_Start_Chars = Letters + ['_'];
    ID_Chars = ID_Start_Chars + Digits;
    Long_Opers = ['<', '>', ':', '+', '-', '*', '/', '&', '~'];
    Oper_Chars = Long_Opers + ['=', '.', '^', '?'];


{ Procedures and Functions }
  function get_token(var f: progfile): boolean;
  procedure write_token(the_type: acl_type; the_number: longint);

implementation


{ Type declarations }
  type
    state_type = (START, STOP, DECIDE, WHITE, COMMENT, QUOTE,
                  LITERAL, IDENTIFIER, NUMBER, OPERATOR);


{ binary_search

Description:
  Performs a binary search on the given ordered array, passing back the
  index of the given string if it's in the array.
  Used for quickly finding an operator or reserved word.

Arguments:
  the_array (IN)        -- ordered array of short strings
  elements (IN)         -- number of elements in the array
  match_str (IN)        -- string to match
  a_index (OUT)         -- the array index

Returns:
  TRUE if match_str was an element in the_array; FALSE otherwise.

}

function binary_search(var the_array: lookup_type;
                       elements: integer;
                       var match_str: short_str_type;
                       var a_index: longint): boolean;

var
  left, right, mid: integer;

begin

  left := 1;
  right := elements;

  repeat
    mid := (left + right) div 2;
    if match_str < the_array[mid] then
      right := mid - 1
    else
      left := mid + 1
  until (match_str = the_array[mid]) or (left > right);
  if match_str <> the_array[mid] then
    binary_search := FALSE
  else begin
    a_index := mid;
    binary_search := TRUE
  end

end;  { binary_search }



{ add_unique_str

Description:
  Searches the given unordered xarray for a string matching the given
  string; if found, returns the index in the list of the string.  If
  not found, adds it to the list.

Arguments:
  the_xarray (IN/OUT)       --  xarray to be searched
  the_str (IN)              --  string to be compared

Returns:
  The index of the_str in the_xarray.

}

function add_unique_str(var the_xarray: xarray_type;
                        var the_str: string): integer;

  var
    new_str, str_index: string_ptr;
    i: integer;
    p: pointer;

begin

{ Duplicate the given string }
  new_str := NewConstStr(the_str);

  if the_xarray.size = 0 then begin
    append_to_xarray(the_xarray, pointer(new_str));
    add_unique_str := the_xarray.size
  end
  else begin
    i := 1;
    while index_xarray(the_xarray, i, p) and
          (string_ptr(p)^ <> the_str) do
      inc(i);
    if string_ptr(p)^ = the_str then begin
      add_unique_str := i;
      FreeConstStr(new_str);
    end
    else begin
      append_to_xarray(the_xarray, pointer(new_str));
      add_unique_str := the_xarray.size
    end
  end  { the_xarray.size > 0 }

end;  { add_unique_str }



{ add_non_unique_str

Description:
  Similar to the above, except that it is to be used when the strings are
  not expected to repeat much.

}

function add_non_unique_str(var the_xarray: xarray_type;
                            var the_str: string): integer;

begin

  append_to_xarray(the_xarray, pointer(NewConstStr(the_str)));
  add_non_unique_str := the_xarray.size

end;



{ get_token

Description:
  State machine which passes out the next token from the file f_in.

  A token is a constant (including parse words and literal text),
  a reserved word, or an operator (including the curly braces).

Arguments:
  f  (IN/OUT)       -- the input file

Returns:
  TRUE  if there is a token available;
  FALSE if the file f_in is empty.

}

function get_token(var f: progfile): boolean;

  var
    state      : state_type;
    more_chars : boolean;
    bracket    : char;
    next_ch    : char;
    s          : string;
    code       : integer;
    index      : integer;

begin

{ Check for old token.  f.newlines may have changed while an old
  token was unconsumed, so if the unconsumed token was a NEWLINE
  and f.newlines is FALSE, we must continue and get another token;
  otherwise we jump out with what we have. }

  if not f.consumed then begin
    f.consumed := TRUE;
    if not ((f.ttype = NEWLINE) and (not f.newlines)) then begin
      get_token := TRUE;
      exit
    end
  end;

  more_chars := TRUE;
  state      := START;
  s          := '';

  while state <> STOP do

    case state of

      START:
        if read_char(f, next_ch) then
          state := DECIDE
        else begin
          more_chars := FALSE;
          state := STOP
        end;

      DECIDE:
        if not more_chars then
          state := STOP
        else if next_ch in White_Space then
          state := WHITE
        else if next_ch in Literal_Type then
          state := LITERAL
        else if next_ch in ID_Start_Chars then
          state := IDENTIFIER
        else if next_ch in Digits then
          state := NUMBER
        else if next_ch in Oper_Chars then
          state := OPERATOR
        else                    { a single-character token }
          case next_ch of
            '#' :
              state := COMMENT;
            ';' :
              if not f.newlines then
                state := START
              else begin
                f.ttype := NEWLINE;
                f.tnum := ord(NEWLINE_CH);
                state := STOP
              end;
            else begin
              f.ttype := PUNCTUATION;
              f.tnum  := ord(next_ch);
              state := STOP
            end;
          end;  { case }

      WHITE: begin
        while (state = WHITE) and (next_ch in White_Space) do begin
          if (next_ch = NEWLINE_CH) and f.newlines then begin
            f.ttype := NEWLINE;
            state   := STOP
          end
          else
            more_chars := read_char(f, next_ch);
        end;
        if state = WHITE then
          if more_chars then          { decide on new non-white character }
            state := DECIDE
          else
            state := STOP
      end;

      COMMENT, QUOTE: begin
        s := '';
        more_chars := read_char(f, next_ch);
        while more_chars and (next_ch <> NEWLINE_CH) do begin
          s := s + next_ch;
          more_chars := read_char(f, next_ch)
        end;
        if state = COMMENT then
          if more_chars then
            state := START
          else
            state := STOP
        else begin                        { quoted literal }
          unread_char(f, next_ch);           { leave \n for the next guy }
          f.ttype    := QUOTE_LIT;
          f.tnum     := add_non_unique_str(Literals, s);
          state      := STOP
        end
      end;

      LITERAL: begin

        bracket := next_ch;
        s := '';
        more_chars := read_char(f, next_ch);     { start the loop }
        while more_chars and
              (next_ch <> NEWLINE_CH) and (next_ch <> bracket)
        do begin

          if next_ch = '\' then begin
            more_chars := read_char(f, next_ch);
            case next_ch of
              't' : next_ch := chr(9);
              'b' : next_ch := chr(8);
              'e' : next_ch := chr(27);
              'n' : begin
                s := s + chr(13);
                next_ch := chr(10)
              end;
            end  { case }
          end;
          s := s + next_ch;

          more_chars := read_char(f, next_ch);

        end;  { while }

        if next_ch <> bracket then begin
          source_pos(f);
          writeln('Unterminated literal');
          halt
        end
        else begin

          case bracket of
            chr(34):
              begin
                f.ttype := TEXT_LIT;
                f.tnum := add_non_unique_str(Literals, s)
              end;
            chr(39):
              begin
                f.ttype := MESSAGE;
                f.tnum := add_unique_str(Vocabulary, s)
              end
            else
              writeln('Programmer error: unknown literal type')
          end;  { case }

          state := STOP

        end  { else }

      end;  { LITERAL }

      IDENTIFIER: begin
        s := '';
        while next_ch in ID_Chars do begin
          s := s + next_ch;
          more_chars := read_char(f, next_ch)
        end;
        if not (next_ch in ID_Chars) then
          unread_char(f, next_ch);
  { Check for reserved words or operators }
        if binary_search(Reserved_Wds, NUM_RWORDS, s, f.tnum) then
          f.ttype := RESERVED
        else if binary_search(Operators, NUM_OPERS, s, f.tnum) then
          f.ttype := OPER
        else begin
          f.ttype := IDENT;
          f.tnum := add_ident(s)
        end;
        state := STOP
      end;

      NUMBER:
        begin
          s := '';
          while more_chars and (next_ch in Digits) do begin
            s := s + next_ch;
            more_chars := read_char(f, next_ch)
          end;
          if not (next_ch in Digits) then
            unread_char(f, next_ch);
          f.ttype := NUMERIC;
          val(s, f.tnum, code);
          state := STOP
        end;

      OPERATOR:
        begin
          s := '';
          while more_chars and
                (next_ch in Long_Opers) and
                (s <> '>>')                 { have to stop short with >> }
          do begin
            s := s + next_ch;
            more_chars := read_char(f, next_ch);
          end;
          if s = '>>' then begin
            unread_char(f, next_ch);
            state := QUOTE
          end
          else begin

            if not (next_ch in Oper_Chars) then
              unread_char(f, next_ch)
            else
              s := s + next_ch;

            state := STOP;

            if s = ':' then begin
              f.ttype := PUNCTUATION;
              f.tnum := ord(':')
            end
            else if not binary_search(Operators, NUM_OPERS,
                                      s, f.tnum) then begin
              source_pos(f);
              writeln('Unknown operator: ', s);
              halt
            end
            else
              f.ttype := OPER

          end     { all cases which are not >> }

        end         { OPERATOR }

  end;  { while - primary state machine loop }

  get_token := more_chars

end;  { get_token }


{ write_token

Description:
  Given a token type and token number, writes out the proper string
  (without terminating the line).

Arguments:
  the_type (IN)   -- the token type
  the_number (IN) -- the token number

Uses:
  The ID_Table

}

procedure write_token(the_type: acl_type; the_number: longint);

  var
    str_ptr: string_ptr;
    the_id_ptr: id_rec_ptr;
    p: pointer;

begin

  case the_type of

    IDENT:
      if the_number < 0 then
        write('an identifier')
      else begin
        write ('<identifier ', the_number, '>: ');
        if index_ident(integer(the_number), the_id_ptr) then
          write ('"', the_id_ptr^.id_name^, '"')
      end;
    RESERVED:
      if the_number < 0 then
        write('a reserved word')
      else
        write('reserved word "', Reserved_Wds[the_number], '"');
    OPER:
      if the_number < 0 then
        write('an operator')
      else
        write('operator "', Operators[the_number], '"');
    PUNCTUATION:
      write(chr(the_number));
    TEXT_LIT:
      if the_number < 0 then
        write('a text literal')
      else if index_xarray(Literals, integer(the_number), p) then begin
        str_ptr := p;
        write('"', str_ptr^, '"')
      end
      else
        write('<text literal ', the_number, '>: ');
    MESSAGE:
      if the_number < 0 then
        write('a message')
      else if index_xarray(Vocabulary, integer(the_number), p) then begin
        str_ptr := p;
        write('''', str_ptr^, '''')
      end
      else
        write('<message ', the_number, '>: ');
    NUMERIC:
      write('the number ', the_number);

    else
      write ('<unknown token>')

  end  { case }

end;  { write_token }



end.  { unit token }
{$V+}
