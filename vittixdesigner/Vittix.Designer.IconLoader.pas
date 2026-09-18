unit Vittix.Designer.IconLoader;

(*
  Icon loading for the designer chrome and the print preview.

  Why this unit exists
  --------------------
  The designer icons ship as 32bpp PNG resources (resources\vittix_png_icons.res)
  with a real alpha channel, but two VCL calls quietly throw that channel away:

    * TBitmap.Assign(TPngImage) - copies the picture without its alpha, so every
      transparent pixel comes out black.
    * TImageList.Add(Bmp, nil)  - does not keep or blend 32bpp alpha either; the
      image is stored without an alpha channel.

  The visible symptom is an icon painted on a solid black square. The route that
  does work is a colour key: paint the transparent pixels with a colour that
  never occurs in the artwork and add the bitmap with TImageList.AddMasked.
  Masking is also state-independent, so flat/hot/pressed buttons all look right.

  Therefore: load icon resources through this unit, never with Assign.

  Note on edges: masking is 1-bit, so pixels below the alpha threshold are cut
  rather than blended. These are 24px monochrome glyphs, so the difference is
  negligible, and it avoids the dark fringe that keeping them would produce.
*)

interface

uses
  Vcl.Graphics,
  Vcl.Controls,   // TImageList
  Vcl.ImgList,    // TCustomImageList.AddMasked
  Vcl.Imaging.pngimage;

const
  { Colour key for masked icon loading. The icon set is monochrome dark
    glyphs, so this colour never occurs in the artwork itself.
    Deliberately an untyped constant so it can be used as a default value. }
  IconMaskColor = $00FF00FF; // fuchsia - RGB(255, 0, 255)

/// <summary>
///   Converts a PNG into a bitmap ready for TImageList.AddMasked: pixels at or
///   above AAlphaThreshold keep their colour, the rest become AMaskColor.
/// </summary>
function PngToMaskedBitmap(APng: TPngImage;
  AMaskColor: TColor = IconMaskColor;
  AAlphaThreshold: Byte = 128): Vcl.Graphics.TBitmap;

/// <summary>
///   Loads PNG_&lt;AIconName&gt; from the module's resources as a masked bitmap.
///   Returns nil when the resource is not linked in.
/// </summary>
function LoadIconBitmap(const AIconName: string;
  AMaskColor: TColor = IconMaskColor): Vcl.Graphics.TBitmap;

/// <summary>
///   Loads an icon resource straight into an image list.
///   Returns the new image index, or -1 when the resource is absent.
/// </summary>
function AddIcon(AImages: TImageList;
  const AIconName: string;
  AMaskColor: TColor = IconMaskColor): Integer;

/// <summary>
///   Adds a bitmap whose transparent areas are already painted with AMaskColor.
/// </summary>
function AddMaskedBitmap(AImages: TImageList;
  ABitmap: Vcl.Graphics.TBitmap;
  AMaskColor: TColor = IconMaskColor): Integer;

implementation

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows;

type
  { 24-bit DIB pixel. The masked bitmaps are deliberately 24bpp: AddMasked
    does not honour the colour key for 32bpp sources, it only masks 24bpp
    (and lower) ones, which is exactly the case we need. }
  TBgr24 = packed record
    B, G, R: Byte;
  end;
  PBgr24 = ^TBgr24;

function PngToMaskedBitmap(APng: TPngImage; AMaskColor: TColor;
  AAlphaThreshold: Byte): Vcl.Graphics.TBitmap;
var
  X, Y, Al: Integer;
  SrcRow: PRGBLine;
  AlphaRow: PByte;
  Dst: PBgr24;
  MaskR, MaskG, MaskB: Byte;
begin
  Result := Vcl.Graphics.TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.SetSize(APng.Width, APng.Height);

  MaskR := GetRValue(AMaskColor);
  MaskG := GetGValue(AMaskColor);
  MaskB := GetBValue(AMaskColor);

  for Y := 0 to APng.Height - 1 do
  begin
    SrcRow   := APng.Scanline[Y];
    AlphaRow := PByte(APng.AlphaScanline[Y]);
    Dst      := PBgr24(Result.ScanLine[Y]);
    for X := 0 to APng.Width - 1 do
    begin
      if AlphaRow = nil then
        Al := 255
      else
        Al := AlphaRow[X];

      if Al >= AAlphaThreshold then
      begin
        Dst.R := SrcRow^[X].rgbtRed;
        Dst.G := SrcRow^[X].rgbtGreen;
        Dst.B := SrcRow^[X].rgbtBlue;
      end
      else
      begin
        Dst.R := MaskR;
        Dst.G := MaskG;
        Dst.B := MaskB;
      end;
      Inc(Dst);
    end;
  end;
end;

function LoadIconBitmap(const AIconName: string;
  AMaskColor: TColor): Vcl.Graphics.TBitmap;
var
  Stream: TResourceStream;
  Png: TPngImage;
begin
  Result := nil;
  try
    Stream := TResourceStream.Create(HInstance, 'PNG_' + UpperCase(AIconName), RT_RCDATA);
  except
    // Not linked into this module - callers keep the caption-only button.
    Exit;
  end;
  try
    Png := TPngImage.Create;
    try
      Png.LoadFromStream(Stream);
      Result := PngToMaskedBitmap(Png, AMaskColor);
    finally
      Png.Free;
    end;
  finally
    Stream.Free;
  end;
end;

function AddMaskedBitmap(AImages: TImageList; ABitmap: Vcl.Graphics.TBitmap;
  AMaskColor: TColor): Integer;
begin
  Result := AImages.AddMasked(ABitmap, AMaskColor);
end;

function AddIcon(AImages: TImageList; const AIconName: string;
  AMaskColor: TColor): Integer;
var
  Bmp: Vcl.Graphics.TBitmap;
begin
  Result := -1;
  Bmp := LoadIconBitmap(AIconName, AMaskColor);
  if Bmp = nil then
    Exit;
  try
    Result := AddMaskedBitmap(AImages, Bmp, AMaskColor);
  finally
    Bmp.Free;
  end;
end;

end.
