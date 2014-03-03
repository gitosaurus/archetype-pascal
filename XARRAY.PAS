{ XARRAY.PAS

Description:
  Contains the type definitions and operators for an "extendable array"
  data structure - a "chunked linked list".  This list will be circular
  so that append operations are O(1).
  Indexing operations will be O(N/c) where N is the number of elements
  and c is the chunk size.
  Search operations will be somewhat more difficult to implement in
  an optimized fashion.

}

unit xarray;

interface

  uses misc;

  const
    CHUNK_SIZE = 128;

  type

    chunk_array = array[0 .. CHUNK_SIZE - 1] of pointer;
    chunk_ptr = ^chunk_node;
    chunk_node =
      record
        data: chunk_array;
        next: chunk_ptr
      end;

    xarray_type =     { actually a "header" node }
      record
        size: integer;
        start: chunk_ptr
      end;

    access_type = (POKE_ACCESS, PEEK_ACCESS);

{ Procedures and Functions }
  procedure new_xarray(var the_xarray: xarray_type);
  procedure dispose_xarray(var the_xarray: xarray_type);
  procedure append_to_xarray(var the_xarray: xarray_type; element: pointer);
  function access_xarray(var the_xarray: xarray_type; index: integer;
                         var result: pointer;
                         direction : access_type): boolean;
  function index_xarray(var the_xarray: xarray_type; index: integer;
                        var result: pointer): boolean;
  procedure shrink_xarray(var the_xarray: xarray_type);


implementation


{ new_xarray

Description:
  The constructor.

Arguments:
  the_xarray (OUT)      -- the array to be "refreshed"

}

procedure new_xarray(var the_xarray: xarray_type);

begin

  with the_xarray do begin
    size := 0;
    start := nil
  end

end;  { new_xarray }



{ dispose_xarray

Description:
  The destructor for the class.  Calls to this procedure must be followed
  by a call to new_xarray in order to use the same xarray again.

Arguments:
  the_xarray (IN/OUT)   -- the xarray whose memory needs to be deallocated.

}

procedure dispose_xarray(var the_xarray: xarray_type);

  var
    index, axe: chunk_ptr;

begin

  if the_xarray.start <> nil then begin
    index := the_xarray.start^.next;
    while index <> the_xarray.start do begin
      axe := index;
      index := index^.next;
      add_bytes(-SizeOf(axe^));
      dispose(axe)
    end;
    add_bytes(-SizeOf(index^));
    dispose(index)
  end;
  with the_xarray do begin
    size := 0;
    start := nil
  end

end;  { dispose_xarray }



{ append_to_xarray

Description:
  An O(1) appending of an element to an xarray.

Arguments:
  the_xarray (IN/OUT)       -- xarray to be appended to
  element (IN)              -- pointer to element to be appended

}

procedure append_to_xarray(var the_xarray: xarray_type; element: pointer);

  var
    new_chunk_ptr: chunk_ptr;
    inner_index: integer;

begin

  with the_xarray do begin
    inner_index := size mod CHUNK_SIZE;
    if inner_index = 0 then begin   { add new chunk }
      new(new_chunk_ptr);
      add_bytes(SizeOf(new_chunk_ptr^));
      if start = nil then
        new_chunk_ptr^.next := new_chunk_ptr
      else begin
        new_chunk_ptr^.next := start^.next;
        start^.next := new_chunk_ptr
      end;
      start := new_chunk_ptr
    end;
    start^.data[inner_index] := element;   { store the element }
    inc(size)                              { increment size AFTERWARD }
  end

end;  { append_to_xarray }



{ access_xarray

Description:
  Accesses the <index>th element of the given xarray.

Arguments:
  the_xarray (IN) --            xarray to be indexed
  index (IN) --                 number of the element in the xarray
  result (IN/OUT) --            holds the value of the element
  direction (IN) --             if POKE_ACCESS, indicates that the
                                accessed element should be replaced by
                                <result>; otherwise, <result> should
                                replace the element.

Returns:
  TRUE if the xarray was successfully indexed; FALSE if the index was
  out of range.

}

function access_xarray(var the_xarray: xarray_type; index: integer;
                      var result: pointer; direction : access_type): boolean;

  var
    i: integer;
    ptr_index: chunk_ptr;

begin

  with the_xarray do
    if (index > size) or (index < 1) then
      access_xarray := FALSE
    else begin
      dec(index);                       { to normalize it }
      ptr_index := start^.next;         { first element }
      for i := 1 to (index div CHUNK_SIZE) do
        ptr_index := ptr_index^.next;
      if direction = POKE_ACCESS then
        ptr_index^.data[index mod CHUNK_SIZE] := result
      else
        result := ptr_index^.data[index mod CHUNK_SIZE];
      access_xarray := TRUE
    end

end;  { access_xarray }



{ index_xarray

Description:
  Passes back the element of the xarray at the given index.

Arguments:
  the_xarray (IN) --            xarray to be indexed
  index (IN) --                 number of the element in the xarray
  result (OUT) --               holds the value of the element

Returns:
  TRUE if the xarray was successfully indexed; FALSE if the index was
  out of range.

}

function index_xarray(var the_xarray: xarray_type; index: integer;
                      var result: pointer): boolean;

  var
    i: integer;
    ptr_index: chunk_ptr;

begin

  index_xarray := access_xarray(the_xarray, index, result, PEEK_ACCESS)

end;  { index_xarray }



{ shrink_xarray

Description:
  Deletes the last element from the given xarray.  The case of the
  inner index being well within a chunk is simple; the boundary condition
  is much more complex.  Is effectively the inverse of append_xarray.
  It hopes you have disposed of whatever the pointer is pointing to
  before you shrink the xarray.

}

procedure shrink_xarray(var the_xarray: xarray_type);

  var
    inner_index : integer;
    ptr_index : chunk_ptr;

begin

  with the_xarray do
    if size > 0 then begin
      inner_index := (size - 1) mod CHUNK_SIZE;
      start^.data[inner_index] := nil;               { deleted }
      if inner_index = 0 then begin                  { must de-chunk }
{ Need to chase around the linked list to find the
  node just before the start node. }
        ptr_index := start;
        while ptr_index^.next <> start do
          ptr_index := ptr_index^.next;
        ptr_index^.next := start^.next;
        add_bytes(-Sizeof(start^));
        dispose(start);
        start := ptr_index
      end;
      dec(size);
      if size = 0 then the_xarray.start := nil
    end

end;  { shrink_xarray }


end.  { unit xarray }
