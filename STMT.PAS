{ STMT.PAS

Description:
  An "include unit" which contains the statement-type and case-pair
  definitions.

}

unit stmt;


interface

  uses linklist, expr;

  type

    stmt_kind = (COMPOUND, ST_EXPR, ST_IF, ST_CASE,
                 ST_FOR, ST_WHILE, ST_BREAK,
                 ST_CREATE, ST_DESTROY,
                 ST_WRITE, ST_WRITES, ST_STOP,
                 CONT_SEQ, END_SEQ);

    stmt_ptr = ^stmt_type;
    stmt_type =
      record
        case kind: stmt_kind of
          COMPOUND:
            (statements: list_type);
          ST_EXPR:
            (expression: expr_tree);
          ST_IF: (
            condition: expr_tree;
            then_branch: stmt_ptr;
            else_branch: stmt_ptr
            );
          ST_CASE: (
            test_expr: expr_tree;
            cases: list_type
            );
          ST_CREATE: (
            archetype: integer;         { direct pointer to Type_List }
            new_name: expr_tree
            );
          ST_DESTROY:
            (victim: expr_tree);
          ST_FOR, ST_WHILE: (
            selection: expr_tree;
            action: stmt_ptr
            );
          ST_WRITE, ST_WRITES, ST_STOP:
            (print_list: list_type);
      end;  { stmt_type }

    case_pair_ptr = ^case_pair_type;
    case_pair_type =
      record
        value: expr_tree;
        action: stmt_ptr
      end;

implementation      { dummy implementation - must be here }


end.  { unit stmt }
