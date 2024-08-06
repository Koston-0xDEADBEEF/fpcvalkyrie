{$INCLUDE valkyrie.inc}
unit vcursesconsole;
interface
uses Classes, SysUtils, viotypes, vioevent, vioconsole;

type TCursesArray = array of array of DWord;

type TCursesConsoleRenderer = class( TIOConsoleRenderer )
  constructor Create( aCols : Word = 80; aRows : Word = 25; aReqCapabilities : TIOConsoleCapSet = [VIO_CON_BGCOLOR, VIO_CON_CURSOR] );
  procedure OutputChar( x,y : Integer; aColor : TIOColor; aChar : char ); override;
  procedure OutputChar( x,y : Integer; aFrontColor, aBackColor : TIOColor; aChar : char ); override;
  function GetChar( x,y : Integer ) : Char; override;
  function GetColor( x,y : Integer ) : TIOColor; override;
  function GetBackColor( x,y : Integer ) : TIOColor; override;
  procedure MoveCursor( x,y : Integer ); override;
  procedure ShowCursor; override;
  procedure HideCursor; override;
  procedure SetCursorType( aType : TIOCursorType ); override;
  procedure Update; override;
  procedure Clear; override;
  procedure ClearRect(x1,y1,x2,y2 : Integer; aBackColor : TIOColor = 0 ); override;
  function GetDeviceArea : TIORect; override;
  function GetSupportedCapabilities : TIOConsoleCapSet; override;
private
  procedure ClearArray( var A : TCursesArray; aClear : DWord );
private
  FClearCell     : Word;
  FOutputCMask   : DWord;
  FCursesPos     : TPoint;
  FCursesArray   : TCursesArray;
  FNewArray      : TCursesArray;
  FCursorVisible : Boolean;
  FUpdateNeeded  : Boolean;
  FUpdateCursor  : Boolean;
  FHighASCII     : array[128..255] of QWord;
end;

implementation

uses vutil, nCurses, vcursesio;

const ColorMask     = $000000FF;
      ForeColorMask = $0000000F;

procedure TCursesConsoleRenderer.ClearArray( var A : TCursesArray; aClear : DWord );
var y : Integer;
begin
  for y := Low(A) to High(A) do
    FillDWord( A[y][0], FSizeX, aClear );
end;

constructor TCursesConsoleRenderer.Create ( aCols : Word; aRows : Word; aReqCapabilities : TIOConsoleCapSet ) ;
begin
  Log('Initializing Curses Console Renderer...');
  inherited Create( aCols, aRows, aReqCapabilities );
//  if VIO_CON_CURSOR in FCapabilities then
//    SetCursorType( VIO_CURSOR_SMALL )
//  else
//    video.SetCursorType( crHidden );
  FillQWord( FHighASCII, 128, 0 );
  FHighASCII[ 219 ] := 97 or A_ALTCHARSET; // full box
  FHighASCII[ 176 ] := 97 or A_ALTCHARSET; // shaded box
  FHighASCII[ 177 ] := 97 or A_ALTCHARSET; // shaded box
  FHighASCII[ 178 ] := 97 or A_ALTCHARSET; // shaded box

  FHighASCII[ 249 ] := 126 or A_ALTCHARSET; // |
  FHighASCII[ 250 ] := 126 or A_ALTCHARSET; // |

  FHighASCII[ 217 ] := 106 or A_ALTCHARSET; // _|
  FHighASCII[ 191 ] := 107 or A_ALTCHARSET; // ^|
  FHighASCII[ 218 ] := 108 or A_ALTCHARSET; // |^
  FHighASCII[ 192 ] := 109 or A_ALTCHARSET; // |_
  FHighASCII[ 197 ] := 110 or A_ALTCHARSET; // +
  FHighASCII[ 196 ] := 113 or A_ALTCHARSET; // -
  FHighASCII[ 195 ] := 116 or A_ALTCHARSET; // |-
  FHighASCII[ 180 ] := 117 or A_ALTCHARSET; // -|
  FHighASCII[ 193 ] := 118 or A_ALTCHARSET; // _|_
  FHighASCII[ 194 ] := 119 or A_ALTCHARSET; // ^|^
  FHighASCII[ 179 ] := 120 or A_ALTCHARSET; // |

  // Doubles
  FHighASCII[ 188 ] := 106 or A_ALTCHARSET; // _|
  FHighASCII[ 187 ] := 107 or A_ALTCHARSET; // ^|
  FHighASCII[ 201 ] := 108 or A_ALTCHARSET; // |^
  FHighASCII[ 200 ] := 109 or A_ALTCHARSET; // |_
  FHighASCII[ 206 ] := 110 or A_ALTCHARSET; // +
  FHighASCII[ 205 ] := 113 or A_ALTCHARSET; // -
  FHighASCII[ 204 ] := 116 or A_ALTCHARSET; // |-
  FHighASCII[ 185 ] := 117 or A_ALTCHARSET; // -|
  FHighASCII[ 202 ] := 118 or A_ALTCHARSET; // _|_
  FHighASCII[ 203 ] := 119 or A_ALTCHARSET; // ^|^
  FHighASCII[ 186 ] := 120 or A_ALTCHARSET; // |

  // Mixed VDouble
  FHighASCII[ 189 ] := 106 or A_ALTCHARSET; // _|
  FHighASCII[ 183 ] := 107 or A_ALTCHARSET; // ^|
  FHighASCII[ 214 ] := 108 or A_ALTCHARSET; // |^
  FHighASCII[ 211 ] := 109 or A_ALTCHARSET; // |_
  FHighASCII[ 215 ] := 110 or A_ALTCHARSET; // +
  FHighASCII[ 199 ] := 116 or A_ALTCHARSET; // |-
  FHighASCII[ 182 ] := 117 or A_ALTCHARSET; // -|
  FHighASCII[ 208 ] := 118 or A_ALTCHARSET; // _|_
  FHighASCII[ 210 ] := 119 or A_ALTCHARSET; // ^|^

  // Mixed HDouble
  FHighASCII[ 190 ] := 106 or A_ALTCHARSET; // _|
  FHighASCII[ 184 ] := 107 or A_ALTCHARSET; // ^|
  FHighASCII[ 213 ] := 108 or A_ALTCHARSET; // |^
  FHighASCII[ 212 ] := 109 or A_ALTCHARSET; // |_
  FHighASCII[ 216 ] := 110 or A_ALTCHARSET; // +
  FHighASCII[ 198 ] := 116 or A_ALTCHARSET; // |-
  FHighASCII[ 181 ] := 117 or A_ALTCHARSET; // -|
  FHighASCII[ 207 ] := 118 or A_ALTCHARSET; // _|_
  FHighASCII[ 209 ] := 119 or A_ALTCHARSET; // ^|^

  FOutputCMask := ColorMask;
  FClearCell := Ord(' ')+(LightGray shl 8);
  FCursesPos.x := 1;
  FCursesPos.y := 1;
  FUpdateNeeded := True;
  FUpdateCursor := True;
  FCursorType    := VIO_CURSOR_SMALL;
  FCursorVisible := True;
  SetLength( FCursesArray, FSizeY, FSizeX );
  ClearArray( FCursesArray, 0 );
  SetLength( FNewArray, FSizeY, FSizeX );
  ClearArray( FNewArray, 0 );
  Log('Initialized.');
end;

procedure TCursesConsoleRenderer.OutputChar ( x, y : Integer; aColor : TIOColor; aChar : char ) ;
var iValue : Word;
begin
  if aColor = ColorNone then Exit;
  if aColor = Black then
  begin
    aChar  := ' ';
    aColor := LightGray;
  end;
  iValue := Ord(aChar) + ((aColor and FOutputCMask) shl 8);
  if ( FNewArray[y-1][x-1] <> iValue ) then
  begin
    FNewArray[y-1][x-1] := iValue;
    FUpdateNeeded := True;
  end;
end;

procedure TCursesConsoleRenderer.OutputChar ( x, y : Integer; aFrontColor, aBackColor : TIOColor; aChar : char ) ;
var iValue : Word;
begin
  if aBackColor = ColorNone then
  begin
    OutputChar( x, y, aFrontColor, aChar );
    Exit;
  end;
  if aFrontColor = ColorNone then
  begin
    FNewArray[y-1][x-1] :=  Ord(' ') + (aBackColor and ForeColorMask) shl 12;
    Exit;
  end;
  if ( aFrontColor = Black ) and ( aBackColor = Black ) then
  begin
    aChar       := ' ';
    aFrontColor := LightGray;
  end;

  iValue := Ord(aChar) + (aFrontColor and ForeColorMask) shl 8;
  if VIO_CON_BGCOLOR in FCapabilities then
    iValue += (aBackColor and ForeColorMask) shl 12;
  if ( FNewArray[y-1][x-1] <> iValue ) then
  begin
    FNewArray[y-1][x-1] := iValue;
    FUpdateNeeded := True;
  end;
end;

function TCursesConsoleRenderer.GetChar ( x, y : Integer ) : Char;
begin
  Exit( Chr( FCursesArray[y-1][x-1] mod 256 ) );
end;

function TCursesConsoleRenderer.GetColor ( x, y : Integer ) : TIOColor;
begin
  Exit( (FCursesArray[y-1][x-1] div 256) mod 16 );
end;

function TCursesConsoleRenderer.GetBackColor ( x, y : Integer ) : TIOColor;
begin
  Exit( (FCursesArray[y-1][x-1] div 256) div 16 );
end;

procedure TCursesConsoleRenderer.MoveCursor ( x, y : Integer ) ;
begin
  if VIO_CON_CURSOR in FCapabilities then
  begin
    if ( FCursesPos.X <> x ) or ( FCursesPos.Y <> y ) then
    begin
      FCursesPos.X  := x;
      FCursesPos.Y  := y;
      FUpdateCursor := True;
    end;
  end;
end;

procedure TCursesConsoleRenderer.ShowCursor;
begin
  if not FCursorVisible then
    if VIO_CON_CURSOR in FCapabilities then
      SetCursorType( FCursorType );
  FCursorVisible := True;
end;

procedure TCursesConsoleRenderer.HideCursor;
begin
  if FCursorVisible then
  begin
    FCursorVisible := False;
    nCurses.curs_set( 0 );
  end;
end;

procedure TCursesConsoleRenderer.SetCursorType ( aType : TIOCursorType ) ;
begin
    if VIO_CON_CURSOR in FCapabilities then
    begin
      FCursorType  := aType;
      if FCursorVisible then
      begin
        case aType of
        VIO_CURSOR_SMALL : nCurses.curs_set( 1 );
        VIO_CURSOR_HALF  : nCurses.curs_set( 1 );
        VIO_CURSOR_BLOCK : nCurses.curs_set( 2 );
        end;
      end;
    end;
end;

procedure TCursesConsoleRenderer.Update;
var iRefresh : Boolean;
    x,y      : Integer;
    iValue   : DWord;
    iChar    : Char;
    iFr, iBk : TIOColor; 
    iOut     : QWord;
begin
  iRefresh := False;
  if FUpdateNeeded then
  begin
    for y := 0 to FSizeY-1 do
      for x := 0 to FSizeX-1 do
        if FNewArray[y][x] <> FCursesArray[y][x] then
        begin
          iValue := FNewArray[y][x];
          iChar  := Char( iValue mod 256 );
          iFr    := ( iValue div 256 ) mod 16;
          if iFr > 0 then
          begin
            iBk    := ( iValue div 256 ) div 16;
            if iBk > 7 then 
              iBk := iBk - 8;

            iOut := QWord(iChar);
            if (iOut > 127) and (iOut < 256) then
            begin
              if FHighASCII[iOut] <> 0 then
                iOut := FHighASCII[iOut];
            end;
            if iFr = 8 then
              iOut := iOut or COLOR_PAIR( 8*8 + iBk*8 ) or A_BOLD
            else if iFr > 7 then
              iOut := iOut or COLOR_PAIR( iFr - 8 + iBk*8 ) or A_BOLD
            else
              iOut := iOut or COLOR_PAIR( iFr + iBk*8 );

            if not iRefresh then
            begin
              nCurses.curs_set( 0 );
              iRefresh := True;
            end;
            nCurses.mvaddch( y, x, iOut );
          end;
          FCursesArray[y][x] := iValue;
        end;
    FUpdateNeeded := false;
  end;
  if iRefresh or FUpdateCursor then
  begin
    if iRefresh then
      SetCursorType( FCursorType );
    nCurses.move( FCursesPos.y-1, FCursesPos.x-1 );
    nCurses.refresh();
    FUpdateCursor := False;
  end;
end;

procedure TCursesConsoleRenderer.Clear;
begin
  ClearArray( FNewArray, FClearCell );
  FUpdateNeeded := True;
end;

procedure TCursesConsoleRenderer.ClearRect ( x1, y1, x2, y2 : Integer; aBackColor : TIOColor ) ;
var x,y    : Word;
    iColor : Word;
begin
  iColor := Ord(' ')+LightGray shl 8;
  if VIO_CON_BGCOLOR in FCapabilities then
    iColor += (aBackColor and ForeColorMask) shl 12;
  for y := y1 to y2 do
    for x := x1 to x2 do
      FNewArray[y-1][x-1] := iColor;
  FUpdateNeeded := True;
end;

function TCursesConsoleRenderer.GetDeviceArea : TIORect;
begin
  GetDeviceArea.Pos := PointZero;
  GetDeviceArea.Dim := Point( FSizeX, FSizeY );
end;

function TCursesConsoleRenderer.GetSupportedCapabilities : TIOConsoleCapSet;
begin
  Result := [ VIO_CON_BGCOLOR, VIO_CON_CURSOR ];
end;


end.

