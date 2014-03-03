{ CREATE.PAS

The translator for an Archetype program.

Usage:
  CREATE [(/E=(None|Simple|Complex) | /D )] [/K] [/A] source-code [/O=binary-code]

}

program create(input, output);

uses
  misc, crypt, id_table, semantic, syntax;

var

  name, infile, outfile : string;

  option : string;
  i, j   : integer;
  f      : progfile;        { dummy progfile to help out classify_as }
  f_out  : file;            { pointer to .ACX file }

begin

  writeln(VERSION);

  name := ''; infile := ''; outfile := '';
  if ParamCount = 0 then begin
    writeln('Copyright 1995 Derek T. Jones');
    writeln;
    writeln('Usage:');
    writeln('CREATE [(/E=(N|S|D|C) | /D)] [/K] [/A] source-code [/O=binary-code]');
    writeln;
    writeln('/E=encryption None(default), Simple, Dynamic, or Complex');
    writeln('/D add Debugging information');
    writeln('/K insist on Keywords being declared');
    writeln('/A report All errors (until fatal syntax error encountered)');
    writeln('/O=.ACX file name (source-code.ACX by default)');
    halt
  end;

  for i := 1 to ParamCount do begin
    option := ParamStr(i);
    for j := 1 to length(option) do option[j] := upcase(option[j]);
    if option[1] <> '/' then begin
      if name = '' then
        name := option
      else
        writeln('Cannot specify more than one input file - ignoring others')
    end
    else if option[2] in ['E', 'O'] then begin
      if option[3] <> '=' then
        writeln('"', option[2], '" must have "=" followed by value')
      else
        case option[2] of
          'O' : outfile := DOSname(Copy(option, 4, length(option)),
                                   'ACX', FALSE);
          'E' :
            case option[4] of
              'N' : Encryption := NONE;
              'S' : Encryption := SIMPLE;
              'D' : Encryption := PURPLE;
              'C' : Encryption := COMPLEX;
              else
                writeln('Unrecognized encryption "', option[4], '"');
            end
        end
    end
    else
      case option[2] of
        'D' : Encryption := DEBUGGING_ON;
        'K' : DefaultClassification := UNDEFINED_ID;
        'A' : AllErrors := TRUE;
        else
          writeln('Unrecognized option ''/', option[2], '''');
      end
  end;        { Parameter loop }

{ Use the pathname of the CREATE program as the location of include
  files not located in the current directory.  Need to back up to
  the last slash. }
  IncludePath := ParamStr(0);
  i := length(IncludePath);
  while (i > 0) and not (IncludePath[i] in ['\', '/', ':']) do dec(i);
  if i <= 0 then
    IncludePath := ''
  else
    IncludePath := Copy(IncludePath, 1, i);

  if infile = ''  then infile   := DOSname(name, 'ACH', FALSE);
  if outfile = '' then outfile  := DOSname(name, 'ACX', TRUE);

{ Set up the special "system" and "main" identifiers }
  name := 'system';
  if not ((add_ident(name) = 1) and
          (classify_as(f, 1, OBJECT_ID, nil) = 0)) then begin
    writeln('Internal error: cannot initialize identifier table');
    halt
  end;

  name := 'main';
  if not (add_ident(name) = 2) then begin
    writeln('Internal error: cannot initialize identifier table');
    halt
  end;

  writeln('Translating ', infile, ' to ', outfile, ' :');
  if not syntax_stream(infile, FALSE) then
    writeln('Could not translate ', infile)
  else begin
    write('Writing ', outfile);
    case Encryption of
      SIMPLE:
        write(' using simple encryption');
      PURPLE:
        write(' using self-referential (dynamic) encryption');
      COMPLEX:
        write(' using pseudorandom (complex) encryption');
    end;  { case }
    writeln;
    if not dump_game(outfile) then
      writeln('Could not write ', outfile)
    else
      writeln(infile, ' translated successfully.')
  end

end.
