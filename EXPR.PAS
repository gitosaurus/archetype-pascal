{ EXPR.PAS

Description:
  An "include unit" which contains the necessary type definitions,
  arrays, and initializations for the use of expression structures.

}

unit expr;

interface

  uses misc, linklist, keywords;

  const
    OP_LPAREN = NUM_OPERS + 1;              { book-keeping operator }
    OP_SEND_TO_TYPE = NUM_OPERS + 2;        { for use with interpreter }

  type

    expr_ptr = ^expr_node;
    expr_node =
      record
        case kind: acl_type of
          OPER: (
            op_name: shortint;      { see KEYWORDS unit for description }
            left, right: expr_ptr   { left will be nil for unary operators }
            );
          NUMERIC:
            (acl_int: longint);
          MESSAGE, TEXT_LIT, QUOTE_LIT:
            (index: integer);
          STR_PTR:
            (acl_str: string_ptr);
          ATTR_PTR:
            (acl_attr: node_ptr);
          RESERVED:
            (keyword: shortint);
          IDENT: (
            ident_kind: classify_type;
            ident_int: integer
            )
      end;
    expr_tree = expr_ptr;

{ Global Variables }
  var
    Right_Assoc, Binary: array[1 .. NUM_OPERS + 1] of boolean;
    Precedence: array[1 .. NUM_OPERS + 1] of shortint;


implementation

  var i : integer;

begin


  Binary[OP_LPAREN]     := FALSE;
  Binary[OP_DOT]        := TRUE;
  Binary[OP_CHS]        := FALSE;
  Binary[OP_NUMERIC]    := FALSE;
  Binary[OP_STRING]     := FALSE;
  Binary[OP_RANDOM]     := FALSE;
  Binary[OP_LENGTH]     := FALSE;
  Binary[OP_POWER]      := TRUE;
  Binary[OP_MULTIPLY]   := TRUE;
  Binary[OP_DIVIDE]     := TRUE;
  Binary[OP_PLUS]       := TRUE;
  Binary[OP_MINUS]      := TRUE;
  Binary[OP_CONCAT]     := TRUE;
  Binary[OP_WITHIN]     := TRUE;
  Binary[OP_LEFTFROM]   := TRUE;
  Binary[OP_RIGHTFROM]  := TRUE;
  Binary[OP_EQ]         := TRUE;
  Binary[OP_NE]         := TRUE;
  Binary[OP_GT]         := TRUE;
  Binary[OP_LT]         := TRUE;
  Binary[OP_GE]         := TRUE;
  Binary[OP_LE]         := TRUE;
  Binary[OP_NOT]        := FALSE;
  Binary[OP_AND]        := TRUE;
  Binary[OP_OR]         := TRUE;
  Binary[OP_C_MULTIPLY] := TRUE;
  Binary[OP_C_DIVIDE]   := TRUE;
  Binary[OP_C_PLUS]     := TRUE;
  Binary[OP_C_MINUS]    := TRUE;
  Binary[OP_C_CONCAT]   := TRUE;
  Binary[OP_ASSIGN]     := TRUE;
  Binary[OP_SEND]       := TRUE;
  Binary[OP_PASS]       := TRUE;

{ Initialize the Right_Assoc table as follows:
    anything unary must be right-associative; all others
    are assumed left-associative.  After the loop, right-associative
    binary operators are explicity set. }

  for i := 1 to NUM_OPERS do
    Right_Assoc[i] := not Binary[i];

  Right_Assoc[OP_POWER]      := TRUE;
  Right_Assoc[OP_C_MULTIPLY] := TRUE;
  Right_Assoc[OP_C_DIVIDE]   := TRUE;
  Right_Assoc[OP_C_PLUS]     := TRUE;
  Right_Assoc[OP_C_MINUS]    := TRUE;
  Right_Assoc[OP_C_CONCAT]   := TRUE;
  Right_Assoc[OP_ASSIGN]     := TRUE;


  Precedence[OP_LPAREN]     := 14;   { must always be the higest }
  Precedence[OP_DOT]        := 13;

  Precedence[OP_CHS]        := 12;
  Precedence[OP_NUMERIC]    := 12;
  Precedence[OP_STRING]     := 12;
  Precedence[OP_RANDOM]     := 12;
  Precedence[OP_LENGTH]     := 12;

  Precedence[OP_POWER]      := 11;

  Precedence[OP_MULTIPLY]   := 10;
  Precedence[OP_DIVIDE]     := 10;

  Precedence[OP_PLUS]       := 9;
  Precedence[OP_MINUS]      := 9;
  Precedence[OP_CONCAT]     := 9;

  Precedence[OP_WITHIN]     := 8;

  Precedence[OP_LEFTFROM]   := 7;
  Precedence[OP_RIGHTFROM]  := 7;

  Precedence[OP_SEND]       := 6;
  Precedence[OP_PASS]       := 6;

  Precedence[OP_EQ]         := 5;
  Precedence[OP_NE]         := 5;
  Precedence[OP_GT]         := 5;
  Precedence[OP_LT]         := 5;
  Precedence[OP_GE]         := 5;
  Precedence[OP_LE]         := 5;

  Precedence[OP_NOT]        := 4;
  Precedence[OP_AND]        := 3;
  Precedence[OP_OR]         := 2;

  Precedence[OP_C_MULTIPLY] := 1;
  Precedence[OP_C_DIVIDE]   := 1;
  Precedence[OP_C_PLUS]     := 1;
  Precedence[OP_C_MINUS]    := 1;
  Precedence[OP_C_CONCAT]   := 1;
  Precedence[OP_ASSIGN]     := 1

end.
