{ MISC.PAS

  Author:
    Derek T. Jones

  Description:
    This unit contains miscellaneous globals, procedures, and types
    which are unified only in the sense that most units need them.

}

unit misc;

interface

  uses crypt;

  const
    MAX_STRING  = 255;
    NULL_CH     = chr(0);
    NEWLINE_CH  = chr(13);

    DEBUG_BYTES = $0001;
    DEBUG_MSGS  = $0002;
    DEBUG_EXPR  = $0004;
    DEBUG_STMT  = $0008;

  type

    acl_type = (RESERVED, IDENT, MESSAGE, OPER,
                TEXT_LIT, QUOTE_LIT, NUMERIC, PUNCTUATION,
                STR_PTR, ATTR_PTR, BAD_TOKEN, NEWLINE);

{ Source program file/accounting structure.  With such a file, it is
  important to keep not only the file pointer, but also fields to keep
  track of position in the source file and the compiler state, or the
  context of the tokenizer. }

    progfile = record

      ptr         : text;       { the physical file }

      filename    : string[80];  { to do with error tracking }
      line_buffer : string;
      file_line   : integer;
      line_pos    : integer;

      newlines    : boolean;       { having to do with the tokenizer context }
      last_ch     : char;
      consumed    : boolean;
      ttype       : acl_type;
      tnum        : longint;

    end;   { progfile structure }

    string_ptr = ^string;

    classify_type = (TYPE_ID, OBJECT_ID,
                     ATTRIBUTE_ID, ENUMERATE_ID, UNDEFINED_ID);
  var

    VERSION, VERSION_STUB : string;
    VERSION_NUM : real;

    Bytes      : longint;             { bytes consumed by allocated memory }
    Debug      : integer;

    KeepLooking : boolean;
    AllErrors   : boolean;


  procedure add_bytes(delta: integer);

  function DOSname(name, ext: string; replace : boolean): string;
  function open_progfile(var filerec: progfile; var name: string): boolean;
  procedure close_progfile(var filerec: progfile);

  function read_char(var f_in: progfile; var ch: char): boolean;
  procedure unread_char(var f_in: progfile; ch: char);

  procedure source_pos(var f_in: progfile);
  procedure trim(var the_str: string);

  procedure load_string(var f_in: file; var the_string: string);
  procedure dump_string(var f_out: file; var the_string: string);

  function NewConstStr(var s : string) : string_ptr;
  procedure FreeConstStr(sp : string_ptr);
  function NewDynStr(var s : string) : string_ptr;
  procedure FreeDynStr(sp : string_ptr);

implementation

var

  Prior: pointer;                               { previous heap state }
  NextExit: pointer;


{ add_bytes

Description:
  Provides a method of keeping track of the size, in allocation,
  of the used part of the heap.

Arguments:
  delta (IN)            -- if positive, the number allocated;
                           if negative, the number deallocated.

}

procedure add_bytes(delta: integer);

begin

  Inc(Bytes, delta);
  if (Debug and DEBUG_BYTES) <> 0 then begin
    if delta >= 0 then
      write('Allocated   ')
    else
      write('Deallocated ');
    writeln(abs(delta): 3, ' bytes.  Current consumed memory: ', Bytes: 6)
  end;

end;  { add_bytes }



{ DOSname

Description:
  Given a name and extension, tacks on the given extension if none given.
  of <name> are ".<ext>", or else tacks those four characters on.  Also
  keeps <name> to eight characters and its extension to three.

  Also is forgiving about directory syntax:  foward slashes, UNIX-style,
  are translated into DOS backslashes.

Returns:
  An uppercased DOS filename.

}

function DOSname(name, ext: string; replace : boolean): string;

  const
    FNAME_LEN = 8;
    EXT_LEN   = 3;

  var
    s : string;
    i : integer;

    bslash, period, namelen : integer;

    noext : boolean;

begin

  bslash := 0; period := 0;
  for i := length(name) downto 1 do
    case (name[i]) of
      '.'           : if period = 0 then period := i;
      '\', '/', ':' : if bslash = 0 then bslash := i;
    end;
  if period = 0 then begin
    period := length(name) + 1;
    noext  := TRUE
  end
  else
    noext  := FALSE;

  namelen := period - bslash - 1;
  if namelen > FNAME_LEN then namelen := FNAME_LEN;

  if replace or noext then
    s := Concat(Copy(name, 1, bslash),
                Copy(name, bslash + 1, namelen), '.',
                Copy(ext, 1, EXT_LEN))
  else
    s := Concat(Copy(name, 1, bslash),
                Copy(name, bslash + 1, namelen),
                Copy(name, period, EXT_LEN + 1));

  for i := 1 to length(s) do begin
    s[i] := upcase(s[i]);
    if (s[i] = '/') then s[i] := '\'
  end;
  DOSname := s

end;  { DOSname }



{ open_progfile

Description:
  Opens an Archetype program source file.

Arguments:
  filerec (OUT)         -- progfile structure
  name (IN)             -- name of the file

Returns:
  TRUE if the file was found and opened; FALSE otherwise.

}

function open_progfile(var filerec: progfile; var name: string): boolean;

begin

  with filerec do begin

    filename := name;
    assign(ptr, filename);
{$I-}
    reset(ptr);
{$I+}
    if IOResult <> 0 then begin
      open_progfile := FALSE;
      exit
    end;

{ Successful open - proceed with field initialization }
    file_line   := 0;
    line_buffer := '';
    line_pos    := 0;
    newlines    := FALSE;
    consumed    := TRUE;
    last_ch     := NULL_CH

  end;  { with }

  open_progfile := TRUE

end;



{ close_progfile

Description:
  Closes an Archetype program source code file.

Arguments:
  filerec (IN/OUT)            -- file to close

}

procedure close_progfile(var filerec: progfile);

begin

  close(filerec.ptr)

end;



{ read_char

Description:
  Reads a single character from the given progfile, performing
  all appropriate housekeeping.

  It appends an internal newline to the end of every line taken
  from the file; it is up to the tokenizer as to whether to consider
  it white space or a token.

Arguments:
  f_in (IN/OUT) -- the input source file
  ch   (OUT)    -- the next character

Returns:
  TRUE  if the character was safely read from the file;
  FALSE if the file pointer was at the end of the file.

}

function read_char(var f_in: progfile; var ch: char): boolean;

begin

  with f_in do begin
    if last_ch <> NULL_CH then begin
      ch := last_ch;
      last_ch := NULL_CH
    end
    else begin
      inc(line_pos);
      while line_pos > length(line_buffer) do begin
        if eof(ptr) then begin
          ch := NULL_CH;
          read_char := FALSE;
          exit
        end;
        readln(ptr, line_buffer);
        line_buffer := line_buffer + NEWLINE_CH;
        inc(file_line);
        line_pos := 1
      end;
      ch := line_buffer[line_pos];
      read_char := TRUE
    end
  end

end;  { read_char }



{ unread_char

Description:
  Has the effect of putting a character back on the data stream.
  Closely cooperates with read_char above.

Arguments:
  f_in (IN/OUT)             -- the input program file
  ch (IN)                   -- character to un-read

}

procedure unread_char(var f_in: progfile; ch: char);

begin

  f_in.last_ch := ch

end;



{ source_pos

Description:
  Writes out the current position in the source file nicely for
  error messages and so forth.  It will, however, only write this out
  once per execution of the program.  This is to prevent messages
  scrolling uncontrollably off the screen.

}

procedure source_pos(var f_in: progfile);

  var i: integer;

begin

{ With the /A switch specified, multiple source_pos messages can be called,
  so long as there is no fatal syntax error.  Otherwise, the first error
  of any kind, regardless of severity, is the only error printed.  This is
  done as a courtesy to those of us without scrolling DOS windows. }

  if KeepLooking then begin
    if not AllErrors then KeepLooking := FALSE;
    with f_in do begin
      writeln('Error in ', filename, ' at line ', file_line);
      writeln(line_buffer);
      for i := 1 to line_pos - 1 do
        write(' ');
      writeln('^')
    end
  end

end;  { source_pos }



{ trim

Description:
  Trims spaces (and tabs and newlines) off the ends of a given string.

Arguments:
  the_str (IN/OUT)          -- string to be trimmed

}

procedure trim(var the_str: string);

  const
    whitespace = [chr(9)..chr(13), ' '];

  var
    i, j:  integer;

begin

  i := 1;
  j := length(the_str);
  while (i <= j) and (the_str[i] in whitespace) do
    inc(i);
  if i > j then
    the_str := ''
  else begin
    while the_str[j] in whitespace do
      dec(j);
    the_str := copy(the_str, i, (j - i) + 1)
  end

end;  { trim }



{ load_string

Description:
  Given an untyped file variable and a string variable, reads
  from the file first the length of the string and then the
  string itself.

  NOTES:  Unlike dump_string, we do not have to worry about preserving
  the original string in case of encryption since it is an OUT parameter.

Arguments:
  f_in (IN/OUT)          -- file variable
  the_string (OUT)       -- string to be read

}

procedure load_string(var f_in: file; var the_string: string);

  var strsize: byte;

begin

  BlockRead(f_in, strsize, SizeOf(strsize));
  BlockRead(f_in, the_string, strsize + 1);
  cryptstr(the_string)

end;



{ dump_string

Description:
  Given an untyped file variable and a string variable, writes
  to the file first the length of the string and then the
  string itself.

Arguments:
  f_out (IN/OUT)        -- file variable
  the_string (IN)       -- string to be written

}

procedure dump_string(var f_out: file; var the_string: string);

  var
    strsize: byte;
    crypted: string;

begin

  strsize := length(the_string);
  if Encryption = NONE then begin
    BlockWrite(f_out, strsize, SizeOf(strsize));
    BlockWrite(f_out, the_string, strsize + 1)
  end

{ If there is any kind of encryption, we do not wish to mangle the string
  that was so trustingly given to us; we must copy it into a mangleable
  string and write that out. }
  else begin
    crypted := the_string;
    cryptstr(crypted);
    BlockWrite(f_out, strsize, SizeOf(strsize));
    BlockWrite(f_out, crypted, strsize + 1)
  end

end;



{ ========================== Constant Strings ===================== }
{ Used for allocating string space that is not expected to be disposed of
  until the end of the program and is never expected to change.
  Only the very minimum space necessary to store the string is used;
  thereby using minimal space and incurring no fragmentation. }


function NewConstStr(var s : string) : string_ptr;

  var
    p  : pointer;

begin

  GetMem(p, length(s) + 1);
  string_ptr(p)^ := s;
  NewConstStr := p

end;



procedure FreeConstStr(sp : string_ptr);

begin

  FreeMem(pointer(sp), length(sp^) + 1)

end;



{ ============================= Dynamic Strings =========================== }
{ These are allocation/free procedures for strings where we need speed
  and yet we need to allocate only the string space necessary.  Memory is
  rounded up to the next paragraph (16 bytes) in order to reduce
  the possiblity of heap fragmentation.  The formula for quickly
  computing the size is (Size + 15) and $FFF0, seen below usually as
  (Size + 16) and $FFF0 because of the extra byte necessary for string
  length. }

function NewDynStr(var s : string) : string_ptr;

  var p : pointer;

begin

  GetMem(p, (length(s) + 16) and $FFF0);
  string_ptr(p)^ := s;
  NewDynStr := p

end;



procedure FreeDynStr(sp : string_ptr);

begin

  FreeMem(pointer(sp), (length(sp^) + 16) and $FFF0)

end;



{ HeapFunc

Description:
  Called when you run out of memory.

}

{$F+} function HeapFunc(Size: word): integer; {$F-}

begin

  writeln;
  writeln('*** OUT OF MEMORY ***');
  writeln('Attempt to allocate block of ', Size, ' bytes');
  writeln('Maximum heap request is only ', MaxAvail, ' bytes');
  writeln('Total free memory is ', MemAvail, ' bytes');

  HeapFunc := 1             { return nil to GetMem or New }

end;



{ exit_prog

Description:
  Used by both CREATE and PERFORM, this is called upon any normal or
  abnormal termination, and ensures that there will be no stray pointers
  hanging around.

}

{$F+}
procedure exit_prog;
{$F-}

begin

  Release(Prior);
  ExitProc := NextExit

end;  { exit_prog }


{ Initialization }

begin

  NextExit := ExitProc;
  ExitProc := @exit_prog;

  HeapError := @HeapFunc;

  VERSION_STUB := 'Archetype version ';
  VERSION      := Concat(VERSION_STUB, '1.02');
  VERSION_NUM  := 1.02;

  Bytes := 0;
  Debug := 0;

  KeepLooking := TRUE;
  AllErrors   := FALSE;

  Mark(Prior)

end.
