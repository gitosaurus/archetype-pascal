{ SEMANTIC.PAS

Description:
  Used by the SYNTAX unit, it provides the high-level semantic checking
  as well as .ACX file output.

}

unit semantic;


interface

  uses misc, linklist, xarray, token, keywords, error, expr, id_table;

{ Global Variables }
  var
    Type_List, Object_List: xarray_type;
    Overlooked : list_type;


{ Procedures and Functions }
  function classify_as(var f: progfile;
                       id_number: integer;
                       interpretation: classify_type;
                       ptr_to_data: pointer): integer;
  procedure get_meaning(id_number: integer; var meaning: classify_type;
                                            var number: integer);
  function display_undefined : boolean;
  procedure add_undefined(the_ID : integer);
  function verify_expr(var f: progfile; the_expr: expr_tree) : boolean;

implementation

  type
    integer_ptr = ^integer;


{ classify_as

Description:
  Works closely with the ID_Table to create and verify the various semantic
  interpretations of identifiers, which are classified as either:
    TYPE_ID:      names a type definition template in the type list.
    OBJECT_ID:    names an object instantiation in the object list.
    ATTRIBUTE_ID: an attribute identifier.
    ENUMERATE_ID: an identifier like "open" or "closed" which is simply
                    assigned so that it can be tested.
    UNDEFINED_ID: Not defined anywhere.  If /K is asserted for CREATE, then
                  this is the value returned by default; otherwise,
                  ENUMERATE_ID is.

Arguments:
  f (IN)                    -- the progfile that is being read.  Since
                                this function is part of the first "pass",
                                it needs access to the file being read.
  id_number (IN)            -- the index in the ID table
  interpretation (IN)       -- one of the constants above
  ptr_to_data (IN)          -- if not nil, points to the data that
                                 the identifier represents (when first
                                 encountered)

Returns:  depends on interpretation:
            TYPE_ID:      the index in Type_List
            OBJECT_ID:    the index in Object_List
            ATTRIBUTE_ID: the order the identifier was declared in, i.e.
                            for the first attribute encountered, 1, for the
                            second, 2, etc.
            ENUMERATE_ID: the unchanged id_number, for a simple unique number.
            UNDEFINED_ID: same as ENUMERATE_ID

          In any case, classify_as returns 0 if there was an error.
          Such an error will have been printed by this routine, so there
          will be no need for the caller to print out its own.

}

var
  NullStr : string_ptr;

function classify_as(var f: progfile;
                     id_number: integer;
                     interpretation: classify_type;
                     ptr_to_data: pointer): integer;

  var
    the_id_ptr   : id_rec_ptr;
    error_string : string;

begin

  if not index_ident(id_number, the_id_ptr) then
    error_message(f, 'Attempt to classify unencountered identifier')
  else
    with the_id_ptr^ do begin
      if id_kind = interpretation then
        classify_as := id_integer

{ If the existing id_kind is the DefaultClassification, we're allowed to
  change it; otherwise there's a conflict }

      else if id_kind = DefaultClassification then begin
        id_kind    := interpretation;
        id_integer := id_index;
        case id_kind of
          TYPE_ID: begin
            append_to_xarray(Type_List, ptr_to_data);
            append_to_xarray(Type_ID_List, pointer(id_name));
            id_integer := Type_List.size
          end;
          OBJECT_ID:
            if ptr_to_data = nil then
              id_integer := 0
            else begin
{ Object_List may have grown by unnamed objects between calls to classify_as.
  Fill in the intervening spaces with "null".  }
              while Object_ID_List.size < Object_List.size do
                append_to_xarray(Object_ID_List, pointer(NullStr));
              append_to_xarray(Object_List, ptr_to_data);
              append_to_xarray(Object_ID_List, pointer(id_name));
              id_integer := Object_List.size
            end;
          ATTRIBUTE_ID: begin
            append_to_xarray(Attribute_ID_List, pointer(id_name));
            id_integer := Attribute_ID_List.size
          end;
        end  { case }
      end
      else begin
        error_string := 'Identifier type conflict: "' + id_name^ +
                       '" already declared as ';
        case id_kind of
          TYPE_ID:
            error_string := error_string + 'a type';
          OBJECT_ID:
            error_string := error_string + 'an object';
          ATTRIBUTE_ID:
            error_string := error_string + 'an attribute';
          ENUMERATE_ID:
            error_string := error_string + 'a keyword';
        end;
        error_message(f, error_string);
        id_integer := 0
      end;

      classify_as := id_integer

    end  { with }


end;  { classify_as }




{ get_meaning

Description:
  Given an ID_Table index, finds what it represents and returns an
  appropriate enumerated type and index.

  If /K is asserted, default return is UNDEFINED_ID; else it is ENUMERATE_ID.

Arguments:
  id_number (IN)            -- integer index to ID_Table
  meaning (OUT)             -- classification of ID
  number (OUT)              -- integer appropriate to classification

}

procedure get_meaning(id_number: integer; var meaning: classify_type;
                                          var number: integer);

  var
    the_id_ptr: id_rec_ptr;

begin

  if not index_ident(id_number, the_id_ptr) then begin
    writeln('Internal error:  ',
            'attempt to find meaning of unencountered identifier');
    halt
  end
  else
    with the_id_ptr^ do begin
      meaning := id_kind;
      number := id_integer
    end

end;  { get_meaning }



{ add_undefined

Description:
  Used for adding the number of an undefined identifier to a list to be
  produced at the end of translation.

}

procedure add_undefined(the_ID : integer);

  var
    np : node_ptr;
    ip : integer_ptr;

begin

  np := find_item(Overlooked, the_ID);
  if np <> nil then
    inc(integer_ptr(np^.data)^)
  else begin
    new(np);
    np^.key  := the_ID;
    new(ip);
    ip^ := 1;
    np^.data := ip;
    insert_item(Overlooked, np)
  end

end;



{ display_undefined

Description:
  Displays the list of undefined identifiers collected with add_undefined.

}

function display_undefined : boolean;

  var

    np : node_ptr;
    ip : integer_ptr;
    id_rec : id_rec_ptr;

    i, ls : integer;

    exists : boolean;

begin

  exists := FALSE;
  np := nil;
  while iterate_list(Overlooked, np) do begin
    if not exists then begin
      writeln('The following identifiers were not explicitly defined.');
      exists := TRUE
    end;
    ip := integer_ptr(np^.data);
    write ('Used ', ip^ : 3);
    if ip^ = 1 then write(' time:   ') else write(' times:  ');
    if index_ident(np^.key, id_rec) then
      writeln(id_rec^.id_name^)
    else
      writeln('<unknown identifier>');
    dispose(ip)
  end;

  dispose_list(Overlooked);

  display_undefined := exists

end;  { display_undefined }



{ verify_expr

Description:
  Assumes that expression tree contains no OP_LPAREN nodes.
  Ensures the following:
  1.    All OP_DOT operators have identifiers as their right-hand
        arguments, which are classified as ATTRIBUTE_ID's.
  2.    All assignment operators have OP_DOT operators or identifiers
        as their left-hand arguments, and any such identifiers are
        classified as ATTRIBUTE_ID's.
  This is necessary because the only way to use the OP_DOT operator is
  to discover the value of some attribute, and attributes are the only
  things which may be assigned to.

Arguments:
  f (IN/OUT)            -- program file (for logging errors)
  the_expr (IN)         -- expression to be verified

}

function verify_expr(var f: progfile; the_expr: expr_tree) : boolean;

  var
    success : boolean;

begin

  success := TRUE;
  with the_expr^ do
    case kind of
      OPER : begin
        case op_name of
          OP_DOT: begin
            if right^.kind <> IDENT then begin
              error_message(f, 'Right side of dot must be an identifier');
              success := FALSE
            end
            else if right^.ident_kind <> ATTRIBUTE_ID then
              right^.ident_int :=
                classify_as(f, right^.ident_int, ATTRIBUTE_ID, nil);
            right^.ident_kind := ATTRIBUTE_ID;
            if right^.ident_int = 0 then success := FALSE
          end;
          OP_ASSIGN, OP_C_CONCAT, OP_C_MULTIPLY,
          OP_C_DIVIDE, OP_C_PLUS, OP_C_MINUS:
            if left^.kind = IDENT then begin
              get_meaning(left^.ident_int, left^.ident_kind,
                                           left^.ident_int);
              if left^.ident_kind <> ATTRIBUTE_ID then begin
                error_message(f, 'Left side of assignment is not an attribute');
                success := FALSE
              end
            end
            else if not ((left^.kind = OPER) and
                         (left^.op_name = OP_DOT)) then begin
              error_message(f,
                 'Left side of assignment must reference an attribute');
              success := FALSE
            end
        end;  { case }

        if success then
          if Binary[op_name] then success := verify_expr(f, left);
        if success then success := verify_expr(f, right)
      end;  { OPER}
    end;  { case }

    verify_expr := success

end;  { verify_expr }


procedure init_NullStr;

  var s : string;

begin

  s := 'null'; NullStr := NewConstStr(s)

end;


begin  { Initialization }

  new_list(Overlooked);

  new_xarray(Type_List);
  new_xarray(Object_List);
  init_NullStr

end.  { unit semantic }
