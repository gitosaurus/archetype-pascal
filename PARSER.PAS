{ PARSER.PAS

Description:
  Performs parsing at a low level that is independent of the
  rest of Archetype.

}

{$V-}

unit parser;

interface

  uses misc, linklist;

  const
    Word_Chars = ['A'..'Z', 'a'..'z', '0'..'9', '-', chr(39)];

  type
    target_list_type = (PARSER_VERBLIST, PARSER_NOUNLIST);

{ Procedures and functions }
  procedure normalize_string(var first, second: string);
  procedure add_parse_word(which_list : target_list_type;
                           the_word : string; the_object : integer);
  procedure parse_sentence;
  function pop_object(var intback : integer; var strback : string) : boolean;
  function find_object(var s : string) : integer;
  procedure new_parse_list;

{ Global Variables }
  var
    Command    : string;
    Abbreviate : integer;
    Proximate  : list_type;

implementation

  const
    WORD_LEN = 32;

  type

    parse_ptr = ^parse_type;
    parse_type = record
      word   : string_ptr;
      object_ref : integer
    end;

{ Static Variables (to this unit) }
  var
    verb_names, object_names: list_type;

{ locase

Description:
  Puts into lowercase the given character.

}

function locase(ch: char): char;

begin

  if ch in ['A'..'Z'] then
    locase := chr(ord(ch) + 32)
  else
    locase := ch

end;



{ lowercase

Description:
  Puts the given string into lowercase.

}

procedure lowercase(var s: string);

  var i : integer;

begin

  for i := 1 to length(s) do s[i] := locase(s[i])

end;



{ normalize_string

Description:
  Given a string, creates a string with one and only one space between
  each word.

Arguments:
  first (IN)            -- the string to be normalized
  second (OUT)          -- the normalized string

}

procedure normalize_string(var first, second: string);

  var
    i, j, lfirst: integer;
    in_word, done: boolean;

begin

  i := 1; j := 0;
  in_word := FALSE;
  done := FALSE;
  lfirst := length(first);
  second := ' ';

  repeat
    if (i > lfirst) or (not (first[i] in Word_Chars)) then begin
      if in_word then begin
        j := 0;
        in_word := FALSE;
        second := second + ' '
      end
      else
        inc(i);
      if i > lfirst then
        done := TRUE
    end
    else if in_word then begin
      if j < Abbreviate then begin
        second := second + locase(first[i]);
        inc(j)
      end;
      inc(i)
    end
    else
      in_word := TRUE
  until done

end;  { normalize_string }



{ add_parse_word

Description:
  Adds another word to one of the lists to match.  If the given
  word has vertical bars in it, the bars are considered delimiters and each
  delimited word is added to the available list.

}

procedure add_parse_word(which_list : target_list_type;
                         the_word : string; the_object : integer);

  var
    the_list : list_type;
    tempstr  : string;
    np       : node_ptr;
    pp       : parse_ptr;
    bar      : integer;

begin

  if which_list = PARSER_VERBLIST then
    the_list := verb_names
  else
    the_list := object_names;

  the_word := the_word + '|';
  repeat
    bar := Pos('|', the_word);
    if bar <> 0 then begin
      new(pp);
      with pp^ do begin
        tempstr := Copy(Copy(the_word, 1, bar - 1), 1, Abbreviate);
        word := NewConstStr(tempstr);
        lowercase(word^);
        Delete(the_word, 1, bar);
        object_ref := the_object
      end;
      new(np);
      with np^ do begin
        key := length(pp^.word^);
        data := pp
      end;
      insert_item(the_list, np)
    end
  until bar = 0

end;  { add_parse_word }



{ parse_sentence

Description:
  Parses the previously given sentence into a string of object references.
  The verbpreps list is searched first, followed by the nounphrases list.
  It does not identify any parts of speech; it is strictly substitutional.

  Also removes all instances of the words "a", "an", "the".

NOTES:
  When an object is matched, its name is replaced by the sequence
  <percent sign><high byte><low byte><caret>.  The percent will
  indicate the beginning of the encoded number; the caret indicates
  the end and also serves the purpose of keeping the trim() procedure
  from trimming off objects 9 or 13 or the like.

  Objects are matched as words; they must be surrounded by spaces.
  When they are replaced in the Command string, they leave the spaces
  on both sides so as not to interfere with further matching.

}

procedure parse_sentence;


  var next_starting : integer;

  const
    nfillers = 3;
    fillers: array[1..nfillers] of string[8] =
             (' a ', ' an ', ' the ');

  procedure substitute(start : integer; pp : parse_ptr);

    var sublen : integer;

  begin

    sublen := length(pp^.word^);
    if sublen > Abbreviate then sublen := Abbreviate;

    Command := Concat(Copy(Command, 1, start),
                      '%', chr(pp^.object_ref shr 8),
                      chr(pp^.object_ref and $FF), '^',
                      Copy(Command, start + sublen + 1, MAX_STRING));

    next_starting := next_starting - sublen + 4

  end;


  function next_chunk(var start_at : integer;
                      var the_chunk : string) : boolean;

    var i : integer;

  begin

    if next_starting = 0 then
      next_chunk := FALSE
    else begin
      repeat
        start_at := next_starting;
        the_chunk := Copy(Command, start_at, MAX_STRING);
        i := Pos('%', the_chunk);
        if i = 0 then
          next_starting := 0
        else begin
          the_chunk := Copy(the_chunk, 1, i - 1);
          next_starting := next_starting + i + 3
        end;
        trim(the_chunk)
      until (next_starting = 0) or (length(the_chunk) > 0);
      next_chunk := length(the_chunk) > 0
    end

  end;


  var
    s  : string;
    np, near_match, far_match : node_ptr;
    pp : parse_ptr;

    i, lchunk : integer;

begin

{ Rip out those fillers }
  s := Command;
  for i := 1 to nfillers do
    while Pos(fillers[i], Command) > 0 do
      Delete (Command, Pos(fillers[i], Command), length(fillers[i]) - 1);
{ Restore the original string if filler removal destroyed it completely }
  if Command = ' ' then Command := s;

{ Two passes: one matching all verbs and prepositions from the verb list,
              longest strings first. }

  np := nil;
  while iterate_list(verb_names, np) do begin
    pp := parse_ptr(np^.data);
    s := Concat(' ', Copy(pp^.word^, 1, Abbreviate), ' ');
    i := Pos(s, Command);
    if i <> 0 then substitute(i, pp)
  end;  { while }

{ Second pass:  carefully search for the remaining string chunks;
                search only the part of the noun list of the same length;
                give preference to those in the Proximate list. }

  next_starting := 1;
  while next_chunk(i, s) do begin
    lchunk := length(s);
    np := find_item(object_names, lchunk);
    if np <> nil then begin
      near_match := nil; far_match := nil;
      repeat
        pp := parse_ptr(np^.data);
        if Copy(pp^.word^, 1, Abbreviate) = s then
          if find_item(Proximate, pp^.object_ref) <> nil then
            near_match := np
          else
            far_match  := np;
      until not (iterate_list(object_names, np) and
                (lchunk = length(parse_ptr(np^.data)^.word^)));
      if near_match <> nil then
        substitute(i, parse_ptr(near_match^.data))
      else if far_match <> nil then
        substitute(i, parse_ptr(far_match^.data))
    end
  end;

  trim(Command)

end;  { parse_sentence }



{ pop_object

Description:
  Pops the first object number off of the parsed Command string and sends
  the number back.  If Command does not begin with an object marker,
  sends back the unparseable string.

Arguments:
  intback (OUT)             -- will be -1 if there was no object;
                               otherwise, the number of the object.
  strback (OUT)             -- will contain the (trimmed) unparseable
                               chunk if intback is -1; unchanged otherwise.

Returns:
  TRUE if there was anything to be popped; FALSE otherwise.

}

function pop_object(var intback : integer; var strback : string) : boolean;

  var
    i : integer;

begin

  if length(Command) = 0 then
    pop_object := FALSE
  else begin
    if Command[1] = '%' then begin  { parsed object }
      intback := (ord(Command[2]) shl 8) or ord(Command[3]);
      Delete(Command, 1, 4);
    end
    else begin
      intback := -1;
      i := Pos('%', Command) - 1;
      if i < 0 then i := length(Command);
      strback := Copy(Command, 1, i);
      Delete(Command, 1, i);
      trim(strback);
    end;
    trim(Command);
    pop_object := TRUE
  end;

end;  { pop_object }



{ find_object

Description:
  Performs a subset of the normal parse_sentence algorithm.  Given a single
  string, find the number of the first object that matches.

}

function find_object(var s : string) : integer;

  var
    np : node_ptr;

begin

  np := nil;
  while iterate_list(object_names, np) do
    if parse_ptr(np^.data)^.word^ = s then begin
      find_object := parse_ptr(np^.data)^.object_ref;
      exit
    end;

  np := nil;
  while iterate_list(verb_names, np) do
    if parse_ptr(np^.data)^.word^ = s then begin
      find_object := parse_ptr(np^.data)^.object_ref;
      exit
    end;

  find_object := 0

end;



{ new_parse_list

Description:
  Called in order to force a full deletion of the parse lists, in order
  that new ones may be built up.

}

procedure new_parse_list;

  procedure clear_parse_list(var the_list : list_type);

    var
      pp : parse_ptr;
      np : node_ptr;

  begin

    np := nil;
    while iterate_list(the_list, np) do begin
      pp := parse_ptr(np^.data);
      FreeConstStr(pp^.word);
      dispose(pp)
    end;
    dispose_list(the_list);
    new_list(the_list)

  end;

begin

  clear_parse_list(verb_names);
  clear_parse_list(object_names)

end;



{ Initializations }

begin

  Command    := '';
  Abbreviate := MaxInt;
  new_list(Proximate);
  new_list(object_names);
  new_list(verb_names)

end.  { unit parse }

{$V+}
