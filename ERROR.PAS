{ ERROR.PAS

  Description:
    Writes out all kinds of compile-time errors.  Does not perform
    a halt; expects the program itself to "unravel" the process.

}

unit error;

interface

  uses misc, keywords, token;

{ Functions and Procedures }
  procedure hit_eof(var f: progfile; expecting: acl_type; specific:integer);
  procedure expected(var f: progfile;
                     expect_ttype: acl_type; expect_specific: integer);
  procedure expect_general(var f: progfile;
                           general_desc: string);
  procedure error_message(var f: progfile; message: string);
  function insist_on(var f: progfile;
                      some_type: acl_type; some_number: integer): boolean;


implementation


procedure hit_eof(var f: progfile; expecting: acl_type; specific: integer);

begin

  if KeepLooking then begin
    KeepLooking := FALSE;
    write('Found end of file; expected ');
    write_token(expecting, specific);
    writeln
  end

end;



procedure expected(var f: progfile;
                   expect_ttype: acl_type; expect_specific: integer);

begin

  if KeepLooking then begin
    source_pos(f);
    write('Expected ');
    write_token(expect_ttype, expect_specific);
    write('; found ');
    write_token(f.ttype, f.tnum);
    writeln
  end

end;  { expected }



procedure expect_general(var f: progfile;
                         general_desc: string);

begin

  if KeepLooking then begin
    source_pos(f);
    write('Expected ');
    write(general_desc, '; found ');
    write_token(f.ttype, f.tnum);
    writeln
  end

end;  { expected }



procedure error_message(var f: progfile; message: string);

begin

  if KeepLooking then begin
    source_pos(f);
    writeln(message)
  end

end;



{ insist_on

Description:
  Used when a particular token is insisted upon by the syntax, usually
  for readability.  It will be an error for the token not to exist.

}

function insist_on(var f: progfile;
                    some_type: acl_type; some_number: integer): boolean;

begin
  if not get_token(f) then begin
    hit_eof(f, some_type, some_number);
    insist_on := FALSE
  end
  else if (f.ttype <> some_type) and (f.tnum <> some_number) then begin
    expected(f, some_type, some_number);
    KeepLooking := FALSE;
    insist_on := FALSE
  end
  else
    insist_on := TRUE

end;  { insist_on }


end.  { unit error }
