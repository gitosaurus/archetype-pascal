{ XSTRING.PAS

Description:
  An "extended string" suitable for Archetype.  Uses reference counting
  and copy-on-write semantics for efficiency; extends itself if necessary,
  up to the range of a two-byte unsigned integer.

}

unit xarray;

interface

  uses misc;

  type

    ref_type =
      record
        references : integer;
        allocation : integer;
        data       : pointer
      end;

    xstring_type =
      record
        length     : integer;       { both in units of bytes }
        reference  : ^ref_type
      end;

{ Procedures and Functions }
  procedure new_xstring(var the_xstring: xstring_type);
  procedure dispose_xstring(var the_xstring: xstring_type);

  procedure concat_xstring(var the_xstring: xstring_type;
                            var extra_xstring: xstring_type;
                            var out_xstring: xstring_type);

  procedure copy_xstring(var destination: xstring_type;
                            var source: xstring_type);
  procedure assign_xstring(var destination: xstring_type;
                            var source: xstring_type);

{ Special operations for efficient Archetype access }
  procedure leftfrom_xstring(var the_xstring: xstring_type;
                            leftfrom: integer;
                            var output_xstring: xstring_type);
  procedure rightfrom_xstring(var the_xstring: xstring_type;
                            rightfrom: integer;
                            var output_xstring: xstring_type);
  function within_xstring(var the_xstring: xstring_type;
                            var substring: xstring_type): integer;

{ Interfacing with regular strings }
  procedure import_string(var the_xstring: xstring_type; strdata: string);
  procedure export_string(var the_xstring: xstring_type; var strdata: string);                                var strdata: string);
  procedure export_substring(var the_xstring: xstring_type;
                                start, length: integer;
                                var strdata: string);

implementation

{ Constants having to do with memory chunk size, to prevent heap
  fragmentation.  Chosen to match a DOS memory paragraph. }
const
  CHUNK_SIZE = 15;
  CHUNK_MASK = $FFF0;

type byte_mask = array[1..65536] of character;



{ strmem_alloc

Description:
  Allocates memory on a nice paragraph boundary.

}

function strmem_alloc(size: integer; var newsize): pointer;

  var
    p: pointer;

begin

  newsize = (size + CHUNK_SIZE) and CHUNK_MASK;
  GetMem(p, newsize);
  strmem_alloc := p

end;



procedure strmem_free(p: pointer; size: integer);

begin

  FreeMem(p, size)

end;



{ new_xstring

Description:
  The constructor.

Arguments:
  the_xstring (OUT)      -- the array to be constructed

}

procedure new_xstring(var the_xstring: xstring_type);

begin

  with the_xstring do begin
    length     := 0;
    new(reference);
    with (reference^) do begin
      references := 0;
      allocation := 0;
      data       := nil
    end
  end

end;  { new_xstring }



{ dispose_xstring

Description:
  The destructor for the class.  Calls to this procedure must be followed
  by a call to new_xstring in order to use the same xstring again.

Arguments:
  the_xstring (IN/OUT)   -- the xstring whose memory needs to be deallocated.

}

procedure dispose_xstring(var the_xstring: xstring_type);

begin

  with the_xstring do begin
    with reference^ do begin
      dec(references);
      if (references = 0) then
        strmem_free(data, allocation)
    end;
    dispose(reference);
    reference := nil;
    length    := 0
  end

end;  { dispose_xstring }





end.  { unit xstring }
