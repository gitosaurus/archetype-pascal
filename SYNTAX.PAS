{ SYNTAX

  Description:
    The syntactic (and semantic) analyzer for Archetype programs.
    There is a procedure at the bottom called syntax_stream, where the
    processing begins.  As it encounters various tokens, it passes
    syntactic checking to other procedures; as control traces through
    these calls, it polices the source code and creates the run-time
    structure in memory.

    This structure must then be written to the disk using the SAVELOAD
    unit, where it will be read again by the CREATE program.

    Many procedures are the implementation of the Backus-Naur Form of
    Archetype as described in the file BNF.ACH .  Their associated BNF
    definition is included in their documentation.

}

unit syntax;

interface

  uses
    Crt,
    misc, linklist, xarray,
    id_table, crypt,
    keywords, token,
    semantic, synexpr, synstmt,
    saveload, error,
    timestmp;

{ Global Variables }

  var
    MainObject  : integer;
    IncludePath : string;

{ Functions and Procedures }
  function dump_game(outfile: string): boolean;
  function syntax_stream(acl_file: string; includeFile: boolean): boolean;


implementation


{ open_includefile

Description:
  Opens an Archetype include file.  If we can't find the file in
  the current directory, try prepending the directory where the
  CREATE program is stored and try again.

  In the future, this function will encapsulate such clevernesses
  as an include-file search list, but not just yet.

}

function open_includefile(var filerec: progfile; var name: string): boolean;

  var
    success : boolean;
    temp    : string;

begin

  if open_progfile(filerec, name) then
    success := TRUE
  else if length(IncludePath) > 0  then
  begin
    temp := Concat(IncludePath, name);
    success := open_progfile(filerec, temp)
  end
  else
    success := FALSE;

  open_includefile := success

end;            { open_includefile }



{ declare_object

Description:
  Ensures syntactic and semantic correctness of a standard object
  declaration.  Used for both object instantiation and the defining
  of new types.

NOTES:
  The local variable the_attr is used for storing/indexing both
  attributes and methods, because both can be described by an
  integer index and a pointer to either a statement-type or
  expression-type.

BNF: <declare_object> ::= <attrdecl>* [methods <method>*] end

}

function declare_object(var f: progfile;
                         var the_object: object_ptr): boolean;

  var
    done        : boolean;
    success     : boolean;
    the_attr    : node_ptr;
    attr_id_num : integer;

begin

  if get_token(f) then
    f.consumed := FALSE
  else begin
    hit_eof(f, RESERVED, RW_END);
    the_object := nil;
    declare_object := FALSE;
    exit
  end;

{ Be optimistic! }
  done := FALSE;
  success := TRUE;
  new(the_object);
  with the_object^ do begin
    new_list(attributes);
    new_list(methods);
    other := nil
  end;

  repeat
{ is this necessary? }
    if not get_token(f) then begin
      error_message(f, 'Expected Archetype literal; found end of file');
      success := FALSE
    end
    else
      case f.ttype of
        IDENT:
          begin
            attr_id_num := f.tnum;
            new(the_attr);
            if not insist_on(f, PUNCTUATION, ord(':')) then
              success := FALSE
            else begin
              the_attr^.data := make_acl_expr(f);
              if the_attr^.data = nil then begin
                success := FALSE;
                expect_general(f, 'Archetype expression')
              end
              else begin
                the_attr^.key :=
                  classify_as(f, attr_id_num, ATTRIBUTE_ID, nil);
                if the_attr^.key = 0 then
                  success := FALSE
                else
                  insert_item(the_object^.attributes, the_attr)
              end
            end
          end;
        RESERVED:
          if (f.tnum = RW_METHODS) or (f.tnum = RW_END) then
            done := TRUE;
        else begin
          expect_general(f, 'Archetype expression');
          success := FALSE
        end
      end   { case }

  until (not success) or done;

  if success and (f.tnum = RW_METHODS) then begin
    done := FALSE;
    repeat
      if not get_token(f) then begin
        hit_eof(f, RESERVED, RW_END);
        success := FALSE
      end
      else if f.ttype = RESERVED then
        case f.tnum of
          RW_END :
            done := TRUE;
          RW_DEFAULT :
            if not insist_on(f, PUNCTUATION, ord(':')) then
              success := FALSE
            else begin
              the_object^.other := make_acl_statement(f);
              if the_object^.other = nil then begin
                error_message(f,
                     'Expected an Archetype statement or expression');
                success := FALSE
              end
            end;
          else begin
            expect_general(f, 'Archetype message');
            KeepLooking := FALSE;
            success := FALSE
          end
        end  { case }
      else if f.ttype <> MESSAGE then begin
        expected(f, MESSAGE, -1);
        KeepLooking := FALSE;
        success := FALSE
      end
      else begin
        new(the_attr);
        the_attr^.key  := f.tnum;
        if not insist_on(f, PUNCTUATION, ord(':')) then
          success := FALSE
        else begin
          the_attr^.data := make_acl_statement(f);
          if the_attr^.data = nil then begin
            error_message(f, 'Expected an Archetype statement or expression');
            success := FALSE
          end
          else
            insert_item(the_object^.methods, the_attr)
        end
      end
    until (not success) or done
  end;

  if not success then
    dispose_object(the_object);

  declare_object := success

end;  { declare_object }



{ define_type

Description:
  Handles "type <newtype> based on <oldtype>" declarations.

BNF:
  <class_defn> ::= type <ident> based on <typeident> <declare_object>

Notes:
  The RW_TYPE token will already have been removed from the stream
  when this procedure begins.
}

function define_type(var f: progfile): boolean;

  var
    new_type_num, old_type_num, new_type_id_num: integer;
    the_type_ptr: object_ptr;
    the_id_type: classify_type;
    ptr_to_type: pointer;
    success: boolean;

begin

  success := TRUE;

  if not get_token(f) then begin
    error_message(f, 'Expected name of new type; found end of file');
    KeepLooking := FALSE;
    success := FALSE
  end
  else if f.ttype <> IDENT then begin
    expect_general(f, 'name of new type');
    KeepLooking := FALSE;
    success := FALSE
  end
  else begin

{ Although this seems more complicated than simply leaving it to classify_as,
  the fact is that an error in the new type name will not be flagged until
  the end of the type definition.  For one thing, the error message will
  not show the offending line; for another, the work will have been wasted.
  However, we will invoke classify_as to produce the desired error. }
    get_meaning(f.tnum, the_id_type, new_type_id_num);
    if the_id_type <> DefaultClassification then begin     { it's wrong! }
      if the_id_type = TYPE_ID then
        if index_xarray(Type_ID_List, new_type_id_num, ptr_to_type) then
          error_message(f, 'Type "' + string_ptr(ptr_to_type)^ +
                           '" has already been defined')
        else
          error_message(f, 'Internal error: unencountered identifier')
      else
        new_type_id_num :=  classify_as(f, f.tnum, TYPE_ID, nil);
      KeepLooking := FALSE;
      define_type := FALSE;
      exit
    end;

    new_type_id_num := f.tnum;
    if not (insist_on(f, RESERVED, RW_BASED) and
            insist_on(f, RESERVED, RW_ON)) then
      success := FALSE
    else if not get_token(f) then begin
      error_message(f, 'Expected name of defined type; found end of file');
      KeepLooking := FALSE;
      success := FALSE
    end
    else if (f.ttype = RESERVED) and (f.tnum = RW_NULL) then
      old_type_num := 0
    else if f.ttype <> IDENT then begin
      expect_general(f, 'name of defined type');
      KeepLooking := FALSE;
      success := FALSE
    end
    else begin
      get_meaning(f.tnum, the_id_type, old_type_num);
      if the_id_type <> TYPE_ID then begin
        expect_general(f, 'name of defined type');
        KeepLooking := FALSE;
        success := FALSE
      end
    end
  end;

{ Note that we actually invoke classify_as twice here.  It has to be done
  before invoking declare_object() so that a type definition can refer
  to itself recursively in its default methods, as in
  "create <self> named ..." }
  if success then begin
    new_type_num := classify_as(f, new_type_id_num, TYPE_ID, nil);
    if not declare_object(f, the_type_ptr) then
      success := FALSE
    else begin
      ptr_to_type := the_type_ptr;
{ We invoked classify_as() earlier to reserve the type name in the type
  table.  Now we attach the pointer. }
      if not access_xarray(Type_List, new_type_num,
                           ptr_to_type, POKE_ACCESS) then begin
        error_message(f, 'Could not access existing type!');
        KeepLooking := FALSE;
        success := FALSE
      end
      else if new_type_num <> Type_List.size then begin
        if new_type_num <> 0 then begin
          error_message(f, 'Internal type table out of sync!');
          writeln('Expected to have defined type ', Type_List.size);
          writeln('but instead just defined ', new_type_num)
        end;
        KeepLooking := FALSE;
        success := FALSE
      end;
      the_type_ptr^.inherited_from := old_type_num
    end
  end;

  define_type := success

end;  { define_type }



{ instantiate

Description:
  Creates an instantation of the type of the given identifier.

BNF:  <instantiate> ::= <typeident> <ident> <declare_object>

Arguments:
  type_id (IN) --       Number of an identifier which indicates the name
                          of a type, which should already have been defined.

}

function instantiate(var f: progfile; type_id_num: integer): boolean;

  var
    ptr_to_obj: pointer;
    obj_index, type_index, object_id_num: integer;
    the_id_type: classify_type;
    the_obj_ptr: object_ptr;
    success: boolean;

begin

  if type_id_num = 0 then begin
    type_index := type_id_num;
    the_id_type := TYPE_ID
  end
  else
    get_meaning(type_id_num, the_id_type, type_index);

  success := TRUE;
  if the_id_type <> TYPE_ID then begin
    error_message(f, 'Require name of defined type');
    KeepLooking := FALSE;
    success := FALSE
  end
  else if not get_token(f) then begin
    error_message(f, 'Expected name of new object; found end of file');
    KeepLooking := FALSE;
    success := FALSE
  end
  else if (f.ttype = IDENT) or
          ((f.ttype = RESERVED) and (f.tnum = RW_NULL)) then begin

    if f.ttype = IDENT then
      object_id_num := f.tnum
    else
      object_id_num := 0;

    if not declare_object(f, the_obj_ptr) then begin
      KeepLooking := FALSE;
      success := FALSE
    end
    else begin
      the_obj_ptr^.inherited_from := type_index;
      ptr_to_obj := the_obj_ptr;
{ Special case:  a nameless object does not need to be classified as
  anything since it has no name to classify. }
      if object_id_num = 0 then
        append_to_xarray(Object_list, ptr_to_obj)
      else begin
        obj_index := classify_as(f, object_id_num, OBJECT_ID, ptr_to_obj);
        if obj_index <> Object_List.size then begin
          if obj_index <> 0 then
            error_message(f, 'Internal identifier table out of sync!');
          KeepLooking := FALSE;
          success := FALSE
        end
      end;

{ Have we just put away the Main Object? }
      if object_id_num = 2 then
        MainObject := Object_List.size

    end

  end
  else begin
    expect_general(f, 'name of new object');
    success := FALSE
  end;

  instantiate := success

end;  { instantiate }



{ dump_game

Description:
  Dumps the entire game to the given output file.

Arguments:
  outfile (IN)      -- name of file to write to

}

function dump_game(outfile: string): boolean;

  var
    f_out     : file;
    i         : integer;
    ch        : char;
    success   : boolean;
    right_now : timestamp_type;

begin

  assign(f_out, outfile);
{$I-}
  rewrite(f_out, 1);
{$I+}
  if IOResult <> 0 then
    success := FALSE
  else begin

{ Visible version information for incautious "type"ing }
    for i := 1 to length(VERSION) do
      BlockWrite(f_out, VERSION[i], 1);
    ch := chr(10); BlockWrite(f_out, ch, 1);
    ch := chr(13); BlockWrite(f_out, ch, 1);
    ch := chr(26); BlockWrite(f_out, ch, 1);        { EOF }

{ Internal version information }
    BlockWrite(f_out, VERSION_NUM, SizeOf(VERSION_NUM));

{ Encryption information }
    BlockWrite(f_out, Encryption, SizeOf(Encryption));

{ Time stamp the file }
    get_time_stamp(right_now);
    BlockWrite(f_out, right_now, SizeOf(right_now));

{ Prepare for proper encryption based on the time stamp }
    cryptinit(Encryption, right_now);

{ Write the starting object }
    BlockWrite(f_out, MainObject, SizeOf(MainObject));

    dump_obj_list(f_out, Object_List);
    dump_obj_list(f_out, Type_List);
    dump_text_list(f_out, Literals);
    dump_text_list(f_out, Vocabulary);

{ display_undefined is TRUE if any undefined identifiers exist }
    success := not display_undefined;

    if success and (Encryption = DEBUGGING_ON) then begin
        writeln('Adding debugging information');
        dump_id_info(f_out)
    end;

  end;

  close(f_out);
  dump_game := success

end;  { dump_game }



{ syntax_stream

Description:
  Performs the base-level source code checking; the entry point of the
  syntactic analyzer.  As the name suggests, it uses get_token to
  stream through the source code and direct the flow of control.

  The syntactic and semantic analyzers are closely knit; the syntactic
  procedures call the appropriate semantic ones when necessary.

Arguments:
  acl_file (IN) --      the name of the input file.

Returns:
  TRUE if the given unit was successfully created; FALSE otherwise.

BNF:  <program> ::= <declaration>*
      <declaration> ::= <defclass> | <instantiate> | <include>


}

function syntax_stream(acl_file: string; includeFile: boolean): boolean;

var
  source  : progfile;
  success : boolean;
  more    : boolean;
  p       : pointer;

begin

  if includeFile then
    success := open_includefile(source, acl_file)
  else
    success := open_progfile(source, acl_file);

  if not success then begin
    writeln('Could not find ', acl_file);
    KeepLooking := FALSE;
    syntax_stream := FALSE;
    exit
  end;

  while success and get_token(source) do begin

    write (acl_file, ' (', source.file_line, ')');
    ClrEol; write(chr(13));

    case source.ttype of

      RESERVED:
        case source.tnum of
          RW_TYPE, RW_CLASS:
            success := define_type(source);
          RW_NULL:
            success := instantiate(source, 0);
          RW_INCLUDE:
            if (not get_token(source)) or
               (source.ttype <> TEXT_LIT) then begin
              error_message(source,
                            'Must follow "include" with name of file');
              KeepLooking := FALSE;
              success := FALSE
            end
            else if index_xarray(Literals, source.tnum, p) then
              success :=
                syntax_stream(DOSname(string_ptr(p)^,
                                      'ACH',
                                      FALSE),
                              TRUE);
          RW_KEYWORD:
            if (not get_token(source)) or
               (source.ttype <> IDENT) then begin
              error_message(source,
                      'Must follow "keyword" with one or more identifiers');
              success := FALSE
            end
            else begin
              success := classify_as(source, source.tnum,
                                     ENUMERATE_ID, nil) <> 0;
              if success and get_token(source) then begin
                more := (source.ttype = PUNCTUATION) and
                        (source.tnum  = ord(','));
                while success and more do begin
                  if get_token(source) and (source.ttype = IDENT) then begin
                    success := classify_as(source, source.tnum,
                                           ENUMERATE_ID, nil) <> 0;
                    more := get_token(source) and
                            (source.ttype = PUNCTUATION) and
                            (source.tnum  = ord(','))
                  end
                  else begin
                    success := FALSE;
                    expected(source, IDENT, -1)
                  end
                end;        { while }
{ The algorithm depends on over-reading by one token }
                source.consumed := FALSE
              end
            end
          else begin
            expected(source, RESERVED, RW_TYPE);
            success := FALSE
          end
        end;  { case }

      IDENT:
        success := instantiate(source, source.tnum);
      else begin
        error_message(source,
                      'Need a type declaration or object instantiation');
        KeepLooking := FALSE;
        success := FALSE
      end

    end  { case }

  end;  { while }

  write (acl_file, ' (', source.file_line, ')');
  ClrEol; writeln;
  close_progfile(source);
  syntax_stream := success

end;  { syntax_stream }


begin

  IncludePath := '';         { let CREATE help us out }
  MainObject  := 1           { start at the top if no main found }

end.  { unit syntax }
