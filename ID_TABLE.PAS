{ ID_TABLE.PAS

Description:
  Contains the necessary data structures and functions for adding to
  and referring to the ID table (a very busy little structure).

  The ID table is a 27-element hash table with one bucket for each
  letter; identifiers are hashed according to their first letter.
  The last bucket is for identifiers beginning with an underscore.
  The ID table is cross_indexed by an xarray containing pointers
  to id_records.
  The ID table is complex enough that it should probably not be
  accessed directly but rather only through its procedures.  In
  this way the data type, its primary instantiation, and associated
  code comprise one stand-alone module which must be "used" by
  any module wishing to modify or query the table.

}

unit id_table;

interface

  uses misc, xarray;

  const
    BUCKETS = 27;               { 1 per letter of alphabet,
                                  plus the underscore }

  type

    id_rec_ptr = ^id_rec_type;
    id_rec_type =
      record
        id_kind    : classify_type;
        id_integer : integer;        { What integer the ID gets written as }
        id_index   : integer;        { The ID's index in the ID table }
        id_name    : string_ptr;
        next       : id_rec_ptr
      end;

{ Functions and procedures }
  function add_ident(var id_str: string): integer;
  function index_ident(index: integer; var id_ptr: id_rec_ptr): boolean;

  var
    DefaultClassification : classify_type;

implementation

{ Static variables - global to this module }
  var
    hash: array[1..BUCKETS] of id_rec_ptr;
    h_index: xarray_type;


{ add_ident

Description:
  Adds the given identifier to the ID table, and returns its index.
  There are no duplications; if the identifier already exists, its
  existing index is returned.

Arguments:
  id_str (IN) --        string containing identifier name

Returns:
  The index of the identifier.

}

function add_ident(var id_str: string): integer;

  var
    hasher     : integer;
    p, new_rec : id_rec_ptr;

begin

  hasher := ord(upcase(id_str[1])) - 64;   { A..Z => 65..90 => 1..26 }
  if (hasher < 1) or (hasher > 26) then hasher := 27;
  p := hash[hasher];
  while (p^.next <> nil) and (p^.next^.id_name^ < id_str) do
    p := p^.next;
  if (p^.next = nil) or (p^.next^.id_name^ > id_str) then begin
    new(new_rec);
    append_to_xarray(h_index, new_rec);
    with new_rec^ do begin
      id_kind    := DefaultClassification;
      id_index   := h_index.size;
      id_integer := id_index;
      id_name    := NewConstStr(id_str);
      next := p^.next
    end;
    p^.next := new_rec;
    add_ident := h_index.size
  end
  else                                 { found existing identifier }
    add_ident := p^.next^.id_index

end;  { add_ident }



{ index_ident

Description:
  A quick little wrapper to the index_xarray function.

Arguments:
  index (IN)   --    number of the identifier
  id_ptr (OUT) --    pointer to the id_record for that identifier

Returns:
  TRUE if the requested identifier exists in the table; FALSE otherwise.

}

function index_ident(index: integer; var id_ptr: id_rec_ptr): boolean;

  var
    p: pointer;

begin

  index_ident := index_xarray(h_index, index, p);
  id_ptr := p

end;  { index_ident }


{ Initializations }

var i: integer;

begin

  for i := 1 to BUCKETS do begin
    new(hash[i]);
    hash[i]^.next := nil
  end;
  new_xarray(h_index);

  DefaultClassification := ENUMERATE_ID

end.
