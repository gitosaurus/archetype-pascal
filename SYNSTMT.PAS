{ SYNSTMT.PAS

Description:
  Contains the code for reading a statement from an .ACH file into
  memory.

}

unit synstmt;

interface

  uses misc, linklist,
       stmt, keywords, token,
       saveload, semantic, synexpr, error;

{ Functions and Procedures }
  function make_acl_statement(var f: progfile): stmt_ptr;


implementation


{ make_case_list

Description:
  Reads a case-pair list from a text .ACH file into memory.  The list
  must be in the form of (<expr>: <statment>)* and may include a
  default: <statement> clause at the end.

Returns:
  A pointer to the list containing case pairs, or nil if it was syntactically
  incorrect.

}

function make_case_list(var f: progfile): list_type;

  var
    done, success : boolean;
    the_node      : node_ptr;
    cases         : list_type;
    the_case_pair : case_pair_ptr;
    default_ptr   : case_pair_ptr;

begin

  done := FALSE;
  default_ptr := nil;
  new_list(cases);
  if not insist_on(f, PUNCTUATION, ord('{')) then begin
    success := FALSE;
    exit
  end;
  repeat
    if not get_token(f) then begin
      hit_eof(f, PUNCTUATION, ord('}'));
      success := FALSE;
    end
    else begin
      new(the_case_pair);
      if (f.ttype = PUNCTUATION) and (chr(f.tnum) = '}') then begin
        dispose(the_case_pair);
        done := TRUE
      end
      else
        with the_case_pair^ do begin
          if (f.ttype = RESERVED) and (f.tnum = RW_DEFAULT) then begin
            if default_ptr <> nil then begin
              error_message(f, 'There is already a default for this case');
              success := FALSE
            end
            else begin
              default_ptr := the_case_pair;
              new(value);
              with value^ do begin
                kind    := RESERVED;
                keyword := RW_DEFAULT
              end
            end
          end
          else begin
            f.consumed := FALSE;
            value := make_acl_expr(f)
          end;
          if success and (value <> nil) and
             insist_on(f, PUNCTUATION, ord(':')) then begin
            action := make_acl_statement(f);
            success := action <> nil
          end
          else
            success := FALSE
        end;  { with the_case_pair^ }

      if success and (not done) and (default_ptr <> the_case_pair) then begin
        new(the_node);
        the_node^.data := the_case_pair;
        append_to_list(cases, the_node)
      end

    end     { if get_token }
  until (not success) or done;

{ Add the default case pair whether there was success or not; it makes
  the subsequent dispose easier. }

  if default_ptr <> nil then begin
    new(the_node);
    the_node^.data := default_ptr;
    append_to_list(cases, the_node)
  end;

  if success then
    make_case_list := cases
  else begin
    dispose_item_list(cases, CASE_LIST);
    make_case_list := nil
  end

end;  { make_case_list }



{ make_acl_statement

Description:
  A very busy procedure.  Ensures semantic correctness of a general
  Archetype statement.

Arguments:
  f (IN/OUT)             -- the input .ACH file

Returns:
  A pointer to the statment; or nil if the statement was not syntactically
  correct.

BNF:
  <statement> ::= <compound> | <single>

  <compound> ::= <left brace> <single>+ <right brace>

  <single> ::= <if_stmt> | <case_stmt> | <any_stmt> |
               <write_stmt> | <send_stmt> | <for_stmt>

}

function make_acl_statement(var f: progfile): stmt_ptr;

  var
    done, success, found_newline: boolean;
    the_stmt, each_stmt: stmt_ptr;
    each_node, the_node: node_ptr;
    the_case_pair: case_pair_ptr;
    the_type_id: classify_type;

begin

  if not get_token(f) then begin
    error_message(f, 'Expected Archetype statement, found end of file');
    KeepLooking := FALSE;
    make_acl_statement := nil;
    exit
  end;

  new(the_stmt);
  success := TRUE;

  if (f.ttype = PUNCTUATION) and (chr(f.tnum) = '{') then begin  { compound }
    done := FALSE;
    the_stmt^.kind := COMPOUND;
    new_list(the_stmt^.statements);
    repeat
      if get_token(f) then
        if (f.ttype = PUNCTUATION) and (chr(f.tnum) = '}') then
          done := TRUE
        else begin
          f.consumed := FALSE;
          each_stmt := make_acl_statement(f);
          if each_stmt = nil then begin                 { unravel }
            dispose_list(the_stmt^.statements);
            error_message(f, 'Unfinished compound statement');
            KeepLooking := FALSE;
            success := FALSE;
            done := TRUE
          end
          else begin
            new(each_node);
            each_node^.data := each_stmt;
            append_to_list(the_stmt^.statements, each_node)
          end
        end
      else
        done := TRUE
    until done
  end                     { compound }
  else                                                       { single }
    if f.ttype <> RESERVED then begin
      f.consumed := FALSE;
      the_stmt^.kind := ST_EXPR;
      the_stmt^.expression := make_acl_expr(f);
      success := the_stmt^.expression <> nil
    end
    else
      case f.tnum of

{ BNF:  <if_stmt> ::= if <expr> then <statement> [else <statement>] }
        RW_IF:
          begin
            with the_stmt^ do begin
              kind := ST_IF;
              condition := make_acl_expr(f);
              if (condition = nil) then
                success := FALSE
              else begin
                else_branch := nil;
                if not insist_on(f, RESERVED, RW_THEN) then
                  success := FALSE
                else begin
                  then_branch := make_acl_statement(f);
                  if then_branch = nil then
                    success := FALSE
                  else if get_token(f) and
                          (f.ttype = RESERVED) and (f.tnum = RW_ELSE) then begin
                    else_branch := make_acl_statement(f);
                    success := else_branch <> nil
                  end
                  else
                    f.consumed := FALSE
                end
              end
            end  { with }
          end;

{ BNF:  <case_stmt> ::= case <expr> of (<expr> <statement>)+
                                 [default <statement>] end }
        RW_CASE:
          with the_stmt^ do begin
            kind := ST_CASE;
            test_expr := make_acl_expr(f);
            success := test_expr <> nil;
            if success then begin
              if not insist_on(f, RESERVED, RW_OF) then
                success := FALSE
              else begin
                cases := make_case_list(f);
                success := cases <> nil
              end
            end
          end;              { RW_CASE }


        RW_CREATE:
          with the_stmt^ do begin
            kind := ST_CREATE;
            if not get_token(f) then begin
              hit_eof(f, IDENT, -1);
              success := FALSE
            end
            else begin
              if (f.ttype = RESERVED) and (f.tnum = RW_NULL) then
                archetype := 0
              else if f.ttype <> IDENT then begin
                expect_general(f, 'type identifier');
                success := FALSE
              end
              else begin
                get_meaning(f.tnum, the_type_id, archetype);
                if the_type_id <> TYPE_ID then begin
                  error_message(f, 'Require name of defined type');
                  success := FALSE
                end
                else if not insist_on(f, RESERVED, RW_NAMED) then
                  success := FALSE
                else begin
                  new_name := make_acl_expr(f);
                  if new_name = nil then success := FALSE
                end
              end  { the type token was indeed an identifier }
            end  { the type token existed }
          end;

        RW_DESTROY:
          with the_stmt^ do begin
            kind := ST_DESTROY;
            victim := make_acl_expr(f);
            if victim = nil then success := FALSE
          end;

{ BNF:  <write_stmt> ::= (write[s] | stop) <expr> (<comma> <expr>)* }
        RW_WRITE, RW_WRITES, RW_STOP:
          begin
            with the_stmt^ do begin
              case f.tnum of
                RW_WRITE:   kind := ST_WRITE;
                RW_WRITES:  kind := ST_WRITES;
                RW_STOP:    kind := ST_STOP
              end;
              new_list(print_list);
              new(the_node)
            end;  { with }
{ If the token immediately following the write statement is NEWLINE, then
  the write was intended to be a null write - that is, no message, only
  the action. }
            f.newlines := TRUE;
            found_newline := get_token(f) and (f.ttype = NEWLINE);
            f.newlines := FALSE;
            if not found_newline then begin
              f.consumed := FALSE;
              the_node^.data := make_acl_expr(f);
              if the_node^.data = nil then
                success := FALSE
              else begin
                append_to_list(the_stmt^.print_list, the_node);
                done := FALSE;
                repeat
                  if get_token(f) then
                    if (f.ttype = PUNCTUATION) and (chr(f.tnum) = ',') then begin
                      new(the_node);
                      the_node^.data := make_acl_expr(f);
                      if the_node^.data = nil then
                        success := FALSE
                      else
                        append_to_list(the_stmt^.print_list, the_node)
                    end
                    else begin
                      f.consumed := FALSE;
                      done := TRUE
                    end
                  else
                    done := TRUE
                until (not success) or done
              end
            end
          end;



{ BNF:  <for_stmt> ::= for <expr> do <statement> }
        RW_FOR, RW_WHILE:
          with the_stmt^ do begin
            if f.tnum = RW_FOR then
              kind := ST_FOR
            else
              kind := ST_WHILE;
            selection := make_acl_expr(f);
            if selection = nil then
              success := FALSE
            else if insist_on(f, RESERVED, RW_DO) then begin
              action := make_acl_statement(f);
              success := action <> nil
            end
            else
              success := FALSE
          end;

{ BNF: <break_stmt> ::= break }
        RW_BREAK:
          the_stmt^.kind := ST_BREAK;

{ Default:  an expression that may begin with a reserved word }
        else
          with the_stmt^ do begin
            kind := ST_EXPR;
            f.consumed := FALSE;
            expression := make_acl_expr(f);
            if expression = nil then
              success := FALSE
          end  { with }

      end;  { case }

  if success then
    make_acl_statement := the_stmt
  else begin
    dispose(the_stmt);
    make_acl_statement := nil
  end

end;  { make_acl_statement }


end.  { unit synstmt }
