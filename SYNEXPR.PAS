{ SYNEXPR.PAS

Description:
  Contains the routines necessary to check the syntactic correctness
  of infix expressions and read them into prefix trees in memory.

}

unit synexpr;

interface

  uses misc, id_table, keywords, token, expr, semantic, error, saveload;

{ Functions and Procedures }
  function make_acl_expr(var f: progfile): expr_tree;

implementation

  function form_acl_expr(var f: progfile;
                         stop_precedence: integer): expr_tree; forward;


{ get_operand

Description:
  Gets the next operand from the file.  This is where unary operators
  are handled:  if the next token is an operator, then it is considered a
  unary expression.

Arguments:
  the_operand (OUT)     -- where the new operand is placed

Returns:
  TRUE if the next operand was available; FALSE if no new operand.

}

function get_operand(var f: progfile; var the_operand: expr_ptr): boolean;

  var
    success : boolean;
    more    : boolean;
    scalar  : expr_ptr;

begin

  success := TRUE;
  new(the_operand);
  scalar := nil;
  with the_operand^ do begin
    kind := OPER;
    op_name := OP_LPAREN;
    left := nil;
    right := nil
  end;

  more := get_token(f);
  while more and (f.ttype = NEWLINE) do
    more := get_token(f);
  if not more then
    success := FALSE
  else
    case f.ttype of
      PUNCTUATION:
        case chr(f.tnum) of
          ')':
            begin
              success := FALSE;         { should not have encountered it here }
              f.consumed := FALSE
            end;
          '(':
            with the_operand^ do begin
              right := form_acl_expr(f, 0);
              success := right <> nil
            end;
          else
            success := FALSE
        end;  { case chr(f.tnum) }
      OPER:
        with the_operand^ do begin
          case f.tnum of                  { special cases? }
            OP_PLUS:
              op_name := OP_NUMERIC;
            OP_MINUS:
              op_name := OP_CHS;
            OP_CONCAT:
              op_name := OP_STRING;
            else if not Binary[f.tnum] then
              op_name := f.tnum
            else begin
              expect_general(f, 'unary operator');
              KeepLooking := FALSE;
              success := FALSE
            end
          end;  { case f.tnum }
          if success then begin
            right := form_acl_expr(f, Precedence[op_name]);
            success := right <> nil
          end
        end;
      else begin                              { some constant or keyword }

        new(scalar);
        with scalar^ do
          case f.ttype of
            MESSAGE, TEXT_LIT, QUOTE_LIT:
              begin
                kind  := f.ttype;
                index := f.tnum
              end;
            NUMERIC:
              begin
                kind    := NUMERIC;
                acl_int := f.tnum
              end;
            IDENT:
              begin
                kind       := IDENT;
                ident_kind := DefaultClassification;
                ident_int  := f.tnum
              end;
            RESERVED:
              case f.tnum of
                RW_NULL, RW_UNDEFINED, RW_ABSENT,
                RW_EACH, RW_SELF, RW_SENDER, RW_MESSAGE,
                RW_READ, RW_KEY,
                RW_TRUE, RW_FALSE:
                  begin
                    kind    := RESERVED;
                    keyword := f.tnum
                  end;
                else
                  success := FALSE
              end;  { the "identifier" is a reserved keyword }
            else
              success := FALSE
          end;  { case f.ttype }

        if success then
          the_operand^.right := scalar
        else
          dispose(scalar)

      end;                              { some constant }

    end;  { case f.ttype }

  if not success then begin
    dispose(the_operand);
    f.consumed := FALSE
  end;
  get_operand := success

end;  { get_operand }



{ tie_on_rside

Description:
  Ties on the partial right side of a new operator-operand pair to the
  given existing expression tree.

Arguments:
  existing (IN) --      the existing expression tree (in prefix form).
  op (IN) --            index of an operator (e.g. OP_PLUS, OP_CONCAT)
  new_rside (IN) --     the new right-side operand.

Returns:
  Pointer to the new expression tree.

}

function tie_on_rside(existing: expr_tree;
                      op: integer; new_rside: expr_ptr): expr_ptr;

  var
    tie: boolean;
    new_oper: expr_ptr;

begin

  if (existing^.kind <> OPER) or
     (Precedence[op] < Precedence[existing^.op_name]) then
    tie := TRUE
  else if Precedence[op] > Precedence[existing^.op_name] then
    tie := FALSE
  else                                                    { equal precedence }
    if Right_Assoc[op] then
      tie := FALSE
    else
      tie := TRUE;

  if tie then begin
    new(new_oper);
    with new_oper^ do begin
      kind := OPER;
      op_name := op;
      left := existing;
      right := new_rside
    end;
    tie_on_rside := new_oper
  end
  else begin
    existing^.right := tie_on_rside(existing^.right, op, new_rside);
    tie_on_rside := existing
  end

end;  { tie_on_rside }



{ form_acl_expr

Description:
  Given a "stopping precedence", that is, the "precedence scope" of the
  current level, returns the expression tree from the Archetype program file.
  In other words, if an operator is encountered with a precedence lower
  than the given "stopping precedence", the token will be replaced and
  form_acl_expr will return the tree up to that point.

Arguments (declared forward above):
  stop_precedence (IN)      -- the stopping precedence described above

Returns:
  A pointer to the expression tree, or nil if no expression was read.

}

function form_acl_expr;

  var
    done: boolean;
    expr_tree, rside: expr_ptr;
    the_operator: integer;

begin

  done := FALSE;
  if not get_operand(f, expr_tree) then
    expr_tree := nil
  else
    repeat
      if not get_token(f) then
        done := TRUE

{ Proceed only if the next token is a binary operator.
  If this token we have just taken is a right-hand parenthesis,
  only consume it if we're at level 0. }

      else if (f.ttype <> OPER) or (not Binary[f.tnum]) then begin
        if not ((f.ttype = PUNCTUATION) and (chr(f.tnum) = ')') and
                (stop_precedence = 0)) then
          f.consumed := FALSE;
        done := TRUE
      end

      else begin
        the_operator := f.tnum;
        if Precedence[the_operator] < stop_precedence then begin
          f.consumed := FALSE;
          done := TRUE
        end
        else begin
          if get_operand(f, rside) then
            expr_tree := tie_on_rside(expr_tree, the_operator, rside)
          else begin
            error_message(f, 'Empty expression or unbalanced parentheses');
            dispose_expr(expr_tree);
            expr_tree := nil;
            done := TRUE
          end
        end
      end
    until done;

  form_acl_expr := expr_tree

end;  { form_acl_expr }



{ tighten_expr

Description:
  Cleans up the representation of an expression by removing all
  OP_LPAREN nodes.  This makes it easier to verify; in addition the
  resulting expression will consume less memory.

}

function tighten_expr(the_expr: expr_tree): expr_tree;

  var
    axe: expr_ptr;

begin

  if the_expr <> nil then begin
    if the_expr^.kind = OPER then begin
      if the_expr^.op_name = OP_LPAREN then begin
        axe := the_expr;
        the_expr := the_expr^.right;
        dispose(axe);
        the_expr := tighten_expr(the_expr)
      end
      else
        with the_expr^ do begin
          if Binary[op_name] then left := tighten_expr(left);
          right := tighten_expr(right)
        end;
    end
  end;

  tighten_expr := the_expr

end;



{ display_expr

Description:
  For debugging purposes.  Writes the given tree to standard output in
  an indented prefix form.

Arguments:
  the_tree (IN) -- pointer to top of expression tree

}

procedure display_expr(the_tree: expr_tree; indent: string);

  var
    the_number: longint;

begin

  if the_tree <> nil then
    if the_tree^.kind = OPER then begin
      if the_tree^.op_name <> OP_LPAREN then
        with the_tree^ do begin
          writeln(indent, Operators[op_name]);
          if Binary[op_name] then
            display_expr(left, indent + ' ');
          display_expr(right, indent + ' ')
        end
      else
        display_expr(the_tree^.right, indent)
    end
    else
      with the_tree^ do begin               { format for write_token }
        case kind of
          IDENT:      the_number := ident_int;
          RESERVED:   the_number := keyword;
          TEXT_LIT, MESSAGE, QUOTE_LIT:  the_number := index;
          NUMERIC:    the_number := acl_int;
          else
            the_number := -1;
        end;
        write(indent);
        write_token(the_tree^.kind, the_number);
        writeln
      end

end;  { display_expr }



{ make_acl_expr

Description:
  A quick wrapper to form_acl_expr.  Also invokes semantic checking
  of the expression after it has been syntactically verified.

}

function make_acl_expr(var f: progfile): expr_tree;

  var
    old_newlines : boolean;
    the_expr     : expr_tree;

begin

  old_newlines := f.newlines;
  f.newlines := TRUE;
  the_expr := form_acl_expr(f, 0);
  f.newlines := old_newlines;

  the_expr := tighten_expr(the_expr);
  if verify_expr(f, the_expr) then
    make_acl_expr := the_expr
  else
    make_acl_expr := nil

end;



end.  { unit synexpr }
