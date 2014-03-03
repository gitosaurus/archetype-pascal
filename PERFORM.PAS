{ PERFORM.PAS

The Archetype interpreter.

}


program perform(input, output);

uses
  misc, archsys;

var
  name, infile: string;
  i: integer;

begin

  if ParamCount = 0 then begin
    write('Name of .ACX file? ');
    readln(name)
  end
  else begin
    if ParamCount > 1 then
      writeln('Ignoring extra command-line parameters');
    name := ParamStr(1)
  end;

  infile := DOSname(name, 'ACX', FALSE);

{  Debug := Debug or DEBUG_BYTES; }
  interpret(infile)

end.
