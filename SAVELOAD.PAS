{ SAVELOAD.PAS

Description:
  Contains routines for both saving and loading binary ACX files.  Also
  contains routines for disposing of the major ACL structures, in order to
  be able to throw away the old before loading in the new.

}

unit saveload;

interface

  uses misc, id_table, linklist, xarray, keywords, stmt, expr, semantic;

{ Type definitions }
  type

    content_type = (STMT_LIST, EXPR_LIST, CASE_LIST);
    mission_type  = (LOAD, DUMP, FREE, DISPLAY);

    object_ptr = ^object_type;
    object_type =
      record
        inherited_from : integer;      { index to Type_List }
        attributes     : list_type;
        methods        : list_type;
        other          : stmt_ptr
      end;

{ Global variables }
  var
    vEndSeq, vContSeq : stmt_kind;              { to make BlockWrite happy }
    Translating: boolean;

{ Functions and Procedures }
  procedure load_item_list(var f_in: file; var elements: list_type;
                           content: content_type);
  procedure dump_item_list(var f_out: file; elements: list_type;
                           content: content_type);
  procedure dispose_item_list(var elements: list_type; content: content_type);

  procedure load_expr(var f_in: file; var the_expr: expr_tree);
  procedure dump_expr(var f_out: file; the_expr: expr_tree);
  procedure dispose_expr(var the_expr: expr_tree);

  procedure load_stmt(var f_in: file; var the_stmt: stmt_ptr);
  procedure dump_stmt(var f_out: file; the_stmt: stmt_ptr);
  procedure dispose_stmt(var the_stmt: stmt_ptr);

  procedure load_object(var f_in: file; var the_object: object_ptr);
  procedure dump_object(var f_out: file; the_object: object_ptr);
  procedure dispose_object(var the_object: object_ptr);

  procedure load_obj_list(var f_in: file; var obj_list: xarray_type);
  procedure dump_obj_list(var f_out: file; obj_list: xarray_type);
  procedure dispose_obj_list(var obj_list: xarray_type);


implementation

{ Forward Declarations
  These must all be declared here to avoid unpleasant mutual recursion. }

  procedure walk_item_list(mission: mission_type;
                           var bfile: file;
                           var elements: list_type;
                           content: content_type); forward;

  procedure walk_expr(mission: mission_type; var bfile: file;
                      var the_expr: expr_tree); forward;

  procedure walk_stmt(mission: mission_type; var bfile: file;
                      var the_stmt: stmt_ptr); forward;

{ ========================== Item Lists ============================ }

{ Wrappers }

procedure load_item_list(var f_in: file; var elements: list_type;
                         content: content_type);
begin
  walk_item_list(LOAD, f_in, elements, content)
end;

procedure dump_item_list(var f_out: file; elements: list_type;
                         content: content_type);
begin
  walk_item_list(DUMP, f_out, elements, content)
end;

procedure dispose_item_list(var elements: list_type; content: content_type);
  var dummy: file;
begin
  walk_item_list(FREE, dummy, elements, content)
end;


{ walk_item_list

Description:
  Used for operating on general linked lists which are homogenous,
  all containing the same type of data, signified by the "content"
  variable.

Arguments:
  mission (IN)          -- action to perform while walking through
  bfile (IN/OUT)        -- binary file to read from or write to, when
                             necessary
  elements (IN/OUT)     -- list of items
  content (IN)          -- contents of each of the items

}

procedure walk_item_list;

  var
    sentinel  : stmt_kind;
    this_stmt : stmt_ptr;
    this_expr : expr_tree;
    this_case : case_pair_ptr;
    np        : node_ptr;

    yet_more  : boolean;

begin

{ Prelude }
  case mission of
    LOAD: begin
      BlockRead(bfile, sentinel, SizeOf(sentinel));
      new_list(elements);
      yet_more := sentinel = CONT_SEQ
    end;
    DUMP, FREE: begin
      np := nil;
      yet_more := iterate_list(elements, np)
    end;
  end;

  while yet_more do begin

  { Main walk }
    case mission of
      LOAD: begin
        new(np);
        add_bytes(SizeOf(np^));
        BlockRead(bfile, np^.key, SizeOf(np^.key))
      end;
      DUMP: begin
        BlockWrite(bfile, vContSeq, SizeOf(vContSeq));
        BlockWrite(bfile, np^.key, SizeOf(np^.key))
      end;
    end;

    case content of
      EXPR_LIST:
        case mission of
          LOAD: begin
            walk_expr(mission, bfile, this_expr);
            np^.data := this_expr
          end;
          DUMP, FREE: begin
            this_expr := expr_tree(np^.data);
            walk_expr(mission, bfile, this_expr)
          end;
        end;
      STMT_LIST:
        case mission of
          LOAD: begin
            walk_stmt(mission, bfile, this_stmt);
            np^.data := this_stmt
          end;
          DUMP, FREE: begin
            this_stmt := stmt_ptr(np^.data);
            walk_stmt(mission, bfile, this_stmt)
          end;
        end;
      CASE_LIST:
        case mission of
          LOAD: begin
            new(this_case);
            add_bytes(SizeOf(this_case^));
            with this_case^ do begin
              walk_expr(mission, bfile, value);
              walk_stmt(mission, bfile, action)
            end;
            np^.data := this_case
          end;
          DUMP, FREE: begin
            this_case := case_pair_ptr(np^.data);
            with this_case^ do begin
              walk_expr(mission, bfile, value);
              walk_stmt(mission, bfile, action)
            end;
            if mission = FREE then begin
              add_bytes(-SizeOf(this_case^));
              dispose(this_case)
            end
          end;
        end;  { case mission }
      end;  { case content }

    case mission of
      LOAD: begin
        append_to_list(elements, np);
        BlockRead(bfile, sentinel, SizeOf(sentinel));
        yet_more := sentinel = CONT_SEQ
      end;
      DUMP, FREE:
        yet_more := iterate_list(elements, np);
    end

  end;  { while }

{ Postlude }
  case mission of
    DUMP:
      BlockWrite(bfile, vEndSeq, SizeOf(vEndSeq));
    FREE: begin
      dispose_list(elements);
      elements := nil
    end;
  end

end;  { walk_item_list }



{ ============================ Expressions =========================== }

{ Wrappers }

procedure load_expr(var f_in: file; var the_expr: expr_tree);
begin
  walk_expr(LOAD, f_in, the_expr)
end;
procedure dump_expr(var f_out: file; the_expr: expr_tree);
begin
  walk_expr(DUMP, f_out, the_expr)
end;
procedure dispose_expr(var the_expr: expr_tree);
  var dummy: file;
begin
  walk_expr(FREE, dummy, the_expr)
end;



{ LoadDynStr

Separated from walk_expr so as not to consume too much stack space with
its large temporary string..

}

function LoadDynStr(var bfile : file) : string_ptr;

  var
    s : string;

begin

  load_string(bfile, s);
  LoadDynStr := NewDynStr(s)

end;



{ walk_expr

Description:
  Walks through an expression tree.

Arguments:
  mission (IN)          -- action to take on each visited element
  bfile (IN/OUT)        -- binary file to read or write from as necessary
  the_expr (IN/OUT)     -- expression tree to walk

}

procedure walk_expr;

var
  temp    : integer;
  ID_kind : classify_type;
  id_ptr  : id_rec_ptr;

begin

{ Prelude }
  case mission of
    LOAD: begin
      new(the_expr);
      add_bytes(SizeOf(the_expr^));
      BlockRead(bfile, the_expr^.kind, SizeOf(the_expr^.kind));
    end;
    DUMP: begin
      if the_expr = nil then exit;
      while (the_expr^.kind = OPER) and (the_expr^.op_name = OP_LPAREN) do
        the_expr := the_expr^.right;
      BlockWrite(bfile, the_expr^.kind, SizeOf(the_expr^.kind))
    end;
    FREE:
      if the_expr = nil then exit;
  end;  { case }

{ Main walk }
  with the_expr^ do
    case kind of
      OPER: begin
        case mission of
          LOAD: begin
            BlockRead(bfile, op_name, SizeOf(op_name));
            left := nil
          end;
          DUMP:
            BlockWrite(bfile, op_name, SizeOf(op_name));
        end;
        if Binary[op_name] then
          walk_expr(mission, bfile, left);
        walk_expr(mission, bfile, right)
      end;
      NUMERIC:
        case mission of
          LOAD:
            BlockRead(bfile, acl_int, SizeOf(acl_int));
          DUMP:
            BlockWrite(bfile, acl_int, SizeOf(acl_int));
        end;
      MESSAGE, TEXT_LIT, QUOTE_LIT:
        case mission of
          LOAD:
            BlockRead(bfile, index, SizeOf(index));
          DUMP:
            BlockWrite(bfile, index, SizeOf(index));
        end;
      IDENT:
        case mission of
          LOAD: begin
            BlockRead(bfile, ident_kind, SizeOf(ident_kind));
            BlockRead(bfile, ident_int, SizeOf(ident_int))
          end;
          DUMP: begin
            if Translating and
               (ident_kind = DefaultClassification)
            then begin   { may have changed meaning }
              get_meaning(ident_int, ID_kind, temp);
              if ID_kind = UNDEFINED_ID then
                add_undefined(ident_int)
              else begin
                ident_kind := ID_kind;
                ident_int  := temp
              end
            end;
            BlockWrite(bfile, ident_kind, SizeOf(ident_kind));
            BlockWrite(bfile, ident_int, SizeOf(ident_int))
          end;
        end;  { case }
      RESERVED:
        case mission of
          LOAD:
            BlockRead(bfile, keyword, SizeOf(keyword));
          DUMP:
            BlockWrite(bfile, keyword, SizeOf(keyword));
        end;
      STR_PTR:
        case mission of
          LOAD:
            acl_str := LoadDynStr(bfile);
          DUMP:
            dump_string(bfile, acl_str^);
          FREE:
            FreeDynStr(acl_str)
        end;
      end;  { case kind }

{ Postlude }
  case mission of
    FREE: begin
      dispose(the_expr);
      the_expr := nil
    end;
  end

end;  { walk_expr }



{ =========================== Statements ========================= }

{ Wrappers }

procedure load_stmt(var f_in: file; var the_stmt: stmt_ptr);
begin
  walk_stmt(LOAD, f_in, the_stmt)
end;
procedure dump_stmt(var f_out: file; the_stmt: stmt_ptr);
begin
  walk_stmt(DUMP, f_out, the_stmt)
end;
procedure dispose_stmt(var the_stmt: stmt_ptr);
  var dummy: file;
begin
  walk_stmt(FREE, dummy, the_stmt)
end;


{ walk_stmt

Description:
  Handles the control involved in walking through a statement.

Arguments:
  mission (IN)          -- action to take for each statement
  bfile (IN/OUT)        -- binary file to read or write as necessary
  the_stmt (IN/OUT)     -- pointer to a statement record

}

procedure walk_stmt;

  var
    np: node_ptr;                { for appending to lists }
    sentinel: stmt_kind;
    this_case: case_pair_ptr;
    this_stmt: stmt_ptr;
    this_expr: expr_tree;

begin

{ Prelude }
  case mission of
    LOAD: begin
      the_stmt := nil;
      if eof(bfile) then exit;
      BlockRead(bfile, sentinel, SizeOf(sentinel));
      if sentinel = END_SEQ then exit;
      new(the_stmt);
      add_bytes(SizeOf(the_stmt));
      the_stmt^.kind := sentinel
    end;
    DUMP: begin
      if the_stmt = nil then begin
        BlockWrite(bfile, vEndSeq, SizeOf(vEndSeq));
        exit
      end;
      BlockWrite(bfile, the_stmt^.kind, SizeOf(the_stmt^.kind))
    end;
    FREE:
      if the_stmt = nil then exit;
  end;

{ Main walk }
  with the_stmt^ do
    case kind of
      COMPOUND:
        walk_item_list(mission, bfile, statements, STMT_LIST);
      ST_EXPR:
        walk_expr(mission, bfile, expression);
      ST_IF: begin
        walk_expr(mission, bfile, condition);
        walk_stmt(mission, bfile, then_branch);
        walk_stmt(mission, bfile, else_branch)
      end;
      ST_CASE: begin
        walk_expr(mission, bfile, test_expr);
        walk_item_list(mission, bfile, cases, CASE_LIST)
      end;
      ST_CREATE: begin
        case mission of
          LOAD : BlockRead (bfile, archetype, SizeOf(archetype));
          DUMP : BlockWrite(bfile, archetype, SizeOf(archetype));
        end;
        walk_expr(mission, bfile, new_name);
      end;
      ST_DESTROY:
        walk_expr(mission, bfile, victim);
      ST_FOR, ST_WHILE: begin
        walk_expr(mission, bfile, selection);
        walk_stmt(mission, bfile, action)
      end;
      ST_WRITE, ST_WRITES, ST_STOP:
        case mission of
          LOAD: begin
            new_list(print_list);
            BlockRead(bfile, sentinel, SizeOf(sentinel));
            while sentinel <> END_SEQ do begin
              walk_expr(mission, bfile, this_expr);
              new(np);
              add_bytes(SizeOf(np^));
              np^.data := this_expr;
              append_to_list(print_list, np);
              BlockRead(bfile, sentinel, SizeOf(sentinel))
            end
          end;
          DUMP, FREE: begin
            np := nil;
            while iterate_list(print_list, np) do begin
              if mission = DUMP then
                BlockWrite(bfile, vContSeq, SizeOf(vContSeq));
              this_expr := expr_tree(np^.data);
              walk_expr(mission, bfile, this_expr);
              if mission = FREE then
                np^.data := nil
            end;
            if mission = DUMP then
              BlockWrite(bfile, vEndSeq, SizeOf(vEndSeq))
            else
              dispose_list(print_list)
          end;
        end   { case mission }
      end;  { case kind }

{ Postlude }
  case mission of
    FREE: begin
      add_bytes(-SizeOf(the_stmt^));
      dispose(the_stmt)
    end
  end

end;  { walk_stmt }



{ ============================ Objects =========================== }


{ load_object

Description:
  Loads an object from the given binary input file and attaches
  it to the given object pointer.

Arguments:
  f_in (IN/OUT)                 -- binary input file
  the_object (OUT)              -- new object

}

procedure load_object(var f_in: file; var the_object: object_ptr);

  var sentinel : stmt_kind;

begin

  new(the_object);
  add_bytes(SizeOf(the_object^));
  with the_object^ do begin
    BlockRead(f_in, inherited_from, SizeOf(inherited_from));
    load_item_list(f_in, attributes, EXPR_LIST);
    load_item_list(f_in, methods, STMT_LIST);
    BlockRead(f_in, sentinel, SizeOf(sentinel));
    if sentinel = CONT_SEQ then
      load_stmt(f_in, other)
    else
      other := nil
  end

end;  { load_object }



{ dump_object

Description:
  Writes the given object to the given file.

Arguments:
  f_out (IN/OUT)            -- file to write to
  the_object (IN/OUT)       -- object to be disposed of

}

procedure dump_object(var f_out: file; the_object: object_ptr);

begin

  with the_object^ do begin
    BlockWrite(f_out, inherited_from, SizeOf(inherited_from));
    dump_item_list(f_out, attributes, EXPR_LIST);
    dump_item_list(f_out, methods, STMT_LIST);
    if other = nil then
      BlockWrite(f_out, vEndSeq, SizeOf(vEndSeq))
    else begin
      BlockWrite(f_out, vContSeq, SizeOf(vContSeq));
      dump_stmt(f_out, other)
    end
  end

end;  { dump_object }



{ dispose_object

Description:
  Disposes of all memory associated with the given object pointer.

Arguments:
  the_object (IN/OUT)       -- object to be disposed of

}

procedure dispose_object(var the_object: object_ptr);

begin

  with the_object^ do begin
    dispose_item_list(attributes, EXPR_LIST);
    dispose_item_list(methods, STMT_LIST);
    if other <> nil then
      dispose_stmt(other)
  end;
  add_bytes(-SizeOf(the_object^));
  dispose(the_object);
  the_object := nil

end;  { dispose_object }



{ ============================= Object Lists ======================== }

{ load_obj_list

Description:
  Loads a list of object from the given binary input file and
  attaches it to the given xarray.

Arguments:
  f_in (IN/OUT)                 -- binary input file
  obj_list (OUT)                -- xarray of objects

}

procedure load_obj_list(var f_in: file; var obj_list: xarray_type);

  var
    new_object: object_ptr;
    p: pointer;
    i, list_size: integer;

begin

  new_xarray(obj_list);
  BlockRead(f_in, list_size, SizeOf(list_size));
  for i := 1 to list_size do begin
    load_object(f_in, new_object);
    p := new_object;
    append_to_xarray(obj_list, p)
  end

end;  { load_obj_list }



{ dump_obj_list

Description:
  Writes the given object list to the given file.

Arguments:
  f_out (IN/OUT)            -- file to write to
  obj_list (IN)             -- object list to write
}

procedure dump_obj_list(var f_out: file; obj_list: xarray_type);

  var
    i: integer;
    p: pointer;
    this_obj: object_ptr;

begin

  BlockWrite(f_out, obj_list.size, SizeOf(obj_list.size));
  for i := 1 to obj_list.size do
    if index_xarray(obj_list, i, p) then begin
      this_obj := object_ptr(p);
      dump_object(f_out, this_obj)
    end

end;  { dump_obj_list }



{ dispose_obj_list

Description:
  Disposes of all memory associated with an xarray of object definitions.

Arguments:
  obj_list (IN/OUT)           -- object xarray to be disposed of

}

procedure dispose_obj_list(var obj_list: xarray_type);

  var
    i: integer;
    p: pointer;
    axe_obj: object_ptr;

begin

  for i := 1 to obj_list.size do
    if index_xarray(obj_list, i, p) then begin
      axe_obj := object_ptr(p);
      dispose_object(axe_obj)
    end;
  dispose_xarray(obj_list)

end;  { dispose_obj_list }


begin

{ to make BlockWrite happy }
  vEndSeq := END_SEQ;
  vContSeq := CONT_SEQ;

  Translating := TRUE

end.  { unit saveload }
