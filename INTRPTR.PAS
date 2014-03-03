{ INTRPTR.PAS

Description:
  Routines which aid in the interpretation of the ACL statements
  and expressions.

}

unit intrptr;

interface

  uses misc, crypt, xarray, keywords, expr, stmt, saveload, wrap, timestmp;

{ Type declarations }
  type

    desired_type = (LVALUE, RVALUE, NAME);

    result_type = expr_node;

    context_type = record
      sender, self, each, message : integer
    end;


{ Global Variables }
  var
    Type_List, Object_List : xarray_type;
    MainObject : integer;
    Dynamic: integer;

{ Functions and Procedures }
  function MakeNewDynStr(s : string) : string_ptr;

  function find_message(var message: string): integer;
  function convert_to(target_type: acl_type;
                      var the_scalar: result_type): boolean;
  procedure undefine(var result: result_type);
  procedure cleanup(var result: result_type);
  procedure copy_result(var r1, r2: result_type);
  function result_compare(comparison: shortint;
                          var r1, r2: result_type): boolean;
  function assignment(var target, value : result_type) : boolean;

  procedure write_result(var result: result_type);
  procedure display_result(var result : result_type);
  procedure display_expr(the_tree : expr_tree);
  function load_game(var f_in: file) : boolean;


implementation


{ MakeNewDynStr

Description:
  A short wrapper to NewDynStr which basically uses the stack as
  temporary string storage.  If you want to use a string constructor
  expression as an argument, call this function, since it does not take
  strings by reference but by value.  Expensive on the stack but only
  briefly; it saves cluttering eval_expr.

}

function MakeNewDynStr(s : string) : string_ptr;

begin

  MakeNewDynStr := NewDynStr(s)

end;



{ find_message

Description:
  Given a string message, returns its number in the Vocabulary list,
  or 0 if it was not found.  At present, it simply uses a very
  inefficient O(N) lookup.  If speed begins to become a consideration,
  this can be changed.

Arguments:
  message (IN)              -- message to find number of

Returns:
  the number of the message in the Vocabulary list.

}

function find_message(var message: string): integer;

  var
    i: integer;
    p: pointer;

begin

  for i := 1 to Vocabulary.size do
    if not index_xarray(Vocabulary, i, p) then
      writeln('Internal error - cannot index element ', i, ' of Vocabulary')
    else if message = string_ptr(p)^ then begin
        find_message := i;
        exit
      end;

  find_message := 0

end;  { find_message }



{ convert_to

Description:
  Converts a scalar expression node to a target type.
  Deals primarily with numeric -> string or string -> numeric
  conversions in their many incarnations.

Arguments:
  target_type (IN)              -- type to convert to
  the_scalar (IN/OUT)           -- scalar to convert

}

function convert_to(target_type: acl_type;
                    var the_scalar: result_type): boolean;

  var
    code: integer;
    dir_from: char;
    the_number: longint;
    s1: string;
    p: pointer;
    boolval : boolean;

begin

  if target_type = the_scalar.kind then begin
    convert_to := TRUE;
    exit
  end;

  case target_type of
    QUOTE_LIT, TEXT_LIT, IDENT, RESERVED:
      begin
        convert_to := FALSE;
        exit
      end
  end;

  case the_scalar.kind of
    NUMERIC:
      begin
        dir_from := 'N';
        the_number := the_scalar.acl_int
      end;
    MESSAGE:
      begin
        dir_from := 'S';
        if index_xarray(Vocabulary, the_scalar.index, p) then
          s1 := string_ptr(p)^
      end;
    TEXT_LIT, QUOTE_LIT:
      begin
        dir_from := 'S';
        if index_xarray(Literals, the_scalar.index, p) then
          s1 := string_ptr(p)^
      end;
    STR_PTR:  { string memory will be disposed ONLY if successful convert }
      begin
        dir_from := 'S';
        s1 := the_scalar.acl_str^
      end;
    IDENT:
      with the_scalar do begin
        dir_from := 'S';
        case ident_kind of
          ENUMERATE_ID : begin
            dir_from := 'N';
            the_number := ident_int
          end;
          OBJECT_ID :
            if ident_int = 0 then
              s1 := 'system'
            else if index_xarray(Object_ID_List, ident_int, p) then begin
              if p = nil then
                s1 := 'null'
              else
                s1 := string_ptr(p)^
            end
            else begin
              convert_to := FALSE;
              exit
            end;
          TYPE_ID :
            if ident_int = 0 then
              s1 := 'null'
            else if index_xarray(Type_ID_List, ident_int, p) then
              s1 := string_ptr(p)^
            else begin
              convert_to := FALSE;
              exit
            end;
          ATTRIBUTE_ID :
            if index_xarray(Attribute_ID_List, ident_int, p) then
              s1 := string_ptr(p)^
            else begin
              convert_to := FALSE;
              exit
            end;
        end         { case ident_kind }
      end;
    RESERVED:
      if (the_scalar.keyword = RW_TRUE) or
         (the_scalar.keyword = RW_FALSE) then begin
        dir_from := 'B';
        boolval  := (the_scalar.keyword = RW_TRUE)
      end
      else begin
        convert_to := FALSE;
        exit
      end;
  end;      { case the_scalar.kind }

{$R-}
  if (target_type = STR_PTR) or (target_type = MESSAGE) then begin
    if the_scalar.kind = STR_PTR then
      FreeDynStr(the_scalar.acl_str);    { we know this will succeed }
    the_scalar.kind := target_type;
    case dir_from of
      'N' :
        str(the_number, s1);
      'B' :
        if boolval then s1 := 'TRUE' else s1 := 'FALSE';
    end;
    if target_type = MESSAGE then
      the_scalar.index   := find_message(s1)
    else
      the_scalar.acl_str := NewDynStr(s1);
    convert_to := TRUE
  end
  else                                  { numeric conversions }
    case dir_from of

      'N' : begin
        the_scalar.kind := NUMERIC;
        the_scalar.acl_int := the_number;
        convert_to := TRUE
      end;

      'B' : begin
        the_scalar.kind := NUMERIC;
        if boolval then
          the_scalar.acl_int := 1
        else
          the_scalar.acl_int := 0
       end;

      'S' : begin
        trim(s1);
        val(s1, the_number, code);
        if code <> 0 then
          convert_to := FALSE
        else begin                        { successful }
          with the_scalar do begin
            if kind = STR_PTR then begin
              FreeDynStr(acl_str)      { memory no longer needed }
            end;
            kind    := NUMERIC;
            acl_int := the_number
          end;
          convert_to := TRUE
        end
      end;     { string -> numeric conversion }

    end;  { case }

end;  { convert_to }



{ undefine

Description:
  Used to initialize previously unused result records.  Does not expect
  that there might be a string pointer lurking within.

}

procedure undefine(var result: result_type);

begin

  with result do begin
    kind := RESERVED;
    keyword := RW_UNDEFINED
  end

end;  { undefine }



{ cleanup

Description:
  To be used on temporary result variables after their usefulness is
  finished.  Like 'undefine' above, except that it is used only for
  results that have actually been used - in other words, results with
  their "kind" field set properly.

}

procedure cleanup(var result: result_type);

begin

  with result do begin
    if kind = STR_PTR then
      FreeDynStr(acl_str);
    kind := RESERVED;
    keyword := RW_UNDEFINED
  end

end;  { cleanup }



{ copy_result

Description:
  Does an rvalue-like copy from r2 to r1.

}

procedure copy_result(var r1, r2: result_type);

begin

  cleanup(r1);
  r1 := r2;
  if r1.kind = STR_PTR then
    r1.acl_str := NewDynStr(r2.acl_str^)

end;  { copy_result }



{ result_compare

Description:
  Compares two result nodes according to the given operator.

Returns:
  TRUE if they can; FALSE if they cannot.

}

function result_compare(comparison: shortint;
                        var r1, r2: result_type): boolean;

  var
    verdict: boolean;

begin

  verdict := FALSE;

{ Try numeric reckoning first, then string reckoning }
  if convert_to(NUMERIC, r1) and
     convert_to(NUMERIC, r2) then
    case comparison of
      OP_EQ,
      OP_NE: verdict :=  r1.acl_int =  r2.acl_int;
      OP_LT: verdict :=  r1.acl_int <  r2.acl_int;
      OP_LE: verdict :=  r1.acl_int <= r2.acl_int;
      OP_GT: verdict :=  r1.acl_int >  r2.acl_int;
      OP_GE: verdict :=  r1.acl_int >= r2.acl_int;
    end

{ No?  Then try string reckoning }
  else if convert_to(STR_PTR, r1) and
          convert_to(STR_PTR, r2) then
    case comparison of
      OP_EQ,
      OP_NE: verdict :=  r1.acl_str^ =  r2.acl_str^;
      OP_LT: verdict :=  r1.acl_str^ <  r2.acl_str^;
      OP_LE: verdict :=  r1.acl_str^ <= r2.acl_str^;
      OP_GT: verdict :=  r1.acl_str^ >  r2.acl_str^;
      OP_GE: verdict :=  r1.acl_str^ >= r2.acl_str^;
    end

  else if r1.kind = r2.kind then begin        { Try other kinds }

    case r1.kind of
      RESERVED:
        case comparison of
          OP_EQ, OP_NE: verdict := r1.keyword =  r2.keyword;
        end;
      IDENT:
        if r1.ident_kind = r2.ident_kind then
          case comparison of
            OP_EQ, OP_NE: verdict := r1.ident_int =  r2.ident_int;
          end
    end  { case }

  end;

  if comparison = OP_NE then
    result_compare := not verdict
  else
    result_compare := verdict

end;  { result_compare }



{ assignment

Description:
  Given the result of an LVALUE evaluation and a result to assign to the
  attribute, performs the assignment if possible.  Returns TRUE if the
  assignment was successful; FALSE otherwise.

Arguments:
  target (IN/OUT)       -- hopefully points to attribute to receive
                           assignment
  value (IN)            -- result to assign

}

function assignment(var target, value : result_type) : boolean;

  var
    e : expr_ptr;

begin

  if target.kind <> ATTR_PTR then begin
    wraperr('Warning: attempted assignment to a non-attribute');
    assignment := FALSE
  end
  else begin

    e := expr_ptr(target.acl_attr^.data);

{ If the current expression starts with an operator, we know it isn't a
  flat result and must therefore be disposed of before proceeding.  Otherwise
  simply clean up the previous expression node. }

    if e^.kind <> OPER then
      cleanup(e^)
    else begin
      dispose_expr(e);
      new(e);
      undefine(e^)
    end;

    copy_result(e^, value);
    target.acl_attr^.data := e;

    assignment := TRUE

  end  { else }

end;  { assignment }



{ write_result

Description:
  Writes the given result to screen w/o terminating it with a newline.

}

procedure write_result(var result: result_type);

  var
    r1 : result_type;

begin

  undefine(r1);
  if result.kind = STR_PTR then
    wrapout(result.acl_str^, FALSE)
  else if result.kind = RESERVED then
    wrapout(Reserved_Wds[result.keyword], FALSE)
  else begin
    if result.kind = ATTR_PTR then
      copy_result(r1, result_type(result.acl_attr^.data^))
    else
      copy_result(r1, result);
    if convert_to(STR_PTR, r1) then
      wrapout(r1.acl_str^, FALSE);
    cleanup(r1)
  end

end;  { write_result }



{ display_result

Description:
  For purposes of debugging.
  Strings are enclosed in double quotes.
  Messages are enclosed in single quotes.
  Quote literals are preceded by >>.

}


procedure display_result(var result : result_type);

  var
    enclose : char;

begin

  case result.kind of
    STR_PTR, TEXT_LIT :
      enclose := '"';
    QUOTE_LIT : begin
      enclose := ' ';
      wrapout('>>', FALSE)
    end;
    MESSAGE :
      enclose := '''';
    else
      enclose := ' ';
  end;

  if enclose <> ' ' then wrapout(enclose, FALSE);
  write_result(result);
  if enclose <> ' ' then wrapout(enclose, FALSE)

end;


{ display_expr

Description:
  Given an expression tree, displays the thing on screen.

}

procedure display_expr(the_tree : expr_tree);

begin

  if the_tree^.kind <> OPER then
     display_result(the_tree^)
  else begin
    if Binary[the_tree^.op_name] then begin
      wrapout(' (', FALSE);
      display_expr(the_tree^.left);
      wrapout(') ', FALSE)
    end;
    wrapout(Operators[the_tree^.op_name], FALSE);
    wrapout(' (', FALSE);
    display_expr(the_tree^.right);
    wrapout(') ', FALSE)
  end

end;  { display_expr }



{ display_stmt

Given a statement, display its contents to the screen.

}

procedure display_stmt(var the_stmt : stmt_type);

begin

  with the_stmt do
    case kind of
      ST_EXPR :
        display_expr(expression);
      ST_IF : begin
        wrapout('Testing: if ', FALSE);
        display_expr(condition)
      end;
      ST_CASE : begin
        wrapout('case ', FALSE);
        display_expr(test_expr)
      end;
      ST_CREATE : begin
        wrapout('create ', FALSE);
        { ... need type reference ... }
        wrapout(' named ', FALSE);
        display_expr(new_name)
      end;
      ST_DESTROY : begin
        wrapout('destroy ', FALSE);
        display_expr(victim)
      end;
      ST_FOR, ST_WHILE :
        ;
      ST_WRITE, ST_WRITES, ST_STOP:
        ;
    end

end;



{ load_game

Description:
  Loads a game into memory from a binary input file.  Checks for errors
  in the header or incompatible versions.

Arguments:
  f_in (IN/OUT)         -- input file

}

function load_game(var f_in: file) : boolean;

  var
    i  : integer;
    ch : char;

    fileversion : real;

begin

{ First, check the initial version string against that in the misc unit. }

  for i := 1 to length(VERSION_STUB) do begin
    BlockRead(f_in, ch, SizeOf(ch));
    if ch <> VERSION_STUB[i] then begin
      writeln('This file is not an Archetype file.');
      load_game := FALSE;
      exit
    end
  end;

{ Bleed off string version information }
  while ch <> chr(26) do
    BlockRead(f_in, ch, SizeOf(ch));

{ Check encoded version }
  BlockRead(f_in, fileversion, SizeOf(fileversion));
  if fileversion > VERSION_NUM then begin
    writeln('This version of PERFORM is ', VERSION_NUM : 3 : 1,
            '; file version is ', fileversion : 3 : 1, ' .');
    writeln('Cannot PERFORM this file.');
    load_game := FALSE;
    exit
  end;

{ Get encryption information }

  BlockRead(f_in, Encryption, SizeOf(Encryption));

{ Read the timestamp.  It is used to verify saved game states,
  and also to prime the encryption. }

  BlockRead(f_in, GTimeStamp, SizeOf(GTimeStamp));

{ Initialize the encrypter.  This is done by using the global time stamp
  as a starting point and using the Encryption variable to decide the
  method.  Be careful here; the PURPLE or Dynamic encryption works
  differently in that we have to set Encryption to UNPURPLE (since we're
  decoding) and then back to PURPLE again in case they save any game
  states.  See load_game_state in the GAMESTAT unit for similar machinations. }
  if Encryption = PURPLE then Encryption := UNPURPLE;
  cryptinit(Encryption, GTimeStamp);

{ Where's the main object? }
  BlockRead(f_in, MainObject, SizeOf(MainObject));

  load_obj_list(f_in, Object_List);

{ Objects may be dynamically allocated beneath this limit.  It is okay
  to set that limit at this time since this routine is only invoked when
  initially loading a game. }
  Dynamic := Object_List.size + 1;

  load_obj_list(f_in, Type_List);

  load_text_list(f_in, Literals);
  load_text_list(f_in, Vocabulary);

  if Encryption = DEBUGGING_ON then begin
    writeln('Loading debugging information');
    load_id_info(f_in)
  end;

  if Encryption = UNPURPLE then Encryption := PURPLE;
  load_game := TRUE

end;  { load_game }


begin

  Dynamic := 1;
  MainObject := 1

end.  { unit intrptr }
