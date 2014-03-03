{ ARCHSYS.PAS

Description:
  Routines which compose the "system object" of Archetype and the primary
  link between the player and the language.

  Routines which perform the interpretation of the Archetype statements
  and expressions, and which perform the inheritance aspect of message
  sending and attribute referencing.

}

unit archsys;

interface

  uses
    Crt,
    misc,
    linklist, xarray,
    keywords, expr, stmt,
    saveload, intrptr,
    wrap, sysobj;

{ Functions and Procedures }
  procedure eval_expr(the_expr: expr_tree; var result: result_type;
                      var context: context_type; desired: desired_type);
  procedure exec_stmt(the_stmt: stmt_ptr; var result: result_type;
                      var context: context_type);
  procedure interpret(var acx_file: string);

implementation


function eval_condition(the_expr: expr_tree;
                        var context: context_type): boolean; forward;

{ lookup

Description:
  Given an object number, attribute number, and desired_type, returns
  the value of the lookup in the given result.  If the desired_type is
  LVALUE, then it creates a new attribute node in the object's own
  attribute list (if not already existing) and returns a pointer to
  it.  If RVALUE, it evaluates any expression it may find, returning
  the result of the evaluation.

  Also performs inheritance, looking back through the object's family
  tree to find the attribute.

}

procedure lookup(the_obj: integer; the_attr: integer;
                 var result: result_type; var context: context_type;
                 desired: desired_type);

  var
    np: node_ptr;
    done, first_pass: boolean;
    attrs: list_type;
    parent: integer;
    p, original: pointer;
    e: expr_tree;
    c: context_type;

begin

  cleanup(result);

  if desired = NAME then
    with result do begin
      kind := IDENT;
      ident_kind := ATTRIBUTE_ID;
      ident_int := the_attr;
      exit
    end;

  if the_obj = 0 then           { system object - all attributes UNDEFINED }
    exit;

  if not index_xarray(Object_List, the_obj, original) then begin
    writeln('Internal error: cannot reference object ', the_obj);
    exit
  end;

{ Return UNDEFINED for attempting to reference any attribute of a destroyed
  object. }

  if original = nil then exit;

{ It is important to change the context before a lookup so that any
  non-scalar expressions that are referenced will be evaluated in the
  light of that object's context. }

  c := context;
  with c do begin
    self    := the_obj;              { references to self must be right }
    each    := 0
  end;
  first_pass := TRUE;
  p := original;
  done := FALSE;
  repeat                                { inheritance loop }

    with object_ptr(p)^ do begin
      attrs := attributes;
      parent := inherited_from
    end;

    np := find_item(attrs, the_attr);
    if (np <> nil) or (parent = 0) then
      done := TRUE
    else begin                          { track back }
      if not index_xarray(Type_List, parent, p) then begin
        writeln('Internal error:  lookup cannot find parent type ', parent);
        exit
      end;
      first_pass := FALSE
    end;

  until done;

  if np = nil then          { not found anywhere }
    exit;

  case desired of

    RVALUE:
      eval_expr(expr_ptr(np^.data), result, c, RVALUE);

{ Getting an inherited LVALUE is tricky.  We must remember that since
  we have come this far, we definitely will return an ATTR_PTR result. }

    LVALUE:
      if first_pass then
        with result do begin
          kind := ATTR_PTR;
          acl_attr := np
        end
      else begin                      { inherited - must create new node }
        result.kind := ATTR_PTR;
        new(result.acl_attr);
        new(e);
        undefine(e^);
        eval_expr(expr_ptr(np^.data), e^, c, RVALUE);
        with result.acl_attr^ do begin
          data := e;
          key := the_attr
        end;
        insert_item(object_ptr(original)^.attributes, result.acl_attr)
      end;  { LVALUE }

  end  { case }

end;  { lookup }



{ send_message

Description:
  Sends the given message number to the object of the given number.
  This procedure performs inheritance; that is, it will search back
  through the object's ancestry in order to find someone to perform
  the message.  Has to do something tricky with the default message:
  it must first search the entire ancestry for an explicit message,
  then search again for a default, if none found.

Arguments:
  transport (IN)        -- how to send the message:  sending to an object,
                           passing to an object, or sending(passing) to
                           a type.
  message (IN)          -- message to send
  recipient (IN)        -- number of object to receive message
  result (OUT)          -- result of the sending

Returns:
  TRUE if the recipient handles the message; FALSE if it doesn't.

}

function send_message(transport: shortint;
                      message_sent, recipient: integer;
                      var result: result_type;
                      var context: context_type): boolean;

  var
    done, find_other : boolean;
    op, original     : object_ptr;

    r  : result_type;

    i  : integer;
    np : node_ptr;
    st : stmt_ptr;
    p  : pointer;
    c  : context_type;

begin

  if message_sent = 0 then begin
    cleanup(result);
    send_message := FALSE;
    exit
  end;

  if (Debug and DEBUG_MSGS) > 0 then begin
    r.kind := IDENT;
    r.ident_kind := OBJECT_ID;
    r.ident_int := context.self;
    wrapout(' : ', FALSE);
    display_result(r);
    if transport = OP_SEND then
      wrapout(' sending ', FALSE)
    else
      wrapout(' passing ', FALSE);
    if index_xarray(Vocabulary, message_sent, p) then
      wrapout(Concat('''', string_ptr(p)^, ''''), FALSE);
    if transport = OP_SEND_TO_TYPE then
      r.ident_kind := TYPE_ID;
    wrapout(' to ', FALSE);
    r.ident_int := recipient;
    display_result(r);
    wrapout('', TRUE)
  end;

{ Trying to send a message to a destroyed object results in UNDEFINED }

  if (((transport = OP_SEND_TO_TYPE) and
        index_xarray(Type_List, recipient, p)) or
       index_xarray(Object_List, recipient, p)) and (p <> nil)
  then begin
    c := context;
    with c do begin
      each    := 0;
      message := message_sent;
      if transport = OP_SEND then begin
        sender := context.self;
        self   := recipient
      end
    end;
    op := object_ptr(p);
    original := op;
    done := FALSE;
    find_other := FALSE;
    while not done do begin
      if find_other then
        st := op^.other
      else begin
        np := find_item(op^.methods, message_sent);
        if np <> nil then
          st := stmt_ptr(np^.data)
        else
          st := nil
      end;
      if st <> nil then begin           { found it }
        exec_stmt(st, result, c);
        send_message := TRUE;
        exit
      end
      else                              { no message for recipient }
        if op^.inherited_from = 0 then
          if find_other then
            done := TRUE
          else begin
            op := original;
            find_other := TRUE
          end
        else if index_xarray(Type_List, op^.inherited_from, p) then
          op := object_ptr(p)
        else begin
          wraperr('Internal error:  invalid inheritance');
          send_message := FALSE;
          exit
        end
    end       { while }
  end;    { if }

{ If we get here, it means that there was not even a "default" handler for
  the message in the given object or its lineage.  Return ABSENT. }
  result.kind    := RESERVED;
  result.keyword := RW_ABSENT;

  send_message := FALSE

end;  { send_message }



{ eval_expr

Description:
  Evaluates the given expression.

}

procedure eval_expr(the_expr: expr_tree; var result: result_type;
                    var context: context_type; desired: desired_type);

  var
    r1, r2 : result_type;
    i      : integer;

    p : pointer;
    e : expr_tree;
    b : boolean;
    c : context_type;

begin

{ It is very important to make sure that the "kind" fields of our
  temporary result variables are properly set to RESERVED/UNDEFINED
  before doing anything with them, so that if someone tries to clean
  them up later on, they won't try to dispose of a string that isn't
  there. }

  undefine(r1);
  undefine(r2);

  cleanup(result);

  if the_expr = nil then
    exit;

{ Check:  if this is a lone attribute, look it up in this object's table. }

  if (the_expr^.kind = IDENT) and
     (the_expr^.ident_kind = ATTRIBUTE_ID) then
    lookup(context.self, the_expr^.ident_int, result, context, desired)

{ Is it a special reserved word that requires an action? }

  else if the_expr^.kind = RESERVED then
    case the_expr^.keyword of
      RW_READ, RW_KEY:
        with result do begin
          kind := STR_PTR;
          if the_expr^.keyword = RW_READ then
            acl_str := ReadLine(TRUE)           { read full line }
          else
            acl_str := ReadLine(FALSE);         { read single key }
          Rows := 0;
          cursor_reset              { user will have had to hit <RETURN> }
        end;
      RW_MESSAGE:
        with result do begin
          kind   := MESSAGE;
          index  := context.message
        end;
      RW_EACH, RW_SELF, RW_SENDER:
        with result do begin
          kind := IDENT;
          ident_kind := OBJECT_ID;
          case the_expr^.keyword of
            RW_EACH:   ident_int := context.each;
            RW_SELF:   ident_int := context.self;
            RW_SENDER: ident_int := context.sender;
          end
        end;
      else
        result := the_expr^
    end  { case }

{ If an operator, need to evaulate it }

  else if the_expr^.kind = OPER then begin

    case the_expr^.op_name of

      OP_SEND, OP_PASS:
        begin

          eval_expr(the_expr^.left, r1, context, RVALUE);
          eval_expr(the_expr^.right, r2, context, RVALUE);
          if (r2.kind = IDENT) and
             ((r2.ident_kind = OBJECT_ID) or
              (r2.ident_kind = TYPE_ID))
          then begin

   { Object 0 is the system object and always receives string messages }

            if (r2.ident_kind = OBJECT_ID) and
               (r2.ident_int = 0)
            then begin
              if convert_to(STR_PTR, r1) then
                send_to_system(the_expr^.op_name, r1.acl_str^,
                               result, context)
            end
            else if convert_to(MESSAGE, r1) then begin
              if r2.ident_kind = TYPE_ID then
                b := send_message(OP_SEND_TO_TYPE,
                                  r1.index, r2.ident_int,
                                  result, context)
              else
                b := send_message(the_expr^.op_name,
                                  r1.index, r2.ident_int,
                                  result, context)
            end
          end

        end;  { ->, --> }


      OP_DOT: begin

        eval_expr(the_expr^.left, r1, context, RVALUE);
        if (r1.kind = IDENT) and (r1.ident_kind = OBJECT_ID) then begin
          eval_expr(the_expr^.right, r2, context, NAME);
          if (r2.kind = IDENT) and (r2.ident_kind = ATTRIBUTE_ID) then
            lookup(r1.ident_int, r2.ident_int, result, context, desired)
        end

      end;  { . }


      OP_ASSIGN:
        begin

          if desired = NAME then
            exit;

          eval_expr(the_expr^.right, result, context, RVALUE);
          eval_expr(the_expr^.left, r1, context, LVALUE);

          if not assignment(r1, result) then
            cleanup(result)
          else if desired = LVALUE then begin
            cleanup(result);
            with result do begin
              kind := ATTR_PTR;
              acl_attr := r1.acl_attr
            end
          end

        end;  { := }

      OP_C_MULTIPLY, OP_C_DIVIDE, OP_C_PLUS, OP_C_MINUS, OP_C_CONCAT:
        begin

          if desired = NAME then
            exit;

        { Do the two operations using a dummy expression node }
          new(e);
          e^ := the_expr^;
          with e^ do
            case the_expr^.op_name of
              OP_C_MULTIPLY:
                op_name := OP_MULTIPLY;
              OP_C_DIVIDE:
                op_name := OP_DIVIDE;
              OP_C_PLUS:
                op_name := OP_PLUS;
              OP_C_MINUS:
                op_name := OP_MINUS;
              OP_C_CONCAT:
                op_name := OP_CONCAT;
            end; { case }
          eval_expr(e, r1, context, RVALUE);
          with e^ do begin
            op_name := OP_ASSIGN;
            right   := @r1
          end;
          eval_expr(e, result, context, desired);
          dispose(e)

        end;    { *:=, /:=, +:=, -:=, &:= }


      OP_CHS, OP_NUMERIC: begin
        eval_expr(the_expr^.right, result, context, RVALUE);
        if not convert_to(NUMERIC, result) then
          cleanup(result)
        else if the_expr^.op_name = OP_CHS then
          with result do
            acl_int := -acl_int
      end;

      OP_STRING: begin
        eval_expr(the_expr^.right, result, context, RVALUE);
        if not convert_to(STR_PTR, result) then
          cleanup(result)
      end;

      OP_LENGTH: begin
        eval_expr(the_expr^.right, r1, context, RVALUE);
        if convert_to(STR_PTR, r1) then begin
          result.kind    := NUMERIC;
          result.acl_int := length(r1.acl_str^)
        end
      end;

{ For the random operator, we must be careful:  ? "01234" should
  select a random digit out of that set, not attempt to convert it
  to 1234 and take a random number in the range 1 - 1234.
  However, we can neither immediately convert it to string, because
  ? 6 should produce a value in the range 1 - 6, not the character "6". }
      OP_RANDOM: begin
        eval_expr(the_expr^.right, result, context, RVALUE);
        if result.kind = NUMERIC then  { convert x < range to 1 <= x <= range }
          result.acl_int := random(result.acl_int) + 1
        else if convert_to(STR_PTR, result) then
          with result do acl_str^ := acl_str^[random(length(acl_str^)) + 1]
      end;  { ? }


      OP_NOT: begin
        result.kind := RESERVED;
        if eval_condition(the_expr^.right, context) then
          result.keyword := RW_FALSE
        else
          result.keyword := RW_TRUE
      end;
      OP_PLUS, OP_MINUS, OP_MULTIPLY, OP_DIVIDE:
        begin
          eval_expr(the_expr^.left, r1, context, RVALUE);
          eval_expr(the_expr^.right, r2, context, RVALUE);
          if convert_to(NUMERIC, r1) and convert_to(NUMERIC, r2) then begin
            result.kind := NUMERIC;
            case the_expr^.op_name of
              OP_PLUS:
                result.acl_int := r1.acl_int + r2.acl_int;
              OP_MINUS:
                result.acl_int := r1.acl_int - r2.acl_int;
              OP_MULTIPLY:
                result.acl_int := r1.acl_int * r2.acl_int;
              OP_DIVIDE:
                result.acl_int := r1.acl_int div r2.acl_int;
            end
          end     { if both NUMERIC }
        end;    { +, -, *, / , and, or }
      OP_AND: begin
        result.kind := RESERVED;
        if eval_condition(the_expr^.left, context) and
           eval_condition(the_expr^.right, context)
        then
          result.keyword := RW_TRUE
        else
          result.keyword := RW_FALSE
      end;
      OP_OR: begin
        if eval_condition(the_expr^.left, context) or
           eval_condition(the_expr^.right, context)
        then
          result.keyword := RW_TRUE
        else
          result.keyword := RW_FALSE
      end;

      OP_POWER: begin
        eval_expr(the_expr^.right, r2, context, RVALUE);
        eval_expr(the_expr^.left, r1, context, RVALUE);
        if convert_to(NUMERIC, r2) and convert_to(NUMERIC, r1) then begin
          result.kind    := NUMERIC;
          result.acl_int := 1;
          for i := 1 to r2.acl_int do
            result.acl_int := result.acl_int * r1.acl_int
        end
      end;  { ^ }


      OP_CONCAT: begin
        eval_expr(the_expr^.left, r1, context, RVALUE);
        eval_expr(the_expr^.right, r2, context, RVALUE);
        if convert_to(STR_PTR, r1) and convert_to(STR_PTR, r2) then begin
          result.kind := STR_PTR;
          result.acl_str := MakeNewDynStr(r1.acl_str^ + r2.acl_str^)
        end
      end;  { & }
      OP_LEFTFROM, OP_RIGHTFROM: begin
        eval_expr(the_expr^.left,  r1, context, RVALUE);
        eval_expr(the_expr^.right, r2, context, RVALUE);
        if convert_to(STR_PTR, r1) and convert_to(NUMERIC, r2) then begin
          result.kind := STR_PTR;
          if the_expr^.op_name = OP_LEFTFROM then
            result.acl_str :=
              MakeNewDynStr(Copy(r1.acl_str^, 1, r2.acl_int))
          else
            result.acl_str :=
              MakeNewDynStr(Copy(r1.acl_str^, r2.acl_int,
                                 length(r1.acl_str^)))
        end
      end;  { leftfrom, rightfrom }
      OP_WITHIN: begin
        eval_expr(the_expr^.left,  r1, context, RVALUE);
        eval_expr(the_expr^.right, r2, context, RVALUE);
        if convert_to(STR_PTR, r1) and convert_to(STR_PTR, r2) then begin
          result.kind    := NUMERIC;
          result.acl_int := Pos(r1.acl_str^, r2.acl_str^);
          if result.acl_int = 0 then cleanup(result)
        end
      end;

      OP_EQ, OP_NE, OP_LT, OP_GT, OP_LE, OP_GE:
        begin

          eval_expr(the_expr^.left, r1, context, RVALUE);
          eval_expr(the_expr^.right, r2, context, RVALUE);

          result.kind := RESERVED;
          if result_compare(the_expr^.op_name, r1, r2) then
            result.keyword := RW_TRUE
          else
            result.keyword := RW_FALSE

        end;  { =, ~=, <, >, <=, >= }


      else
        writeln('Internal error: "', Operators[the_expr^.op_name],
                '" not yet supported.');

    end;  { case }

    cleanup(r1);
    cleanup(r2);

    if (Debug AND DEBUG_EXPR) > 0 then begin
      wrapout(' -- ', FALSE);
      display_expr(the_expr);
      wrapout('  ==>  ', FALSE);
      display_result(result);
      wrapout('', TRUE)
    end

  end  { else }

  else                                  { some scalar }
    case desired of
      RVALUE:
        copy_result(result, the_expr^);
      LVALUE:
        result := the_expr^;
    end

end;  { eval_expr }



{ eval_condition

Description:
  Evaluates the given expression as though it were a condition.
  Will succeed if the given expression is not UNDEFINED and not FALSE.

Arguments:
  the_expr (IN)             -- expression to evaluate

Returns:
  TRUE if the condition can be considered true; FALSE otherwise.

}

function eval_condition;

  var
    result: result_type;
    failure: boolean;

begin

  undefine(result);
  eval_expr(the_expr, result, context, RVALUE);

  with result do
    failure := (kind = RESERVED) and
                 ((keyword = RW_UNDEFINED) or
                  (keyword = RW_FALSE) or
                  (keyword = RW_ABSENT));

  cleanup(result);
  eval_condition := not failure

end;  { eval_condition }



{ exec_stmt

Description:
  Given a pointer to a statement, executes that statement.
  Very heavily called.

Arguments:
  the_stmt  (IN)        -- pointer to statement to be executed
  result (OUT)          -- the "value" of the execution (for example, the
                            last expression of a compound statement)

}

procedure exec_stmt(the_stmt: stmt_ptr; var result: result_type;
                    var context: context_type);

  var
    np: node_ptr;
    p, q: pointer;
    r1, r2: result_type;
    this_case: case_pair_ptr;
    b: boolean;
    c: context_type;
    i: integer;
    e: expr_ptr;
    the_object: object_ptr;

    verbose : boolean;

begin

  undefine(r1);
  undefine(r2);
  cleanup(result);

  verbose := (Debug AND DEBUG_STMT) > 0;

  if verbose then
    wrapout(' == ', FALSE);

  with the_stmt^ do
    case kind of

      COMPOUND:
        begin
          np := nil;
          b  := FALSE;
          while (not b) and iterate_list(statements, np) do begin
            cleanup(result);
            exec_stmt(stmt_ptr(np^.data), result, context);
            b := (result.kind = RESERVED) and (result.keyword = RW_BREAK)
          end
        end;

      ST_EXPR:
        begin
          if verbose then
            display_expr(expression);
          case expression^.kind of
            QUOTE_LIT:
              if index_xarray(Literals, expression^.index, p) then
                with result do begin
                  kind  := TEXT_LIT;
                  index := expression^.index;
                  wrapout(string_ptr(p)^, TRUE)
                end;
            MESSAGE:
              b := send_message(OP_PASS, expression^.index,
                                context.self, result, context);
            else
              eval_expr(expression, result, context, RVALUE)
          end  { case }

        end;  { ST_EXPR }

      ST_WRITE, ST_WRITES, ST_STOP:
        begin
          if verbose then begin
            case kind of
              ST_WRITE  : wrapout('write ', FALSE);
              ST_WRITES : wrapout('writes ', FALSE);
              ST_STOP   : wrapout('stop ', FALSE);
            end;
            wrapout(' ', FALSE);
            np := nil;
            while iterate_list(print_list, np) do begin
              display_expr(expr_tree(np^.data));
              if np^.next <> print_list then
                wrapout(', ', FALSE)
            end;
            wrapout('', TRUE)
          end;
          np := nil;
          while iterate_list(print_list, np) do begin
            cleanup(result);
            eval_expr(expr_tree(np^.data), result, context, RVALUE);
            write_result(result)
          end;
          if kind = ST_WRITE then
            wrapout('', TRUE)
          else if kind = ST_STOP then begin
            writeln; writeln;
            writeln(VERSION);
            halt
          end
        end;

      ST_IF: begin
        if verbose then begin
          wrapout('if: Testing ', FALSE);
          display_expr(condition)
        end;
        if eval_condition(condition, context) then begin
          if verbose then
            wrapout(' Evaluated TRUE; executing then branch', TRUE);
          exec_stmt(then_branch, result, context)
        end
        else if else_branch <> nil then begin
          if verbose then
            wrapout(' Evaluated FALSE; executing else branch', TRUE);
          exec_stmt(else_branch, result, context)
        end
      end;

      ST_CASE:
        begin
          if verbose then begin
            wrapout('case ', FALSE);
            display_expr(test_expr);
            wrapout(' of', FALSE);
            wrapout('', TRUE)
          end;
          eval_expr(test_expr, r1, context, RVALUE);
          np := nil;
          while iterate_list(cases, np) do begin
            this_case := case_pair_ptr(np^.data);
            with this_case^ do begin
              eval_expr(value, r2, context, RVALUE);
              if ((r2.kind = RESERVED) and (r2.keyword = RW_DEFAULT)) or
                 result_compare(OP_EQ, r1, r2)
              then begin
                exec_stmt(action, result, context);
                cleanup(r1);
                cleanup(r2);
                exit
              end
            end;  { with }
            cleanup(r2)
          end;  { while }
          cleanup(result);
          cleanup(r1)
        end;

      ST_BREAK:
        with result do begin
          kind := RESERVED;
          keyword := RW_BREAK
        end;

      ST_FOR: begin
        b := FALSE;
        c := context;
        c.each := 1;
        while (not b) and (c.each <= Object_List.size) do begin
          if eval_condition(selection, c) then begin
            exec_stmt(action, result, c);
            b := (result.kind = RESERVED) and (result.keyword = RW_BREAK);
            cleanup(result);
          end;
          inc(c.each)
        end
      end;

      ST_WHILE: begin
        b := FALSE;
        while (not b) and eval_condition(selection, context) do begin
          exec_stmt(action, result, context);
          b := (result.kind = RESERVED) and (result.keyword = RW_BREAK);
          cleanup(result)
        end
      end;

      ST_CREATE: begin
        eval_expr(new_name, r1, context, LVALUE);

{ Attempt a dummy assignment just to see if it works }
        result.kind := IDENT;
        result.ident_kind := OBJECT_ID;
        result.ident_int := 0;

        if not assignment(r1, result) then
          cleanup(result)
        else begin                          { do it for real }

          new(the_object);
          the_object^.inherited_from := archetype;
          new_list(the_object^.attributes);
          new_list(the_object^.methods);
          the_object^.other := nil;
          p := the_object;

{ NOTE:  Search the list for an empty slot; if none found, append. }

          i := Dynamic; b := TRUE;
          while access_xarray(Object_List, i, q, PEEK_ACCESS) and
                (q <> nil) do
            inc(i);

          if i > Object_List.size then
            append_to_xarray(Object_List, p)
          else
            b := access_xarray(Object_List, i, p, POKE_ACCESS);

{ Now we know its number; go back and update the result's object reference.
  "Return" this same value. }

          expr_ptr(r1.acl_attr^.data)^.ident_int := i;

          copy_result(result, expr_ptr(r1.acl_attr^.data)^);

          cleanup(r1)

        end

      end;

{ Just dispose of the indicated object in the Object_List.  Shrink the
  list only if the very last object was destroyed. }
      ST_DESTROY:
        begin
          eval_expr(victim, result, context, RVALUE);
          if (result.kind = IDENT) and
             (result.ident_kind = OBJECT_ID) and
             index_xarray(Object_List, result.ident_int, p)
          then begin
            the_object := object_ptr(p);
            dispose_object(the_object);
            p := nil;
            b := access_xarray(Object_List, result.ident_int, p,
                               POKE_ACCESS);
            if result.ident_int = Object_List.size then
              shrink_xarray(Object_List)
          end
          else
            wraperr('Can only destroy previously created objects');
          cleanup(result)
        end;

      else
        wraperr('Internal error:  statement not supported yet')

    end;  { case }

  if verbose then wrapout('', TRUE)   { finish off dangling lines }

end;  { exec_stmt }



{ interpret

Description:
  Loads and interprets the given .ACX file.

Arguments:
  acx_file (IN)         -- name of file

}

procedure interpret(var acx_file: string);

  var
    f_in    : file;
    message : string;
    result  : result_type;
    context : context_type;
    success : boolean;

begin

  assign(f_in, acx_file);
{$I-}
  reset(f_in, 1);
{$I+}
  if IOResult <> 0 then begin
    writeln('Could not open ', acx_file);
    exit
  end;

  writeln('Loading ', acx_file);

  Translating := FALSE;

  success := load_game(f_in);
  close(f_in);
  if not success then
    writeln('Could not PERFORM ', acx_file)
  else begin

    with context do begin
      sender  := 0;
      self    := 0;
      each    := 0;
      message := 0
    end;

    undefine(result);

    Randomize;

    message := 'START';
    if not send_message(OP_SEND, find_message(message),
                        MainObject, result, context)
    then
      wraperr('Cannot execute; no ''START'' message for main object.');

    cleanup(result)

  end;  { else }

  writeln; writeln(VERSION)

end;


end.  { archsys }
