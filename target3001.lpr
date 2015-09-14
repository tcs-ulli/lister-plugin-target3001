library target3001;

{$mode objfpc}{$H+}
{$include calling.inc}

uses
  Classes,
  sysutils,
  WLXPlugin, general_nogui,Utils,memds,db;
var
  ResText : string;

procedure ListGetDetectString(DetectString:pchar;maxlen:integer); dcpcall;
begin
  StrCopy(DetectString, 'EXT="T3001"');
end;

function SearchToBinString(Stream : TStream;Str : string) : Boolean;
var
  search_str : string;
  search_idx : Integer = 1;
  b : Byte;
begin
  Result := false;
  search_str := Str;
  while search_idx < length(search_str) do
    begin
      if Stream.Read(b,1) < 1 then exit;
      if b = Ord(search_str[search_idx]) then
        inc(search_idx)
      else
        search_idx := 1;
    end;
  Result := True;
end;

function ReadBinaryPair(Stream : TStream) : string;
var
  Buffer : string;
  aSize : DWord;
const
  MAX_SIZE = 1024;
begin
  Result := '';
  Stream.Read(aSize,4);
  aSize := LeToN(aSize);
  if aSize > MAX_SIZE then
    exit;
  Setlength(Buffer,aSize);
  Stream.Read(Buffer[1],aSize);
  Result := SysToUni(Buffer)+':';
  Stream.Read(aSize,4);
  aSize := LeToN(aSize);
  if aSize > MAX_SIZE then
    begin
      Result := '';
      exit;
    end;
  Setlength(Buffer,aSize);
  Stream.Read(Buffer[1],aSize);
  Result := Result+SysToUni(Buffer);
  if Result = ':' then Result := '';
end;

function ReadBinaryString(Stream : TStream) : string;
var
  Buffer : Ansistring;
  aSize : DWord;
const
  MAX_SIZE = 512;
begin
  Result := '';
  aSize := Stream.ReadDWord;
  aSize := LEToN(aSize);
  if aSize > MAX_SIZE then
    exit;
  Setlength(Buffer,aSize);
  Stream.Read(Buffer[1],aSize);
  Result := SysToUni(Buffer);
end;

function FindComponents(fs: TStream;MemDataSet : TMemDataset) : string;
var
  aPos2: Int64;
  aPos: Int64;
  LastValue: String;
  aFoundPropCount: DWord;
  aPropCount: DWord;
  b: byte;
  aOldPos: Int64;
begin
  result := '';
  aOldPos := fs.Position;
  while SearchToBinString(fs,#00#00#00#00#00#00#00#00#00#00#00+chr($ff)) do
    begin
      MemDataSet.Append;
      while (fs.Read(b,1) = 1) and (b <> $ff) do;
      if b <> $ff then
        begin
          fs.Position := aOldPos;
          exit;
        end;
      fs.Seek(2,soCurrent);
      fs.Read(aPropCount,4);
      aPropCount := LeToN(aPropCount);
      aFoundPropCount := 0;
      LastValue := 'nichtleer';
      while (LastValue <> '') do
        begin
          LastValue := ReadBinaryPair(fs);
          inc(aFoundPropCount,2);
          if aFoundpropCount > aPropCount then break;
          if LastValue = '' then break;
          if MemDataSet.FieldDefs.IndexOf(copy(LastValue,0,pos(':',LastValue)-1)) <> -1 then
            MemDataSet.FieldByName(copy(LastValue,0,pos(':',LastValue)-1)).AsString := copy(LastValue,pos(':',LastValue)+1,length(LastValue));
        end;
      aPos := fs.Position;
      SearchToBinString(fs,'$%&DEUTSCH');
      aPos2 := fs.Position;
      fs.Position:=aPos;
      SearchToBinString(fs,#00#00#00#00#00#00#00#00#00#00#00+chr($ff));
      if fs.Position > aPos2 then
        begin
          fs.Position:=aPos2;
          fs.Seek(1,soCurrent);
          ReadBinaryString(fs);//Default Component Name
          MemDataSet.FieldByName('NAME').AsString := ReadBinaryString(fs);//Component Name
          fs.Seek(16,soCurrent);
          ReadBinaryString(fs);//Font
          fs.Seek(21,soCurrent);
          MemDataSet.FieldByName('VALUE').AsString := ReadBinaryString(fs);//Value
          if MemDataSet.FieldByName('VALUE').AsString = '$%&FRANCAIS' then
            MemDataSet.FieldByName('VALUE').AsString := ReadBinaryString(fs);//Value

          if (copy(MemDataSet.FieldByName('BIB_BAUTEIL').AsString,0,1) = '!')
          or (MemDataSet.FieldByName('BIB_BAUTEIL').AsString = 'V+') then
            begin
              MemDataSet.cancel;
              continue;
            end;
          if copy(MemDataSet.FieldByName('NAME').AsString,0,1) = '!' then
            begin
              MemDataSet.cancel;
              continue;
            end;
          MemDataSet.Post;
        end
      else
        begin
          fs.Position:=aOldPos;
          MemDataSet.cancel;
          exit;
        end;
    end;
  fs.Position:=aOldPos;
end;

function ListGetText(FileToLoad:pchar;contentbuf:pchar;contentbuflen:integer):pchar; dcpcall;
var
  aFile: TFileStream;
  aText: String;
  aVersion: Byte;
  aTarget: String;
  aFont: String;
  bFont: String;
  aVersionInfo: String;
  aLogBook: String;
  aTodo: String;
  mDS: TMemDataset;
  aPos: Int64;
  Divider : string;
  cFont: String;
  function BuildBinStr(chr : char;acount : Integer) : string;
  var
    i: Integer;
  begin
    SetLength(Result,acount);
    FillChar(Result[1],acount,chr);
  end;
label Cleanup;
begin
  result := PChar('');
  aFile := TFileStream.Create(FileToLoad,fmOpenRead);
  mDS := TMemDataset.Create(nil);
  aVersion := aFile.ReadByte;
  case aVersion of
  21:aTarget := 'Target V14.9';
  end;
  //undefined
  aFile.ReadByte;
  aFile.ReadByte;
  aFile.ReadByte;
  aFont := ReadBinaryString(aFile);
  bFont := ReadBinaryString(aFile);
  cFont := ReadBinaryString(aFile);
  SetLength(Divider,4);
  aFile.ReadByte;
  aFile.Read(Divider[1],4);
  //Unknown Stuff
  //Block of 78xFF
  if not SearchToBinString(aFile,BuildBinStr(char($ff),78)) then goto Cleanup;
  //Signale/Schaltung
    //Scheibar druch Divider getrennt (E0 93 04 00)
  //Komponenten
    //every component starts with 11x00+1xFF
    //Parameter readable with ReadBinaryPair
    //TODO:Position and additional parameter
    //Französisch,English,Deutsch Bauteilname ??
    //Font
    //Französisch,English,Deutsch Bauteilwert ??
    //Font
  mDS.FieldDefs.Add('BAUTEILNAME',ftString,100);
  mDS.FieldDefs.Add('NAME',ftString,100);
  mDS.FieldDefs.Add('VALUE',ftString,100);
  mDS.FieldDefs.Add('COMPONENT_ID',ftString,100);
  mDS.FieldDefs.Add('COMPONENT_NAME',ftString,100);
  mDS.FieldDefs.Add('PROPOSED_PACKAGE',ftString,100);
  mDS.FieldDefs.Add('BIB_BAUTEIL',ftString,100);
  mDS.FieldDefs.Add('LAST_MODIFIED',ftString,100);
  mDS.FieldDefs.Add('COMPONENTTYPE',ftString,100);
  mDS.FieldDefs.Add('COMPONENT_VALUE',ftString,100);
  mDS.FieldDefs.Add('VARIANT=0',ftString,100);
  mDS.FieldDefs.Add('VARIANT=1',ftString,100);
  mDs.CreateTable;
  mDs.Open;
  aText := FindComponents(aFile,mDS);
  //8xDivider (E0 93 04 00)
  //if not SearchToBinString(aFile,Divider+Divider+Divider+Divider+Divider+Divider+Divider+Divider) then goto Cleanup;
  //Simulation Models
  if not SearchToBinString(aFile,BuildBinStr(char($00),100)) then exit;//100x00
  //Layer List
  if not SearchToBinString(aFile,BuildBinStr(char($00),100)) then exit;//100x00
  //Fonts or other embedded Blob Stuff
  //2xDivider (E0 93 04 00)
  if not SearchToBinString(aFile,Divider) then goto Cleanup;
  aFile.ReadByte;
  aFile.ReadByte;
  aFile.ReadByte;
  aFile.ReadByte;
  aFile.ReadByte;
  aPos := aFile.Position;
  aVersionInfo := ReadBinaryString(aFile);
  aLogBook := ReadBinaryString(aFile);
  aTodo := ReadBinaryString(aFile);
  aText += 'Version Info:'+LineEnding+aVersionInfo;
  aText += 'Logbuch:'+LineEnding+aLogBook;
  aText += 'Todo:'+LineEnding+aTodo;

  aText += 'Teile:'+LineEnding;
  mDS.First;
  while not mDS.EOF do
    begin
      aText += mDs.FieldByName('NAME').AsString+#19+mDs.FieldByName('VALUE').AsString+LineEnding;
      mDs.Next;
    end;
Cleanup:
  mDS.Free;
  aFile.Free;
  ResText:=UniToSys(aText);
  result := PChar(ResText);
end;

exports
  ListGetDetectString,
  ListGetText;

begin
end.

