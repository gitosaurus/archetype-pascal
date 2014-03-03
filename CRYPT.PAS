unit crypt;

interface

  type
    encryption_type = (NONE,
                       SIMPLE,
                       PURPLE, UNPURPLE,
                       COMPLEX,
                       DEBUGGING_ON);

  var
    CryptMask  : byte;
    Encryption : encryption_type;

  procedure cryptinit(crypt_kind : encryption_type; seed : longint);
  procedure cryptstr(var s : string);

implementation


procedure cryptinit(crypt_kind : encryption_type; seed : longint);

begin

  CryptMask := seed AND $FF;
  Encryption := crypt_kind;
  if Encryption = COMPLEX then RandSeed := seed

end;  { cryptinit }



{ cryptstr

Description:
  Encrypts or decrypts a string.  Since all encryption methods are based
  on XOR, the same method both encrypts and decrypts.
  If <method> is SIMPLE, the CryptMask is simply XORed with each byte in
  the string.
  If <method> is PURPLE, the CryptMask is changed each time after using it,
  by adding to it the lowest three bits of the result of the last encrypted
  byte.  This way the mask changes frequently and dynamically in a way that
  is difficult to predict.
  If <method> is UNPURPLE, the same algorithm as PURPLE is used except that
  the next CryptMask must be determined before altering the byte under
  consideration.
  if <method> is COMPLEX, a pseudorandom sequence is used to alter the
  CryptMask.  This can make prediction well-nigh impossible.

}

procedure cryptstr(var s : string);

  var
    nextmask : byte;
    i        : integer;

begin

  case Encryption of
    SIMPLE :
      for i := 1 to length(s) do
        s[i] := chr(ord(s[i]) XOR CryptMask);
    PURPLE:
      for i := 1 to length(s) do begin
        s[i] := chr(ord(s[i]) XOR CryptMask);
        inc(CryptMask, ord(s[i]) AND $7)
      end;
    UNPURPLE:
      for i := 1 to length(s) do begin
        nextmask  := CryptMask + (ord(s[i]) AND $7);
        s[i] := chr(ord(s[i]) XOR CryptMask);
        CryptMask := nextmask
      end;
    COMPLEX :
      for i := 1 to length(s) do begin
        s[i] := chr(ord(s[i]) XOR CryptMask);
        CryptMask := random($100)
      end;
  end   { case }

end;  { cryptstr }


begin

  Encryption := NONE;
  CryptMask  := $55

end.  { unit crypt }
