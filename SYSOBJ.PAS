{ SYSOBJ.PAS

Description:
  Routines, types, and variables which comprise the "system" object
  of Archetype.

}

unit sysobj;

interface

  uses
    misc, linklist, keywords, expr, wrap, intrptr,
    parser, gamestat, heapsort;

  procedure send_to_system(transport: shortint; var strmsg: string;
                           var result: result_type; var context: context_type);

implementation

  type
    sys_state_type = (IDLING,
                      INIT_SORTER, OPEN_SORTER, CLOSE_SORTER, NEXT_SORTED,
                      PLAYER_CMD, NORMALIZE, ABBR,
                      OPEN_PARSER, VERB_LIST, NOUN_LIST, CLOSE_PARSER,
                      INIT_PARSER, WHICH_OBJECT,
                      ROLL_CALL, PRESENT, PARSE, NEXT_OBJECT,
                      DEBUG_MESSAGES, DEBUG_EXPRESSIONS,
                      DEBUG_STATEMENTS,
                      DEBUG_MEMORY, FREE_MEMORY,
                      SAVE_STATE, LOAD_STATE);

  const
    StateLookup: array[IDLING..LOAD_STATE] of string =
                     ('IDLING',
                      'INIT SORTER', 'OPEN SORTER', 'CLOSE SORTER',
                         'NEXT SORTED',
                      'PLAYER CMD', 'NORMALIZE', 'ABBR',
                      'OPEN PARSER', 'VERB LIST', 'NOUN LIST', 'CLOSE PARSER',
                      'INIT PARSER', 'WHICH OBJECT',
                      'ROLL CALL', 'PRESENT', 'PARSE', 'NEXT OBJECT',
                      'DEBUG MESSAGES', 'DEBUG EXPRESSIONS',
                      'DEBUG STATEMENTS',
                      'DEBUG MEMORY', 'FREE MEMORY',
                      'SAVE STATE', 'LOAD STATE');

{ Global variables which retain the state of the system object between
  calls. }

  var
    sys_state   : sys_state_type;
    target_list : target_list_type;



function figure_state(var s : string) : boolean;

  var  st : sys_state_type;

begin

  for st := IDLING to LOAD_STATE do
    if StateLookup[st] = s then begin
      sys_state := st;
      figure_state := TRUE;
      exit
    end;

  figure_state := FALSE

end;



{ send_to_system

Description:
  Is the receiver of all "system calls" and the only object that receives
  messages in the form of strings rather than message constants.

Notes:
  Uses a global variable called sys_state to keep track of its state
  between calls.

}

procedure send_to_system(transport: shortint; var strmsg: string;
                         var result: result_type; var context: context_type);

  var
    the_caller, the_message: integer;
    obj_index: integer;
    nomatch: string;
    st: sys_state_type;
    np: node_ptr;
    p : pointer;
    stfile: file;

begin

  if transport = OP_SEND then
    the_caller := context.self
  else
    the_caller := context.sender;

  repeat

    cleanup(result);

    case sys_state of
      IDLING: begin
        if figure_state(strmsg) then
          case sys_state of
            PLAYER_CMD, ABBR, SAVE_STATE, LOAD_STATE,
            OPEN_PARSER, OPEN_SORTER, WHICH_OBJECT:
              exit;                         { come back again! }
            INIT_SORTER: begin
              reinit_heap;
              sys_state := OPEN_SORTER;
              exit
            end;
            INIT_PARSER: begin
              new_parse_list;
              sys_state := OPEN_PARSER;
              exit
            end;
          end  { case }
      end;
      PLAYER_CMD: begin
        normalize_string(strmsg, Command);
        sys_state := IDLING
      end;
      NORMALIZE: begin              { last normalized command }
        with result do begin
          kind := STR_PTR;
          acl_str := NewDynStr(Command)
        end;
        sys_state := IDLING
      end;
      ABBR: begin
        with result do begin
          kind := STR_PTR;
          acl_str := NewDynStr(strmsg)
        end;
        if convert_to(NUMERIC, result) then
          Abbreviate := result.acl_int
        else begin
          wraperr('Warning: non-numeric abbreviation message sent to system');
          cleanup(result)
        end;
        sys_state := IDLING
      end;
      OPEN_PARSER: begin
        if figure_state(strmsg) then
          case sys_state of
            CLOSE_PARSER:
              sys_state := IDLING;
            VERB_LIST: begin
              target_list := PARSER_VERBLIST;
              sys_state := OPEN_PARSER
            end;
            NOUN_LIST: begin
              target_list := PARSER_NOUNLIST;
              sys_state := OPEN_PARSER
            end;
          end  { case }
        else
          add_parse_word(target_list, strmsg, the_caller);
        exit
      end;
      OPEN_SORTER: begin
        if figure_state(strmsg) then
          case sys_state of
            CLOSE_SORTER:
              sys_state := IDLING;
          end
        else
          drop_str_on_heap(strmsg);
        exit
      end;
      NEXT_SORTED: begin
        if not pop_heap(p) then
          cleanup(result)
        else with result do begin
          kind    := STR_PTR;
          acl_str := p
        end;
        sys_state := IDLING
      end;
      WHICH_OBJECT: begin
        obj_index := find_object(strmsg);
        if obj_index <> 0 then
          with result do begin
            kind       :=    IDENT;
            ident_kind := OBJECT_ID;
            ident_int  := obj_index
          end;
        sys_state := IDLING
      end;
      ROLL_CALL: begin
        dispose_list(Proximate);
        new_list(Proximate);
        sys_state := IDLING
      end;
      PRESENT: begin
        new(np);
        with np^ do begin
          data := nil;
          key := the_caller
        end;
        insert_item(Proximate, np);
        sys_state := IDLING
      end;
      PARSE: begin
        parse_sentence;
        sys_state := IDLING
      end;
      NEXT_OBJECT: begin
        if not pop_object(obj_index, nomatch) then
          cleanup(result)
        else if obj_index < 0 then
          with result do begin
            kind := STR_PTR;
            acl_str := NewDynStr(nomatch)
          end
        else
          with result do begin
            kind := IDENT;
            ident_kind := OBJECT_ID;
            ident_int := obj_index
          end;
        sys_state := IDLING
      end;
      DEBUG_MESSAGES: begin
        Debug := Debug XOR DEBUG_MSGS;
        sys_state := IDLING
      end;
      DEBUG_EXPRESSIONS: begin
        Debug := Debug XOR DEBUG_EXPR;
        sys_state := IDLING
      end;
      DEBUG_STATEMENTS: begin
        Debug := Debug XOR DEBUG_STMT;
        sys_state := IDLING
      end;
      DEBUG_MEMORY: begin
        wrapout('', TRUE);          { get to beginning of line }
        writeln('Maximum memory request: ', MaxAvail, ' bytes');
        writeln('Actual free memory:     ', MemAvail, ' bytes');
        sys_state := IDLING
      end;
      FREE_MEMORY: begin
        with result do begin
          kind    := NUMERIC;
          acl_int := MemAvail
        end;
        sys_state := IDLING
      end;
      SAVE_STATE, LOAD_STATE: begin
        assign(stfile, strmsg);
{$I-}
        if sys_state = SAVE_STATE then
          rewrite(stfile, 1)
        else
          reset(stfile, 1);
{$I+}
        if IOResult <> 0 then begin
          writeln('Error opening ', strmsg);
          cleanup(result)
        end
        else begin
          result.kind := RESERVED;
          if sys_state = SAVE_STATE then begin
            save_game_state(stfile, Object_List);
            result.keyword := RW_TRUE
          end
          else if load_game_state(stfile, Object_List) then
            result.keyword := RW_TRUE
          else
            result.keyword := RW_FALSE;
          close(stfile)
        end;
        sys_state := IDLING
      end;
    end  { case }

  until sys_state = IDLING

end;  { send_to_system }


begin

  sys_state := IDLING

end.  { unit sysobj }
