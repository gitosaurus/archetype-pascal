{ LINKLIST

  Description:
    Implements a simple linked list type and a number of
    convenient operators.

    Is a circular linked-list with an internal structure similar
    to the xarray structure (i.e. data is only a general pointer
    and interpretation is left up to the using module).  In this
    way appending is O(1).  Has a header node.

    The lists can be ordered; each node has both a data pointer and
    an integer called 'key'.  The interpretation of this integer is left
    up to the using module.  The only concern of LINKLIST is that
    insertions and lookups can be done in average O(N/2) if this
    field is used consistently.

    Advantage to xarray:  much less memory usage for small (< 32)
    lists, and the ability to insert in an ordered way.

}

unit linklist;

interface

  uses misc;

{ Type declarations }
  type

    node_ptr = ^node_type;

    list_type = node_ptr;

    node_type =
      record
        data : pointer;
        key  : integer;
        next : node_ptr
      end;

{ Procedures and Functions }
  procedure new_list(var the_list: list_type);
  procedure dispose_list(var the_list: list_type);
  function iterate_list(the_list: list_type; var index: node_ptr): boolean;
  procedure append_to_list(var the_list: list_type; the_node: node_ptr);
  function index_list(the_list: list_type; number: integer): node_ptr;
  procedure insert_item(the_list: list_type; the_item: node_ptr);
  function find_item(the_list: list_type; the_key: integer): node_ptr;


implementation


{ new_list

  Description:
    Allocates a header node and points it to itself.

  Arguments:
    the_list (IN/OUT) -- pointer to get new list
}

procedure new_list(var the_list: list_type);

begin

  new(the_list);
  add_bytes(SizeOf(the_list^));
  the_list^.next := the_list

end;  { new_list }



{ dispose_list

  Description:
    Throws away all the memory that makes up an entire list structure.
    Is a "shallow dispose"; i.e. only disposes of the structure, not
    the data.

  Arguments:
    the_list (IN/OUT) -- list to be disposed of

}

procedure dispose_list(var the_list: list_type);

  var
    the_node, axe: node_ptr;

begin

  the_node := the_list^.next;

  while the_node <> the_list do begin
    axe := the_node;
    the_node := the_node^.next;
    add_bytes(-SizeOf(axe^));
    dispose(axe)
  end;

  add_bytes(-SizeOf(the_list^));
  dispose(the_list);
  the_list := nil

end;  { dispose_list }



{ iterate_list

Description:
  Iterates through the given list.

Arguments:
  the_list (IN)  --     list to be iterated through
  index (IN/OUT) --     If nil, is a message IN to start iteration.
                        Otherwise, is a message OUT containg the node for
                                   this iteration.

Returns:
  TRUE if the list is not exhausted; FALSE if it is.

}

function iterate_list(the_list: list_type; var index: node_ptr): boolean;

begin

  if index = nil then           { begin iteration }
    index := the_list^.next
  else
    index := index^.next;

  iterate_list := (index <> the_list)

end;  { iterate_list }



{ append_to_list

Description:
  Efficient O(1) appending.

Arguments:
  the_list (IN/OUT) -- the list to be appended to.
  the_node (IN)     -- pointer to the new node.

Notes:
  Performs the "trick swap" of copying the new data into the header/trailer
  node and letting the new node become the new header/trailer.

}

procedure append_to_list(var the_list: list_type; the_node: node_ptr);

begin

  the_list^.data  := the_node^.data;
  the_list^.key   := the_node^.key;

  the_node^.next := the_list^.next;
  the_list^.next := the_node;

  the_list := the_node

end;  { append_to_list }



{ index_list

Description:
  Permits a linked list to be indexed like an array in O(N) time.

Arguments:
  the_list (IN) --      list to be indexed
  number (IN) --        the number of the node in the list to index

Returns:
  a pointer to the indexed node, if found; otherwise nil.

}

function index_list(the_list: list_type; number: integer): node_ptr;

  var i: integer;
      p: node_ptr;

begin

  p := the_list^.next;
  i := 1;
  while (i < number) and (p <> the_list) do begin
    p := p^.next;
    inc(i)
  end;
  if p = the_list then    { we know we didn't find it - back at header node }
    index_list := nil
  else
    index_list := p

end;  { index_list }



{ insert_item

Description:
  Ordered insert; average time O(N/2).  Inserts in descending order.

Arguments:
  the_list (IN/OUT)     -- list to be inserted into.
  the_item (IN)         -- pointer to the item to be inserted.

}

procedure insert_item(the_list: list_type; the_item: node_ptr);

  var
    p: node_ptr;

begin

  p := the_list;
  while (p^.next <> the_list) and (p^.next^.key > the_item^.key) do
    p := p^.next;

  the_item^.next := p^.next;
  p^.next := the_item

end;  { insert_item }



{ find_item

Description:
  Given a list and a key, finds the first item in the list corresponding
  to that key.  Expects that the elements have been sorted in descending
  order.

Arguments:
  the_list (IN)         -- list to search
  the_key (IN)          -- key to search for

Returns:
  If found, a pointer to the first node containing the key;
  if not, nil.

}

function find_item(the_list: list_type; the_key: integer): node_ptr;

  var p: node_ptr;

begin

  p := the_list^.next;
  while (p <> the_list) and (the_key < p^.key) do
    p := p^.next;
  if (p = the_list) or (the_key <> p^.key) then
    find_item := nil
  else
    find_item := p

end;  { find_item }


end.  { unit linklist }
