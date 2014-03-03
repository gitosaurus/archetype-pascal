{ HEAPSORT.PAS

The heapsort algorithm, for use with the Archetype interpreter.  It uses
an xarray as its heap.

}

unit heapsort;

interface

  uses misc, xarray;

  type
    heaptype = xarray_type;
    element  = pointer;

  var
    H : heaptype;


{ Functions and Procedures }
  function pop_heap(var e : element) : boolean;
  procedure drop_on_heap(e : element);
  procedure drop_str_on_heap(var s : string);
  procedure reinit_heap;

implementation

const
  CANT_PEEK = 'Internal error:  cannot peek into heap';
  CANT_POKE = 'Internal error:  cannot poke into heap';


function lighter(var one, two : element): boolean;

begin

  lighter := string_ptr(one)^ < string_ptr(two)^

end;



procedure heapup;

  var
    L, parent   : integer;
    Lp, parentp : element;
    temp        : element;

begin

  L := H.size;
  while L > 1 do begin
    if (L mod 2) = 0 then
      parent := L div 2
    else
      parent := (L - 1) div 2;
    if not (access_xarray(H, L, Lp, PEEK_ACCESS) and
            access_xarray(H, parent, parentp, PEEK_ACCESS)) then
      writeln(CANT_PEEK);
    if lighter(Lp, parentp) then begin
      temp := parentp;
      if not (access_xarray(H, parent, Lp, POKE_ACCESS) and
              access_xarray(H, L,    temp, POKE_ACCESS))
      then
        writeln(CANT_POKE);
      L := parent
    end
    else
      L := 0
  end

end;  { heapup }


procedure heapdown;

  var
    L, compare, lc, rc : integer;
    Lp       : element;
    lcp, rcp : element;
    comparep : element;
    temp     : element;

begin

  L := 1;
  while L < H.size do begin
    lc := L * 2;
    if lc > H.size then
      L := lc
    else begin
      rc := lc + 1;
      if not access_xarray(H, lc, lcp, PEEK_ACCESS) then
        writeln(CANT_PEEK);
      if (rc > H.size) then begin
        compare  := lc;
        comparep := lcp
      end
      else begin
        if not access_xarray(H, rc, rcp, PEEK_ACCESS) then
          writeln(CANT_PEEK);
        if lighter(lcp, rcp) then begin
          compare  := lc;
          comparep := lcp
        end
        else begin
          compare  := rc;
          comparep := rcp
        end
      end;
      if not access_xarray(H, L, lp, PEEK_ACCESS) then
        writeln(CANT_PEEK);
      if lighter(comparep, Lp) then begin
        temp := comparep;
        if not (access_xarray(H, compare, Lp, POKE_ACCESS) and
                access_xarray(H, L,     temp, POKE_ACCESS))
        then
          writeln(CANT_POKE);
        L := compare
      end
      else
        L := H.size + 1
    end
  end

end;  { heapdown }



function pop_heap(var e : element) : boolean;

  var
    temp : element;

begin

  if H.size < 1 then
    pop_heap := FALSE
  else begin
    if not (access_xarray(H, 1, e,   PEEK_ACCESS) and
            access_xarray(H, H.size, temp, PEEK_ACCESS) and
            access_xarray(H, 1,      temp, POKE_ACCESS))
    then
      writeln(CANT_PEEK);
    shrink_xarray(H);
    heapdown;
    pop_heap := TRUE
  end

end;



procedure drop_on_heap(e : element);

begin

  append_to_xarray(H, e);
  heapup

end;



procedure drop_str_on_heap(var s : string);

  var
    sp : string_ptr;
    p  : pointer;

begin

  sp := NewDynStr(s);
  p  := pointer(sp);
  drop_on_heap(p)

end;



procedure reinit_heap;

begin

  dispose_xarray(H);
  new_xarray(H)

end;



begin

  new_xarray(H)

end.
