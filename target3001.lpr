library target3001;

{$mode objfpc}{$H+}
{$include calling.inc}

uses
  Classes,
  sysutils,
  WLXPlugin;

procedure ListGetDetectString(DetectString:pchar;maxlen:integer); dcpcall;
begin
  StrCopy(DetectString, 'EXT="T3001"');
end;

function ListGetText(FileToLoad:pchar;contentbuf:pchar;contentbuflen:integer):pchar; dcpcall;
begin
end;

exports
  ListGetDetectString,
  ListGetText;

begin
end.

