{ GAMESTAT.PAS

Description:
  Functions and procedures that help with the saving and loading of
  game states.  Only the attribute records of a given object list are ever
  saved or loaded; statements and other object information, such as
  the Dynamic pointer, are really constant across a game; as long as
  we know that the game states belong to a particular game, we don't
  need to save any more.

}

unit gamestat;


interface

  uses misc, crypt, linklist, xarray, stmt, saveload, timestmp, intrptr;

  procedure save_game_state(var bfile: file; objects: xarray_type);
  function load_game_state(var bfile: file; var objects: xarray_type) : boolean;

implementation

procedure save_game_state(var bfile: file; objects: xarray_type);

  var
    i: integer;
    p: pointer;

begin

{ Write out the timestamp associated with the original game. }

  BlockWrite(bfile, GTimeStamp, SizeOf(GTimeStamp));

{ Get the encryption straight - reset the seed }
  cryptinit(Encryption, GTimeStamp);

  for i := 1 to Dynamic - 1 do
    if index_xarray(objects, i, p) then
      with object_ptr(p)^ do begin
        BlockWrite(bfile, vContSeq, SizeOf(vContSeq));
        dump_item_list(bfile, attributes, EXPR_LIST)
      end;

  for i := Dynamic to objects.size do
    if index_xarray(objects, i, p) then begin
      BlockWrite(bfile, vContSeq, SizeOf(vContSeq));
      dump_object(bfile, object_ptr(p))
    end;

  BlockWrite(bfile, vEndSeq, SizeOf(vEndSeq))

end;  { save_game_state }



function load_game_state(var bfile: file; var objects: xarray_type) : boolean;

  var
    i: integer;
    p: pointer;
    op: object_ptr;

    tstamp : timestamp_type;

    sentinel: stmt_kind;

begin

{ Check the time stamp }

  BlockRead(bfile, tstamp, SizeOf(tstamp));
  if tstamp <> GTimeStamp then begin
    writeln('State file does not match original .ACX file');
    load_game_state := FALSE
  end
  else begin

  { Get the encryption straight - reset the seed.  Be careful upon loading
    since we have to do UNPURPLE instead of PURPLE. }
    if Encryption = PURPLE then Encryption := UNPURPLE;
    cryptinit(Encryption, GTimeStamp);

  { Need to flush out the previous attributes and load in the new ones.
    Dynamically allocated objects are a little different since they might
    vary between game states. }

    for i := 1 to Dynamic - 1 do
      if index_xarray(objects, i, p) then begin
        BlockRead(bfile, sentinel, SizeOf(sentinel));
        with object_ptr(p)^ do begin
          dispose_item_list(attributes, EXPR_LIST);
          load_item_list(bfile, attributes, EXPR_LIST)
        end
      end;

  { Flush dynamic objects.  Dispose of each object and shrink back the
    xarray. }

    for i := objects.size downto Dynamic do begin
      if index_xarray(objects, i, p) then begin
        op := object_ptr(p);
        dispose_object(op)
      end;
      shrink_xarray(objects)
    end;

  { sentinel has been set from before }

    BlockRead(bfile, sentinel, SizeOf(sentinel));
    while sentinel = CONT_SEQ do begin
      load_object(bfile, op);
      p := op;
      append_to_xarray(objects, p);
      BlockRead(bfile, sentinel, SizeOf(sentinel))
    end;

  if Encryption = UNPURPLE then Encryption := PURPLE;

  load_game_state := TRUE

  end  { else }

end;  { load_game_state }


end.
