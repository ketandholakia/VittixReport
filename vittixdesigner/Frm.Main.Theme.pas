unit Frm.Main.Theme;

{ Designer chrome palette.

  The designer has always carried its surface colours inline (dock header bars,
  splitters, panel fills). This unit is the single documented source for them so
  the look can be adjusted in one place, and so a future full theme switch has
  somewhere to live.

  Scope note: this palette covers the window chrome that the designer app owns -
  dock section headers, splitters, panel and canvas backgrounds, list colours and
  the status bar. The designer canvas *internals* (grid, margin guides, band
  header strips, selection handles, smart guides) are painted by
  Vittix.Report.DesignerControl with system colours (clWindowText, clGray,
  clFuchsia, ...) which adapt to the OS theme; making those theme-driven needs a
  change inside the control and is deliberately not part of this palette.

  Colours are TColor, i.e. $00BBGGRR - blue and red are swapped relative to the
  RGB values quoted in the comments. }

interface

uses
  System.SysUtils,
  Vcl.Graphics;

type
  TDesignerPalette = record
    Name: string;
    AppBackground: TColor;      // form / outer panels
    PanelBackground: TColor;    // dock panels, right-hand property dock
    CanvasBackground: TColor;   // designer surface around the page
    HeaderBackground: TColor;   // collapsible dock section bars
    HeaderText: TColor;
    Splitter: TColor;
    Accent: TColor;             // focus / selection accent in the chrome
  end;

const
  { The colours the app has used so far: system-coloured surfaces with a dark
    header bar. Keeping this as the default means existing installations see no
    change until they pick another theme. }
  PaletteClassic: TDesignerPalette = (
    Name: 'Classic';
    AppBackground: clBtnFace;
    PanelBackground: clBtnFace;
    CanvasBackground: clBtnFace;
    HeaderBackground: $002C2C2C;   // RGB(44, 44, 44)
    HeaderText: clWhite;
    Splitter: $00D0D0D0;           // RGB(208, 208, 208)
    Accent: clHighlight);

  { Light refresh: warm-neutral surfaces, a slate header bar and a blue accent. }
  PaletteSoft: TDesignerPalette = (
    Name: 'Soft';
    AppBackground: $00F7F7F9;      // RGB(249, 247, 247)
    PanelBackground: $00FCFCFD;    // RGB(253, 252, 252)
    CanvasBackground: $00EEEFEF;   // RGB(239, 239, 238)
    HeaderBackground: $0068554A;   // RGB(74, 85, 104) slate
    HeaderText: clWhite;
    Splitter: $00DED8D6;           // RGB(214, 216, 222)
    Accent: $00CC6600);            // RGB(0, 102, 204)

  { Dark chrome. Note the caveat above: the canvas internals stay system-coloured,
    so this is aimed at the surrounding chrome rather than a full dark mode. }
  PaletteDark: TDesignerPalette = (
    Name: 'Dark';
    AppBackground: $00303030;      // RGB(48, 48, 48)
    PanelBackground: $003C3C3C;    // RGB(60, 60, 60)
    CanvasBackground: $00242424;   // RGB(36, 36, 36)
    HeaderBackground: $00505050;   // RGB(80, 80, 80)
    HeaderText: clWhite;
    Splitter: $00585858;           // RGB(88, 88, 88)
    Accent: $00D77800);            // RGB(0, 120, 215)

const
  THEME_NAMES: array[0..2] of string = ('Classic', 'Soft', 'Dark');

function PaletteByName(const AName: string): TDesignerPalette;
function PaletteIndexByName(const AName: string): Integer;

implementation

function PaletteByName(const AName: string): TDesignerPalette;
begin
  if SameText(AName, 'Soft') then
    Result := PaletteSoft
  else if SameText(AName, 'Dark') then
    Result := PaletteDark
  else
    Result := PaletteClassic;
end;

function PaletteIndexByName(const AName: string): Integer;
var
  I: Integer;
begin
  for I := Low(THEME_NAMES) to High(THEME_NAMES) do
    if SameText(AName, THEME_NAMES[I]) then
      Exit(I);
  Result := 0;
end;

end.
