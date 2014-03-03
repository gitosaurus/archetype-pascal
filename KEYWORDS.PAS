{ KEYWORDS.PAS

Description:
  A type definition unit which contains all the reserved words, operators,
  and associated types.

}

unit keywords;

interface

  uses misc, xarray;

{ Constants }
  const
    SHORT_STR_LEN = 9;          { max length of any reserved word or operator }

    NUM_RWORDS   = 35;
    NUM_OPERS    = 32;
    MAX_ELEMENTS = 35;          { max(NUM_RWORDS, NUM_OPERS) }

  { The following serve more like C #define statements than Pascal constants;
    they are defined as constants and not enumerated types so that they can
    be referenced by either integer or identifier, whichever happens to be
    more convenient.  In addition, this way the numbers can be optimized
    later for a more efficient lookup if necessary. }

{ Reserved word indices }
    RW_ABSENT      = 1;
    RW_FALSE       = 2;
    RW_TRUE        = 3;
    RW_UNDEFINED   = 4;
    RW_BASED       = 5;
    RW_BREAK       = 6;
    RW_CASE        = 7;
    RW_CLASS       = 8;
    RW_CREATE      = 9;
    RW_DEFAULT     = 10;
    RW_DESTROY     = 11;
    RW_DO          = 12;
    RW_EACH        = 13;
    RW_ELSE        = 14;
    RW_END         = 15;
    RW_FOR         = 16;
    RW_IF          = 17;
    RW_INCLUDE     = 18;
    RW_KEY         = 19;
    RW_KEYWORD     = 20;
    RW_MESSAGE     = 21;
    RW_METHODS     = 22;
    RW_NAMED       = 23;
    RW_NULL        = 24;
    RW_OF          = 25;
    RW_ON          = 26;
    RW_READ        = 27;
    RW_SELF        = 28;
    RW_SENDER      = 29;
    RW_STOP        = 30;
    RW_THEN        = 31;
    RW_TYPE        = 32;
    RW_WHILE       = 33;
    RW_WRITE       = 34;
    RW_WRITES      = 35;

{ Operator indices }
    OP_CONCAT      = 1;
    OP_C_CONCAT    = 2;
    OP_MULTIPLY    = 3;
    OP_C_MULTIPLY  = 4;
    OP_PLUS        = 5;
    OP_C_PLUS      = 6;
    OP_MINUS       = 7;
    OP_PASS        = 8;
    OP_C_MINUS     = 9;
    OP_SEND        = 10;
    OP_DOT         = 11;
    OP_DIVIDE      = 12;
    OP_C_DIVIDE    = 13;
    OP_ASSIGN      = 14;
    OP_LT          = 15;
    OP_LE          = 16;
    OP_EQ          = 17;
    OP_GT          = 18;
    OP_GE          = 19;
    OP_RANDOM      = 20;
    OP_POWER       = 21;
    OP_AND         = 22;
    OP_CHS         = 23;
    OP_LEFTFROM    = 24;
    OP_LENGTH      = 25;
    OP_NOT         = 26;
    OP_NUMERIC     = 27;
    OP_OR          = 28;
    OP_RIGHTFROM   = 29;
    OP_STRING      = 30;
    OP_WITHIN      = 31;
    OP_NE          = 32;

{ Type declarations }
  type
    short_str_type = string[SHORT_STR_LEN];
    lookup_type = array[1..MAX_ELEMENTS] of short_str_type;

{ Global Variables }
  var
    Reserved_Wds, Operators : lookup_type;
    Literals, Vocabulary : xarray_type;
    Type_ID_List, Object_ID_List, Attribute_ID_List : xarray_type;

{ Functions and Procedures }
  procedure load_text_list(var f_in: file; var the_list: xarray_type);
  procedure dump_text_list(var f_out: file; var the_list: xarray_type);
  procedure dispose_text_list(var the_list: xarray_type);
  procedure load_id_info(var bfile : file);
  procedure dump_id_info(var bfile : file);

implementation


{ load_text_list

Description:
  Loads an xarray of test literals into memory from the given file.

Arguments:
  f_in  (IN/OUT)            -- file to read from
  the_list (IN)             -- xarray containing pointers to string constants
}

procedure load_text_list(var f_in: file; var the_list: xarray_type);

  var
    i, n: integer;
    s: string;

begin

  new_xarray(the_list);
  BlockRead(f_in, n, SizeOf(n));
  for i := 1 to n do begin
    load_string(f_in, s);
    append_to_xarray(the_list, NewConstStr(s))
  end

end;  { load_text_list }



{ dump_text_list

Description:
  Dumps the given xarray of text literals to the given file.

Arguments:
  f_out (IN/OUT)            -- file to write to
  the_list (IN)             -- xarray containing pointers to string constants
}

procedure dump_text_list(var f_out: file; var the_list: xarray_type);

  var
    i: integer;
    p: pointer;

begin

  BlockWrite(f_out, the_list.size, SizeOf(the_list.size));
  for i := 1 to the_list.size do
    if index_xarray(the_list, i, p) then
      dump_string(f_out, string_ptr(p)^);

end;  { dump_text_list }



{ dispose_text_list

Description:
  Disposes with all memory associated with the given xarray of text
  literals.

Arguments:
  the_list (IN)             -- xarray containing pointers to string constants
}

procedure dispose_text_list(var the_list: xarray_type);

  var
    i: integer;
    p: pointer;

begin

  for i := 1 to the_list.size do
    if index_xarray(the_list, i, p) then
      FreeConstStr(string_ptr(p));
  dispose_xarray(the_list)

end;  { dispose_text_list }


{ load_id_info

Description:
  Loads all ID information from the given binary file.

}

procedure load_id_info(var bfile: file);

begin

  load_text_list(bfile, Type_ID_List);
  load_text_list(bfile, Object_ID_List);
  load_text_list(bfile, Attribute_ID_List)

end;


{ dump_id_info

Description:
  Dumps all ID information to the given binary file.

}

procedure dump_id_info(var bfile : file);

begin

  dump_text_list(bfile, Type_ID_List);
  dump_text_list(bfile, Object_ID_List);
  dump_text_list(bfile, Attribute_ID_List)

end;



{ Initializations }

begin

  Reserved_Wds[RW_ABSENT]     := 'ABSENT';
  Reserved_Wds[RW_FALSE]      := 'FALSE';
  Reserved_Wds[RW_TRUE]       := 'TRUE';
  Reserved_Wds[RW_UNDEFINED]  := 'UNDEFINED';
  Reserved_Wds[RW_BASED]      := 'based';
  Reserved_Wds[RW_BREAK]      := 'break';
  Reserved_Wds[RW_CASE]       := 'case';
  Reserved_Wds[RW_CLASS]      := 'class';
  Reserved_Wds[RW_CREATE]     := 'create';
  Reserved_Wds[RW_DEFAULT]    := 'default';
  Reserved_Wds[RW_DESTROY]    := 'destroy';
  Reserved_Wds[RW_DO]         := 'do';
  Reserved_Wds[RW_EACH]       := 'each';
  Reserved_Wds[RW_ELSE]       := 'else';
  Reserved_Wds[RW_END]        := 'end';
  Reserved_Wds[RW_FOR]        := 'for';
  Reserved_Wds[RW_IF]         := 'if';
  Reserved_Wds[RW_INCLUDE]    := 'include';
  Reserved_Wds[RW_KEY]        := 'key';
  Reserved_Wds[RW_KEYWORD]    := 'keyword';
  Reserved_Wds[RW_MESSAGE]    := 'message';
  Reserved_Wds[RW_METHODS]    := 'methods';
  Reserved_Wds[RW_NAMED]      := 'named';
  Reserved_Wds[RW_NULL]       := 'null';
  Reserved_Wds[RW_OF]         := 'of';
  Reserved_Wds[RW_ON]         := 'on';
  Reserved_Wds[RW_READ]       := 'read';
  Reserved_Wds[RW_SELF]       := 'self';
  Reserved_Wds[RW_SENDER]     := 'sender';
  Reserved_Wds[RW_STOP]       := 'stop';
  Reserved_Wds[RW_THEN]       := 'then';
  Reserved_Wds[RW_TYPE]       := 'type';
  Reserved_Wds[RW_WHILE]      := 'while';
  Reserved_Wds[RW_WRITE]      := 'write';
  Reserved_Wds[RW_WRITES]     := 'writes';

  Operators[OP_CONCAT]     := '&';
  Operators[OP_C_CONCAT]   := '&:=';
  Operators[OP_MULTIPLY]   := '*';
  Operators[OP_C_MULTIPLY] := '*:=';
  Operators[OP_PLUS]       := '+';
  Operators[OP_C_PLUS]     := '+:=';
  Operators[OP_MINUS]      := '-';
  Operators[OP_PASS]       := '-->';
  Operators[OP_C_MINUS]    := '-:=';
  Operators[OP_SEND]       := '->';
  Operators[OP_DOT]        := '.';
  Operators[OP_DIVIDE]     := '/';
  Operators[OP_C_DIVIDE]   := '/:=';
  Operators[OP_ASSIGN]     := ':=';
  Operators[OP_LT]         := '<';
  Operators[OP_LE]         := '<=';
  Operators[OP_EQ]         := '=';
  Operators[OP_GT]         := '>';
  Operators[OP_GE]         := '>=';
  Operators[OP_RANDOM]     := '?';
  Operators[OP_POWER]      := '^';
  Operators[OP_AND]        := 'and';
  Operators[OP_CHS]        := 'chs';
  Operators[OP_LEFTFROM]   := 'leftfrom';
  Operators[OP_LENGTH]     := 'length';
  Operators[OP_NOT]        := 'not';
  Operators[OP_NUMERIC]    := 'numeric';
  Operators[OP_OR]         := 'or';
  Operators[OP_RIGHTFROM]  := 'rightfrom';
  Operators[OP_STRING]     := 'string';
  Operators[OP_WITHIN]     := 'within';
  Operators[OP_NE]         := '~=';

  new_xarray(Literals);
  new_xarray(Vocabulary);

  new_xarray(Type_ID_List);
  new_xarray(Object_ID_List);
  new_xarray(Attribute_ID_List)

end.
