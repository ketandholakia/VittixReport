unit Vittix.Report.Serializer;

(*
  Vittix.Report.Serializer
  ========================
  Saves and loads a TReportModel to/from a UTF-8 JSON file (.vrt).

  JSON structure (v2)
  -------------------
  Each band in Objects[] includes a Children[] array (was missing in v1).
  PageSettings is persisted as a nested object.

  Versioning
  ----------
  Reading a v1 file (no Version key) still works; Children defaults to empty.

  Cloning
  -------
  CloneObject - deep-clones a single TReportObject (text or band + children)
  CloneReport - deep-clones an entire TReportModel (serialize -> deserialize)
*)

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Types,
  System.IOUtils,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.PageSettings;

type
  TReportSerializer = class
  public
    class procedure SaveToFile(R: TReportModel; const FN: string);
    class function  LoadFromFile(const FN: string): TReportModel;

    /// <summary>Deep-clone a single object (band + its children, or leaf object).</summary>
    class function CloneObject(Obj: TReportObject): TReportObject;

    /// <summary>Deep-clone an entire report model via serialize â†’ deserialize.</summary>
    class function CloneReport(R: TReportModel): TReportModel;
  end;

{ Exposed so units like the designer can reuse serialisation of single objects }
function ObjectToJSON(Obj: TReportObject): TJSONObject;
function JSONToObject(O: TJSONObject): TReportObject;

implementation

uses
  System.NetEncoding,
  Vcl.Graphics,         // TFontStyles, TFont constants used when reading font fields
  Vcl.Controls,         // TVerticalAlignment
  Vcl.Imaging.pngimage, // register PNG format for picture load/save
  Vcl.Imaging.Jpeg;     // register JPEG format for picture load/save

// ---------------------------------------------------------------------------
// Rect helpers
// ---------------------------------------------------------------------------

function RectToJSON(const R: TRect): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('L', TJSONNumber.Create(R.Left));
  Result.AddPair('T', TJSONNumber.Create(R.Top));
  Result.AddPair('R', TJSONNumber.Create(R.Right));
  Result.AddPair('B', TJSONNumber.Create(R.Bottom));
end;

function JSONToRect(O: TJSONObject): TRect;
begin
  Result := Rect(
    O.GetValue<Integer>('L'),
    O.GetValue<Integer>('T'),
    O.GetValue<Integer>('R'),
    O.GetValue<Integer>('B')
  );
end;

// ---------------------------------------------------------------------------
// Class registry lookup
// ---------------------------------------------------------------------------

function FindObjectClass(const ClassName: string): TReportObjectClass;
var
  C: TReportObjectClass;
begin
  Result := nil;
  for C in GetRegisteredReportObjects do
    if SameText(C.ClassName, ClassName) then
      Exit(C);
end;

// ---------------------------------------------------------------------------
// Single TReportObject â†” JSON
// ---------------------------------------------------------------------------

function ObjectToJSON(Obj: TReportObject): TJSONObject;
var
  T:         TReportTextObject;
  Sh:        TReportShapeObject;
  Img:       TReportImageObject;
  Memo:      TReportMemoObject;
  Ln:        TReportLineObject;
  Band:      TReportBand;
  ChildArr:  TJSONArray;
  Child:     TReportObject;
  PicStream: TMemoryStream;
  PicBytes:  TBytes;
begin
  Result := TJSONObject.Create;

  Result.AddPair('Class',        Obj.ClassName);
  Result.AddPair('Name',         Obj.Name);
  Result.AddPair('Bounds',       RectToJSON(Obj.Bounds));
  Result.AddPair('Visible',      TJSONBool.Create(Obj.Visible));
  Result.AddPair('PrintWhen',    Obj.PrintWhen);
  Result.AddPair('AnchorRight',  TJSONBool.Create(Obj.AnchorRight));
  Result.AddPair('AnchorBottom', TJSONBool.Create(Obj.AnchorBottom));

  // ----- TReportTextObject fields -----
  if Obj is TReportTextObject then
  begin
    T := TReportTextObject(Obj);
    Result.AddPair('Text',          T.Text);
    Result.AddPair('DataField',      T.DataField);
    Result.AddPair('Expression',     T.Expression);
    Result.AddPair('FontName',       T.Font.Name);
    Result.AddPair('FontSize',       TJSONNumber.Create(T.Font.Size));
    Result.AddPair('FontColor',      TJSONNumber.Create(T.Font.Color));
    Result.AddPair('FontBold',       TJSONBool.Create(fsBold   in T.Font.Style));
    Result.AddPair('FontItalic',     TJSONBool.Create(fsItalic in T.Font.Style));
    Result.AddPair('HAlign',         TJSONNumber.Create(Ord(T.HAlign)));
    Result.AddPair('VAlign',         TJSONNumber.Create(Ord(T.VAlign)));
    Result.AddPair('Background',     TJSONNumber.Create(T.Background));
    Result.AddPair('Transparent',    TJSONBool.Create(T.Transparent));
    Result.AddPair('BorderVisible',  TJSONBool.Create(T.BorderVisible));
    Result.AddPair('BorderColor',    TJSONNumber.Create(T.BorderColor));
    Result.AddPair('BorderWidth',    TJSONNumber.Create(T.BorderWidth));
    Result.AddPair('WordWrap',       TJSONBool.Create(T.WordWrap));
    Result.AddPair('AutoSize',       TJSONBool.Create(T.AutoSize));
    Result.AddPair('PaddingLeft',    TJSONNumber.Create(T.PaddingLeft));
    Result.AddPair('PaddingTop',     TJSONNumber.Create(T.PaddingTop));
    Result.AddPair('PaddingRight',   TJSONNumber.Create(T.PaddingRight));
    Result.AddPair('PaddingBottom',  TJSONNumber.Create(T.PaddingBottom));
  end;

  // ----- TReportShapeObject fields -----
  if Obj is TReportShapeObject then
  begin
    Sh := TReportShapeObject(Obj);
    Result.AddPair('ShapeType',    TJSONNumber.Create(Ord(Sh.ShapeType)));
    Result.AddPair('PenColor',     TJSONNumber.Create(Sh.PenColor));
    Result.AddPair('PenWidth',     TJSONNumber.Create(Sh.PenWidth));
    Result.AddPair('PenStyle',     TJSONNumber.Create(Ord(Sh.PenStyle)));
    Result.AddPair('BrushColor',   TJSONNumber.Create(Sh.BrushColor));
    Result.AddPair('BrushStyle',   TJSONNumber.Create(Ord(Sh.BrushStyle)));
    Result.AddPair('CornerRadius', TJSONNumber.Create(Sh.CornerRadius));
  end;

  // ----- TReportImageObject fields -----
  if Obj is TReportImageObject then
  begin
    Img := TReportImageObject(Obj);
    Result.AddPair('Stretch',       TJSONBool.Create(Img.Stretch));
    Result.AddPair('Center',        TJSONBool.Create(Img.Center));
    Result.AddPair('Proportional',  TJSONBool.Create(Img.Proportional));
    Result.AddPair('BorderVisible', TJSONBool.Create(Img.BorderVisible));
    Result.AddPair('BorderColor',   TJSONNumber.Create(Img.BorderColor));
    Result.AddPair('BorderWidth',   TJSONNumber.Create(Img.BorderWidth));
    Result.AddPair('DataField',     Img.DataField);
    if Assigned(Img.Picture.Graphic) and not Img.Picture.Graphic.Empty then
    begin
      PicStream := TMemoryStream.Create;
      try
        Img.Picture.Graphic.SaveToStream(PicStream);
        SetLength(PicBytes, PicStream.Size);
        Move(PicStream.Memory^, PicBytes[0], PicStream.Size);
        Result.AddPair('PictureData',  TNetEncoding.Base64.EncodeBytesToString(PicBytes));
        Result.AddPair('PictureClass', Img.Picture.Graphic.ClassName);
      finally
        PicStream.Free;
      end;
    end;
  end;

  // ----- TReportMemoObject extra fields (text fields handled above) -----
  if Obj is TReportMemoObject then
  begin
    Memo := TReportMemoObject(Obj);
    Result.AddPair('AutoHeight', TJSONBool.Create(Memo.AutoHeight));
    Result.AddPair('MinHeight',  TJSONNumber.Create(Memo.MinHeight));
  end;

  // ----- TReportLineObject fields -----
  if Obj is TReportLineObject then
  begin
    Ln := TReportLineObject(Obj);
    Result.AddPair('Orientation', TJSONNumber.Create(Ord(Ln.Orientation)));
    Result.AddPair('LineColor',   TJSONNumber.Create(Ln.LineColor));
    Result.AddPair('LineWidth',   TJSONNumber.Create(Ln.LineWidth));
    Result.AddPair('LineStyle',   TJSONNumber.Create(Ord(Ln.LineStyle)));
  end;

  // ----- TReportBand fields + children -----
  if Obj is TReportBand then
  begin
    Band := TReportBand(Obj);
    Result.AddPair('BandType',            TJSONNumber.Create(Ord(Band.BandType)));
    Result.AddPair('Height',              TJSONNumber.Create(Band.Height));
    Result.AddPair('GroupField',          Band.GroupField);
    Result.AddPair('GroupLevel',          TJSONNumber.Create(Band.GroupLevel));
    Result.AddPair('StartNewPage',        TJSONBool.Create(Band.StartNewPage));
    Result.AddPair('CanGrow',             TJSONBool.Create(Band.CanGrow));
    Result.AddPair('CanShrink',           TJSONBool.Create(Band.CanShrink));
    Result.AddPair('BackColor',           TJSONNumber.Create(Band.BackColor));
    Result.AddPair('BackColorTransparent',TJSONBool.Create(Band.BackColorTransparent));

    ChildArr := TJSONArray.Create;
    for Child in Band.Children do
      ChildArr.AddElement(ObjectToJSON(Child));
    Result.AddPair('Children', ChildArr);
  end;
end;

function JSONToObject(O: TJSONObject): TReportObject;
var
  Cls:        TReportObjectClass;
  Obj:        TReportObject;
  T:          TReportTextObject;
  Sh:         TReportShapeObject;
  Img:        TReportImageObject;
  Memo:       TReportMemoObject;
  Ln:         TReportLineObject;
  Band:       TReportBand;
  ChildArr:   TJSONArray;
  i:          Integer;
  Style:      TFontStyles;
  PicData:    string;
  PicClass:   string;
  PicBytes:   TBytes;
  PicStream:  TMemoryStream;
  PicGraphic: TGraphicClass;
  G:          TGraphic;
begin
  Cls := FindObjectClass(O.GetValue<string>('Class'));
  if not Assigned(Cls) then
    raise Exception.CreateFmt(
      'Unknown report object class: "%s"',
      [O.GetValue<string>('Class')]);

  Obj := Cls.Create;
  try
    Obj.Name         := O.GetValue<string>('Name',   '');
    Obj.Bounds       := JSONToRect(O.GetValue<TJSONObject>('Bounds'));
    Obj.Visible      := O.GetValue<Boolean>('Visible',      True);
    Obj.PrintWhen    := O.GetValue<string>('PrintWhen',     '');
    Obj.AnchorRight  := O.GetValue<Boolean>('AnchorRight',  False);
    Obj.AnchorBottom := O.GetValue<Boolean>('AnchorBottom', False);

    // ----- TReportTextObject fields -----
    if Obj is TReportTextObject then
    begin
      T := TReportTextObject(Obj);
      T.Text        := O.GetValue<string>('Text',       '');
      T.DataField   := O.GetValue<string>('DataField',  '');
      T.Expression  := O.GetValue<string>('Expression', '');
      T.Font.Name   := O.GetValue<string>('FontName',   'Tahoma');
      T.Font.Size   := O.GetValue<Integer>('FontSize',  10);
      T.Font.Color  := O.GetValue<Integer>('FontColor', 0);

      Style := [];
      if O.GetValue<Boolean>('FontBold',   False) then Include(Style, fsBold);
      if O.GetValue<Boolean>('FontItalic', False) then Include(Style, fsItalic);
      T.Font.Style     := Style;
      T.HAlign         := TAlignment(O.GetValue<Integer>('HAlign',  0));
      T.VAlign         := TVerticalAlignment(O.GetValue<Integer>('VAlign', 2));
      T.Background     := O.GetValue<Integer>('Background',    Integer(clWhite));
      T.Transparent    := O.GetValue<Boolean>('Transparent',   True);
      T.BorderVisible  := O.GetValue<Boolean>('BorderVisible', False);
      T.BorderColor    := O.GetValue<Integer>('BorderColor',   Integer(clBlack));
      T.BorderWidth    := O.GetValue<Integer>('BorderWidth',   1);
      T.WordWrap       := O.GetValue<Boolean>('WordWrap',      False);
      T.AutoSize       := O.GetValue<Boolean>('AutoSize',      False);
      T.PaddingLeft    := O.GetValue<Integer>('PaddingLeft',   2);
      T.PaddingTop     := O.GetValue<Integer>('PaddingTop',    2);
      T.PaddingRight   := O.GetValue<Integer>('PaddingRight',  2);
      T.PaddingBottom  := O.GetValue<Integer>('PaddingBottom', 2);
    end;

    // ----- TReportShapeObject fields -----
    if Obj is TReportShapeObject then
    begin
      Sh := TReportShapeObject(Obj);
      Sh.ShapeType    := TReportShapeType(O.GetValue<Integer>('ShapeType', 0));
      Sh.PenColor     := O.GetValue<Integer>('PenColor',   Integer(clBlack));
      Sh.PenWidth     := O.GetValue<Integer>('PenWidth',   1);
      Sh.PenStyle     := TPenStyle(O.GetValue<Integer>('PenStyle',   0));
      Sh.BrushColor   := O.GetValue<Integer>('BrushColor', Integer(clWhite));
      Sh.BrushStyle   := TBrushStyle(O.GetValue<Integer>('BrushStyle', 0));
      Sh.CornerRadius := O.GetValue<Integer>('CornerRadius', 12);
    end;

    // ----- TReportImageObject fields -----
    if Obj is TReportImageObject then
    begin
      Img := TReportImageObject(Obj);
      Img.Stretch       := O.GetValue<Boolean>('Stretch',       True);
      Img.Center        := O.GetValue<Boolean>('Center',        True);
      Img.Proportional  := O.GetValue<Boolean>('Proportional',  True);
      Img.BorderVisible := O.GetValue<Boolean>('BorderVisible', False);
      Img.BorderColor   := O.GetValue<Integer>('BorderColor',   Integer(clBlack));
      Img.BorderWidth   := O.GetValue<Integer>('BorderWidth',   1);
      Img.DataField     := O.GetValue<string>('DataField',      '');
      PicData  := O.GetValue<string>('PictureData',  '');
      PicClass := O.GetValue<string>('PictureClass', '');
      if (PicData <> '') and (PicClass <> '') then
      begin
        PicBytes  := TNetEncoding.Base64.DecodeStringToBytes(PicData);
        PicStream := TMemoryStream.Create;
        try
          PicStream.Write(PicBytes[0], Length(PicBytes));
          PicStream.Position := 0;
          PicGraphic := TGraphicClass(FindClass(PicClass));
          if Assigned(PicGraphic) then
          begin
            G := PicGraphic.Create;
            try
              G.LoadFromStream(PicStream);
              Img.Picture.Assign(G);
            finally
              G.Free;
            end;
          end;
        finally
          PicStream.Free;
        end;
      end;
    end;

    // ----- TReportMemoObject extra fields -----
    if Obj is TReportMemoObject then
    begin
      Memo := TReportMemoObject(Obj);
      Memo.AutoHeight := O.GetValue<Boolean>('AutoHeight', True);
      Memo.MinHeight  := O.GetValue<Integer>('MinHeight',  20);
    end;

    // ----- TReportLineObject fields -----
    if Obj is TReportLineObject then
    begin
      Ln := TReportLineObject(Obj);
      Ln.Orientation := TLineOrientation(O.GetValue<Integer>('Orientation', 0));
      Ln.LineColor   := O.GetValue<Integer>('LineColor', Integer(clBlack));
      Ln.LineWidth   := O.GetValue<Integer>('LineWidth', 1);
      Ln.LineStyle   := TPenStyle(O.GetValue<Integer>('LineStyle', 0));
    end;

    // ----- TReportBand fields + children -----
    if Obj is TReportBand then
    begin
      Band := TReportBand(Obj);
      Band.BandType             := TReportBandType(O.GetValue<Integer>('BandType',    0));
      Band.Height               := O.GetValue<Integer>('Height',       40);
      Band.GroupField           := O.GetValue<string>('GroupField',    '');
      Band.GroupLevel           := O.GetValue<Integer>('GroupLevel',   0);
      Band.StartNewPage         := O.GetValue<Boolean>('StartNewPage', False);
      Band.CanGrow              := O.GetValue<Boolean>('CanGrow',      False);
      Band.CanShrink            := O.GetValue<Boolean>('CanShrink',    False);
      Band.BackColor            := O.GetValue<Integer>('BackColor',    Integer(clWhite));
      Band.BackColorTransparent := O.GetValue<Boolean>('BackColorTransparent', True);

      ChildArr := O.GetValue<TJSONArray>('Children');
      if Assigned(ChildArr) then
        for i := 0 to ChildArr.Count - 1 do
          Band.Children.Add(
            JSONToObject(ChildArr.Items[i] as TJSONObject));
    end;

    Result := Obj;
  except
    Obj.Free;
    raise;
  end;
end;

// ---------------------------------------------------------------------------
// PageSettings â†” JSON
// ---------------------------------------------------------------------------

function PageSettingsToJSON(PS: TReportPageSettings): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('PaperSize',    TJSONNumber.Create(Ord(PS.PaperSize)));
  Result.AddPair('Orientation',  TJSONNumber.Create(Ord(PS.Orientation)));
  Result.AddPair('MarginLeft',   TJSONNumber.Create(PS.Margins.Left));
  Result.AddPair('MarginTop',    TJSONNumber.Create(PS.Margins.Top));
  Result.AddPair('MarginRight',  TJSONNumber.Create(PS.Margins.Right));
  Result.AddPair('MarginBottom', TJSONNumber.Create(PS.Margins.Bottom));
  Result.AddPair('CustomWidth',  TJSONNumber.Create(PS.CustomWidth));
  Result.AddPair('CustomHeight', TJSONNumber.Create(PS.CustomHeight));
end;

procedure JSONToPageSettings(O: TJSONObject; PS: TReportPageSettings);
var
  M: TReportMargins;
begin
  if not Assigned(O) then Exit;

  PS.PaperSize   := TReportPaperSize(O.GetValue<Integer>('PaperSize',   0));
  PS.Orientation := TReportOrientation(O.GetValue<Integer>('Orientation', 0));
  PS.CustomWidth  := O.GetValue<Integer>('CustomWidth',  793);
  PS.CustomHeight := O.GetValue<Integer>('CustomHeight', 1122);

  M.Left   := O.GetValue<Integer>('MarginLeft',   40);
  M.Top    := O.GetValue<Integer>('MarginTop',    40);
  M.Right  := O.GetValue<Integer>('MarginRight',  40);
  M.Bottom := O.GetValue<Integer>('MarginBottom', 40);
  PS.Margins := M;
end;

// ---------------------------------------------------------------------------
// Clone helpers
// ---------------------------------------------------------------------------

class function TReportSerializer.CloneObject(Obj: TReportObject): TReportObject;
var
  J: TJSONObject;
begin
  J := ObjectToJSON(Obj);
  try
    Result := JSONToObject(J);
  finally
    J.Free;
  end;
end;

class function TReportSerializer.CloneReport(R: TReportModel): TReportModel;
var
  Root: TJSONObject;
  Arr : TJSONArray;
  Obj : TReportObject;
  JSON: string;
  i   : Integer;
begin
  if not Assigned(R) then
    raise Exception.Create('Report model must be assigned.');

  { Serialize to an in-memory JSON string -- no disk I/O, no temp-file risks }
  Root := TJSONObject.Create;
  try
    Root.AddPair('Version',      TJSONNumber.Create(2));
    Root.AddPair('Title',        R.Title);
    Root.AddPair('Author',       R.Author);
    Root.AddPair('Description',  R.Description);
    Root.AddPair('PageSettings', PageSettingsToJSON(R.PageSettings));

    Arr := TJSONArray.Create;
    for Obj in R.Objects do
      Arr.AddElement(ObjectToJSON(Obj));
    Root.AddPair('Objects', Arr);

    JSON := Root.ToJSON;
  finally
    Root.Free;
  end;

  { Deserialize from the string back into a fresh TReportModel }
  Root := nil;
  try
    Root := TJSONObject.ParseJSONValue(JSON) as TJSONObject;
    if not Assigned(Root) then
      raise Exception.Create('CloneReport: JSON round-trip produced invalid output');

    Result := TReportModel.Create;
    try
      Result.Title       := Root.GetValue<string>('Title',       '');
      Result.Author      := Root.GetValue<string>('Author',      '');
      Result.Description := Root.GetValue<string>('Description', '');
      JSONToPageSettings(Root.GetValue<TJSONObject>('PageSettings'), Result.PageSettings);

      Arr := Root.GetValue<TJSONArray>('Objects');
      if Assigned(Arr) then
        for i := 0 to Arr.Count - 1 do
          Result.Objects.Add(JSONToObject(Arr.Items[i] as TJSONObject));
    except
      Result.Free;
      raise;
    end;
  finally
    Root.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Save
// ---------------------------------------------------------------------------

class procedure TReportSerializer.SaveToFile(R: TReportModel; const FN: string);
var
  Root: TJSONObject;
  Arr:  TJSONArray;
  Obj:  TReportObject;
begin
  if not Assigned(R) then
    raise Exception.Create('Report model must be assigned.');

  Root := TJSONObject.Create;
  try
    Root.AddPair('Version',     TJSONNumber.Create(2));
    Root.AddPair('Title',       R.Title);
    Root.AddPair('Author',      R.Author);
    Root.AddPair('Description', R.Description);
    Root.AddPair('PageSettings', PageSettingsToJSON(R.PageSettings));

    Arr := TJSONArray.Create;
    for Obj in R.Objects do
      Arr.AddElement(ObjectToJSON(Obj));
    Root.AddPair('Objects', Arr);

    TFile.WriteAllText(FN, Root.Format(2), TEncoding.UTF8);
  finally
    Root.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Load
// ---------------------------------------------------------------------------

class function TReportSerializer.LoadFromFile(const FN: string): TReportModel;
var
  Root: TJSONObject;
  Arr:  TJSONArray;
  i:    Integer;
  S:    string;
begin
  if not TFile.Exists(FN) then
    raise Exception.CreateFmt('Report file not found: "%s"', [FN]);

  S    := TFile.ReadAllText(FN, TEncoding.UTF8);
  Root := nil;
  try
    try
      Root := TJSONObject.ParseJSONValue(S) as TJSONObject;
    except
      raise Exception.Create('Invalid JSON format in report file');
    end;

    if not Assigned(Root) then
      raise Exception.Create('Invalid JSON format in report file');

    Result := TReportModel.Create;
    try
      // Metadata
      Result.Title       := Root.GetValue<string>('Title',       '');
      Result.Author      := Root.GetValue<string>('Author',      '');
      Result.Description := Root.GetValue<string>('Description', '');

      // Page settings (v2+; silently absent in v1 files)
      JSONToPageSettings(
        Root.GetValue<TJSONObject>('PageSettings'),
        Result.PageSettings);

      // Objects (bands + their children)
      Arr := Root.GetValue<TJSONArray>('Objects');
      if Assigned(Arr) then
        for i := 0 to Arr.Count - 1 do
          Result.Objects.Add(
            JSONToObject(Arr.Items[i] as TJSONObject));

    except
      Result.Free;
      raise;
    end;

  finally
    Root.Free;
  end;
end;

end.
