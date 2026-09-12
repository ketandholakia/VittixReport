unit Vittix.Report.Serializer;

(*
  Vittix.Report.Serializer
  ========================
  Saves and loads a TReportModel to/from a UTF-8 JSON file (.vrt).

  JSON structure (v2)
  -------------------
  Each band in Objects[] includes a Children[] array (was missing in v1).
  PageSettings is persisted as a nested object.
  FieldNames[] array added: column names embedded so the standalone designer
  can populate its "Dataset Fields" panel without a live DB connection.

  Versioning
  ----------
  Reading a v1 file (no Version key, no FieldNames) still works fine.

  Cloning
  -------
  CloneObject - deep-clones a single TReportObject (text or band + children)
  CloneReport - deep-clones an entire TReportModel (serialize -> deserialize)

  Transactional Loading (Phase 4I-18)
  -----------------------------------
  New loading methods return TReportLoadResult, which owns the deserialized
  model and provides structured diagnostics.  A failed load never corrupts
  the active model.

    LoadFromJSON(Result, FileName)  - transactional load from JSON string
    LoadFromFile(Result, FileName)  - transactional load from file

  Unknown Object Strategy
  -----------------------
  Unknown classes are preserved as TReportUnknownObject instances that store
  the raw JSON fragment.  This prevents silent data loss when loading a
  report from a newer version.  On save, the raw JSON is written back
  verbatim.

  Legacy Methods
  --------------
  LoadFromJSON, LoadFromFile, LoadFromJSONTolerant are preserved as
  convenience wrappers.  New code should prefer the transactional API.
*)

interface

uses
  System.UITypes, System.SysUtils,
  System.Classes,
  System.JSON,
  System.Types,
  System.IOUtils,
  System.Generics.Collections,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.PageSettings,
  Vittix.Report.LoadResult;

type
  TReportSerializer = class
  public
    { Save }
    class procedure SaveToFile(R: TReportModel; const FN: string);
    class function  SaveToJSON(R: TReportModel): string;

    { --- Transactional Loading (preferred API) --- }

    /// <summary>
    ///   Transactionally load a report from a JSON string.
    ///   On success, owns the deserialized model in Result.Model.
    ///   On failure, Result.Success = False and Result.Errors explains why.
    ///   The caller owns the returned TReportLoadResult (and must free it).
    /// </summary>
    class function LoadFromJSONEx(const S: string;
      const AStrict: Boolean = True): TReportLoadResult;

    /// <summary>
    ///   Transactionally load a report from a file.
    ///   On success, owns the deserialized model in Result.Model.
    ///   On failure, Result.Success = False and Result.Errors explains why.
    ///   The caller owns the returned TReportLoadResult (and must free it).
    /// </summary>
    class function LoadFromFileEx(const FN: string): TReportLoadResult;

    { --- Legacy Loading (backward-compatible) --- }

    /// <summary>
    ///   Legacy strict loader.  Raises on unknown class or invalid JSON.
    ///   For new code, prefer LoadFromJSONEx which returns a result instead of raising.
    /// </summary>
    class function LoadFromJSON(const S: string): TReportModel;

    /// <summary>
    ///   Legacy loader from file.  Raises on unknown class or invalid JSON.
    ///   For new code, prefer LoadFromFileEx which returns a result instead of raising.
    /// </summary>
    class function LoadFromFile(const FN: string): TReportModel;

    /// <summary>
    ///   Legacy tolerant loader.  Skips unknown classes, returns warnings.
    ///   Preserved for backward compatibility.
    /// </summary>
    class function LoadFromJSONTolerant(const S: string;
      out AWarnings: TArray<string>): TReportModel;

    { --- Cloning --- }

    /// <summary>Deep-clone a single object (band + its children, or leaf object).</summary>
    class function CloneObject(Obj: TReportObject): TReportObject;

    /// <summary>Deep-clone an entire report model via serialize -> deserialize.</summary>
    class function CloneReport(R: TReportModel): TReportModel;

    { --- Clipboard --- }

    /// <summary>Serialize a list of objects to a JSON string.</summary>
    class function SerializeObjectListToJSON(const Objects: TArray<TReportObject>): string;

    /// <summary>Deserialize a list of objects from a JSON string.</summary>
    class function DeserializeObjectListFromJSON(const S: string): TArray<TReportObject>;

  private
    /// <summary>
    ///   Internal method to load objects from a JSON array.
    ///   APreserveUnknown determines whether unknown classes are preserved
    ///   as TReportUnknownObject instances (tolerant) or cause errors (strict).
    ///   AOwner is the list that receives the loaded objects: nil means the
    ///   top-level Model.Objects; band loading passes the band's own Children
    ///   list so band children are owned by the band and never duplicated
    ///   into the top-level model.
    /// </summary>
    class procedure LoadObjectsEx(Arr: TJSONArray; AVersion: Integer;
      APreserveUnknown: Boolean; AResult: TReportLoadResult;
      const APathPrefix: string; AOwner: TObjectList<TReportObject>);
  end;

{ Exposed so units like the designer can reuse serialisation of single objects }
function ObjectToJSON(Obj: TReportObject): TJSONObject;
function JSONToObject(O: TJSONObject): TReportObject;
function JSONToObjectEx(O: TJSONObject; AVersion: Integer): TReportObject; forward;

implementation

uses
  System.NetEncoding,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Imaging.pngimage,
  Vcl.Imaging.Jpeg,
  Vcl.Imaging.gifimg,
  Vittix.Report.Objects.Table,
  Vittix.Report.Objects.CrossTab,
  Vittix.Report.Objects.Chart,
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Objects.Unknown;

function PageSettingsToJSON(PS: TReportPageSettings): TJSONObject; forward;
procedure JSONToPageSettings(O: TJSONObject; PS: TReportPageSettings); forward;

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
  if not Assigned(O) then
    Exit(Rect(0, 0, 0, 0));
  Result := Rect(
    Trunc(O.GetValue<Double>('L')),
    Trunc(O.GetValue<Double>('T')),
    Trunc(O.GetValue<Double>('R')),
    Trunc(O.GetValue<Double>('B'))
  );
end;

// ---------------------------------------------------------------------------
// Font helpers
// ---------------------------------------------------------------------------

function FontToJSON(F: TFont): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Name',  F.Name);
  Result.AddPair('Size',  TJSONNumber.Create(F.Size));
  Result.AddPair('Color', TJSONNumber.Create(F.Color));
  Result.AddPair('Bold',  TJSONBool.Create(fsBold in F.Style));
  Result.AddPair('Italic', TJSONBool.Create(fsItalic in F.Style));
end;

procedure JSONToFont(O: TJSONObject; F: TFont);
begin
  F.Name := O.GetValue<string>('Name', 'Tahoma');
  F.Size := Trunc(O.GetValue<Double>('Size', 10));
  F.Color := Trunc(O.GetValue<Double>('Color', clBlack));
  var Style: TFontStyles := [];
  if O.GetValue<Boolean>('Bold', False) then Include(Style, fsBold);
  if O.GetValue<Boolean>('Italic', False) then Include(Style, fsItalic);
  F.Style := Style;
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


type
  TReportObjectSerializer = class
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); virtual;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); virtual;
  end;
  TReportObjectSerializerClass = class of TReportObjectSerializer;

  TReportTextObjectSerializer = class(TReportObjectSerializer)
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); override;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); override;
  end;

  TReportShapeObjectSerializer = class(TReportObjectSerializer)
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); override;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); override;
  end;

  TReportImageObjectSerializer = class(TReportObjectSerializer)
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); override;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); override;
  end;

  TReportMemoObjectSerializer = class(TReportTextObjectSerializer)
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); override;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); override;
  end;

  TReportFieldObjectSerializer = class(TReportTextObjectSerializer)
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); override;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); override;
  end;

  TReportSubReportObjectSerializer = class(TReportObjectSerializer)
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); override;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); override;
  end;

  TReportLineObjectSerializer = class(TReportObjectSerializer)
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); override;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); override;
  end;

  TReportBarcodeObjectSerializer = class(TReportObjectSerializer)
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); override;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); override;
  end;

  TReportTableObjectSerializer = class(TReportObjectSerializer)
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); override;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); override;
  end;

  TReportCrossTabObjectSerializer = class(TReportObjectSerializer)
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); override;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); override;
  end;

  TReportChartObjectSerializer = class(TReportObjectSerializer)
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); override;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); override;
  end;

  TReportBandSerializer = class(TReportObjectSerializer)
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); override;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); override;
  end;

  TReportUnknownObjectSerializer = class(TReportObjectSerializer)
  public
    class procedure SaveProperties(Obj: TReportObject; JSON: TJSONObject); override;
    class procedure LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer); override;
  end;

var
  GSerializers: TDictionary<TReportObjectClass, TReportObjectSerializerClass>;

function GetSerializer(Cls: TReportObjectClass): TReportObjectSerializerClass;
var
  CurrCls: TClass;
begin
  if not Assigned(GSerializers) then
  begin
    GSerializers := TDictionary<TReportObjectClass, TReportObjectSerializerClass>.Create;
    GSerializers.Add(TReportObject, TReportObjectSerializer);
    GSerializers.Add(TReportTextObject, TReportTextObjectSerializer);
    GSerializers.Add(TReportLabelObject, TReportTextObjectSerializer);
    GSerializers.Add(TReportShapeObject, TReportShapeObjectSerializer);
    GSerializers.Add(TReportImageObject, TReportImageObjectSerializer);
    GSerializers.Add(TReportMemoObject, TReportMemoObjectSerializer);
    GSerializers.Add(TReportFieldObject, TReportFieldObjectSerializer);
    GSerializers.Add(TReportSubReportObject, TReportSubReportObjectSerializer);
    GSerializers.Add(TReportLineObject, TReportLineObjectSerializer);
    GSerializers.Add(TReportBarcodeObject, TReportBarcodeObjectSerializer);
    GSerializers.Add(TReportTableObject, TReportTableObjectSerializer);
    GSerializers.Add(TReportCrossTabObject, TReportCrossTabObjectSerializer);
    GSerializers.Add(TReportChartObject, TReportChartObjectSerializer);
    GSerializers.Add(TReportBand, TReportBandSerializer);
    GSerializers.Add(TReportUnknownObject, TReportUnknownObjectSerializer);
  end;

  CurrCls := Cls;
  while CurrCls <> nil do
  begin
    if GSerializers.TryGetValue(TReportObjectClass(CurrCls), Result) then
      Exit;
    CurrCls := CurrCls.ClassParent;
  end;
  Result := TReportObjectSerializer;
end;

{ TReportObjectSerializer }

class procedure TReportObjectSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
begin
  JSON.AddPair('Class',        Obj.ClassName);
  JSON.AddPair('Name',         Obj.Name);
  JSON.AddPair('Bounds',       RectToJSON(Obj.Bounds));
  JSON.AddPair('Visible',      TJSONBool.Create(Obj.Visible));
  JSON.AddPair('PrintWhen',    Obj.PrintWhen);
  JSON.AddPair('AnchorRight',  TJSONBool.Create(Obj.AnchorRight));
  JSON.AddPair('AnchorBottom', TJSONBool.Create(Obj.AnchorBottom));
  JSON.AddPair('PageBreakBefore', TJSONBool.Create(Obj.PageBreakBefore));
  JSON.AddPair('PageBreakAfter',  TJSONBool.Create(Obj.PageBreakAfter));
  JSON.AddPair('Locked',          TJSONBool.Create(Obj.Locked));
  if not (Obj is TReportBand) then
  begin
    if Trim(Obj.OnBeforePrint) <> '' then
      JSON.AddPair('OnBeforePrint', Obj.OnBeforePrint);
    if Trim(Obj.OnAfterPrint) <> '' then
      JSON.AddPair('OnAfterPrint', Obj.OnAfterPrint);
  end;
end;

class procedure TReportObjectSerializer.LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer);
begin
  Obj.Name         := JSON.GetValue<string>('Name',   '');
  if Assigned(JSON.GetValue('Bounds')) then Obj.Bounds := JSONToRect(JSON.GetValue('Bounds') as TJSONObject);
  Obj.Visible      := JSON.GetValue<Boolean>('Visible',      True);
  Obj.PrintWhen    := JSON.GetValue<string>('PrintWhen',     '');
  Obj.OnBeforePrint:= JSON.GetValue<string>('OnBeforePrint', '');
  Obj.OnAfterPrint := JSON.GetValue<string>('OnAfterPrint',  '');
  Obj.AnchorRight  := JSON.GetValue<Boolean>('AnchorRight',  False);
  Obj.AnchorBottom := JSON.GetValue<Boolean>('AnchorBottom', False);
  Obj.PageBreakBefore := JSON.GetValue<Boolean>('PageBreakBefore', False);
  Obj.PageBreakAfter  := JSON.GetValue<Boolean>('PageBreakAfter',  False);
  Obj.Locked          := JSON.GetValue<Boolean>('Locked',          False);
end;

{ TReportTextObjectSerializer }

class procedure TReportTextObjectSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
var
  T: TReportTextObject;
begin
  inherited;
  T := TReportTextObject(Obj);
  JSON.AddPair('Text',          T.Text);
  JSON.AddPair('DataField',      T.DataField);
  JSON.AddPair('Expression',     T.Expression);
  JSON.AddPair('FontName',       T.Font.Name);
  JSON.AddPair('FontSize',       TJSONNumber.Create(T.Font.Size));
  JSON.AddPair('FontColor',      TJSONNumber.Create(T.Font.Color));
  JSON.AddPair('FontBold',       TJSONBool.Create(fsBold   in T.Font.Style));
  JSON.AddPair('FontItalic',     TJSONBool.Create(fsItalic in T.Font.Style));
  JSON.AddPair('HAlign',         TJSONNumber.Create(Ord(T.HAlign)));
  JSON.AddPair('VAlign',         TJSONNumber.Create(Ord(T.VAlign)));
  JSON.AddPair('Background',     TJSONNumber.Create(T.Background));
  JSON.AddPair('Transparent',    TJSONBool.Create(T.Transparent));
  JSON.AddPair('BorderVisible',  TJSONBool.Create(T.BorderVisible));
  JSON.AddPair('BorderColor',    TJSONNumber.Create(T.BorderColor));
  JSON.AddPair('BorderWidth',    TJSONNumber.Create(T.BorderWidth));
  JSON.AddPair('WordWrap',       TJSONBool.Create(T.WordWrap));
  JSON.AddPair('AutoSize',       TJSONBool.Create(T.AutoSize));
  JSON.AddPair('PaddingLeft',    TJSONNumber.Create(T.PaddingLeft));
  JSON.AddPair('PaddingTop',     TJSONNumber.Create(T.PaddingTop));
  JSON.AddPair('PaddingRight',   TJSONNumber.Create(T.PaddingRight));
  JSON.AddPair('PaddingBottom',  TJSONNumber.Create(T.PaddingBottom));
  JSON.AddPair('FontColorCondition',   T.FontColorCondition);
  JSON.AddPair('FontColorOnTrue',      TJSONNumber.Create(T.FontColorOnTrue));
  JSON.AddPair('BackgroundCondition',  T.BackgroundCondition);
  JSON.AddPair('BackgroundOnTrue',     TJSONNumber.Create(T.BackgroundOnTrue));
  JSON.AddPair('BorderColorCondition', T.BorderColorCondition);
  JSON.AddPair('BorderColorOnTrue',    TJSONNumber.Create(T.BorderColorOnTrue));
end;

class procedure TReportTextObjectSerializer.LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer);
var
  T: TReportTextObject;
  Style: TFontStyles;
begin
  inherited;
  T := TReportTextObject(Obj);
  T.Text        := JSON.GetValue<string>('Text',       '');
  T.DataField   := JSON.GetValue<string>('DataField',  '');
  T.Expression  := JSON.GetValue<string>('Expression', '');
  T.Font.Name   := JSON.GetValue<string>('FontName',   'Tahoma');
  T.Font.Size   := Trunc(JSON.GetValue<Double>('FontSize',  10));
  T.Font.Color  := Trunc(JSON.GetValue<Double>('FontColor', 0));
  Style := [];
  if JSON.GetValue<Boolean>('FontBold',   False) then Include(Style, fsBold);
  if JSON.GetValue<Boolean>('FontItalic', False) then Include(Style, fsItalic);
  T.Font.Style     := Style;
  T.HAlign         := TAlignment(Trunc(JSON.GetValue<Double>('HAlign',  0)));
  T.VAlign         := TVerticalAlignment(Trunc(JSON.GetValue<Double>('VAlign', 2)));
  T.Background     := Trunc(JSON.GetValue<Double>('Background',    Integer(clWhite)));
  T.Transparent    := JSON.GetValue<Boolean>('Transparent',   True);
  T.BorderVisible  := JSON.GetValue<Boolean>('BorderVisible', False);
  T.BorderColor    := Trunc(JSON.GetValue<Double>('BorderColor',   Integer(clBlack)));
  T.BorderWidth    := Trunc(JSON.GetValue<Double>('BorderWidth',   1));
  T.WordWrap       := JSON.GetValue<Boolean>('WordWrap',      False);
  T.AutoSize       := JSON.GetValue<Boolean>('AutoSize',      False);
  T.PaddingLeft    := Trunc(JSON.GetValue<Double>('PaddingLeft',   2));
  T.PaddingTop     := Trunc(JSON.GetValue<Double>('PaddingTop',    2));
  T.PaddingRight   := Trunc(JSON.GetValue<Double>('PaddingRight',  2));
  T.PaddingBottom  := Trunc(JSON.GetValue<Double>('PaddingBottom', 2));
  T.FontColorCondition   := JSON.GetValue<string>('FontColorCondition',   '');
  T.FontColorOnTrue      := Trunc(JSON.GetValue<Double>('FontColorOnTrue',      Integer(clRed)));
  T.BackgroundCondition  := JSON.GetValue<string>('BackgroundCondition',  '');
  T.BackgroundOnTrue     := Trunc(JSON.GetValue<Double>('BackgroundOnTrue',     Integer(clYellow)));
  T.BorderColorCondition := JSON.GetValue<string>('BorderColorCondition', '');
  T.BorderColorOnTrue    := Trunc(JSON.GetValue<Double>('BorderColorOnTrue',    Integer(clRed)));
end;

{ TReportShapeObjectSerializer }

class procedure TReportShapeObjectSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
var
  Sh: TReportShapeObject;
begin
  inherited;
  Sh := TReportShapeObject(Obj);
  JSON.AddPair('ShapeType',    TJSONNumber.Create(Ord(Sh.ShapeType)));
  JSON.AddPair('PenColor',     TJSONNumber.Create(Sh.PenColor));
  JSON.AddPair('PenWidth',     TJSONNumber.Create(Sh.PenWidth));
  JSON.AddPair('PenStyle',     TJSONNumber.Create(Ord(Sh.PenStyle)));
  JSON.AddPair('BrushColor',   TJSONNumber.Create(Sh.BrushColor));
  JSON.AddPair('BrushStyle',   TJSONNumber.Create(Ord(Sh.BrushStyle)));
  JSON.AddPair('CornerRadius', TJSONNumber.Create(Sh.CornerRadius));
end;

class procedure TReportShapeObjectSerializer.LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer);
var
  Sh: TReportShapeObject;
begin
  inherited;
  Sh := TReportShapeObject(Obj);
  Sh.ShapeType    := TReportShapeType(Trunc(JSON.GetValue<Double>('ShapeType', 0)));
  Sh.PenColor     := Trunc(JSON.GetValue<Double>('PenColor',   Integer(clBlack)));
  Sh.PenWidth     := Trunc(JSON.GetValue<Double>('PenWidth',   1));
  Sh.PenStyle     := TPenStyle(Trunc(JSON.GetValue<Double>('PenStyle',   0)));
  Sh.BrushColor   := Trunc(JSON.GetValue<Double>('BrushColor', Integer(clWhite)));
  Sh.BrushStyle   := TBrushStyle(Trunc(JSON.GetValue<Double>('BrushStyle', 0)));
  Sh.CornerRadius := Trunc(JSON.GetValue<Double>('CornerRadius', 12));
end;

{ TReportImageObjectSerializer }

class procedure TReportImageObjectSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
var
  Img: TReportImageObject;
  PicStream: TMemoryStream;
  PicBytes: TBytes;
begin
  inherited;
  Img := TReportImageObject(Obj);
  JSON.AddPair('Stretch',       TJSONBool.Create(Img.Stretch));
  JSON.AddPair('Center',        TJSONBool.Create(Img.Center));
  JSON.AddPair('Proportional',  TJSONBool.Create(Img.Proportional));
  JSON.AddPair('BorderVisible', TJSONBool.Create(Img.BorderVisible));
  JSON.AddPair('BorderColor',   TJSONNumber.Create(Img.BorderColor));
  JSON.AddPair('BorderWidth',   TJSONNumber.Create(Img.BorderWidth));
  JSON.AddPair('DataField',     Img.DataField);
  if Assigned(Img.Picture.Graphic) and not Img.Picture.Graphic.Empty then
  begin
    PicStream := TMemoryStream.Create;
    try
      Img.Picture.Graphic.SaveToStream(PicStream);
      SetLength(PicBytes, PicStream.Size);
      Move(PicStream.Memory^, PicBytes[0], PicStream.Size);
      JSON.AddPair('PictureData',  TNetEncoding.Base64.EncodeBytesToString(PicBytes));
      JSON.AddPair('PictureClass', Img.Picture.Graphic.ClassName);
    finally
      PicStream.Free;
    end;
  end;
end;

class procedure TReportImageObjectSerializer.LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer);
var
  Img: TReportImageObject;
  PicData, PicClass: string;
  PicBytes: TBytes;
  PicStream: TMemoryStream;
  PicClassRef: TPersistentClass;
  PicGraphic: TGraphicClass;
  G: TGraphic;
begin
  inherited;
  Img := TReportImageObject(Obj);
  Img.Stretch       := JSON.GetValue<Boolean>('Stretch',       True);
  Img.Center        := JSON.GetValue<Boolean>('Center',        True);
  Img.Proportional  := JSON.GetValue<Boolean>('Proportional',  True);
  Img.BorderVisible := JSON.GetValue<Boolean>('BorderVisible', False);
  Img.BorderColor   := Trunc(JSON.GetValue<Double>('BorderColor',   Integer(clBlack)));
  Img.BorderWidth   := Trunc(JSON.GetValue<Double>('BorderWidth',   1));
  Img.DataField     := JSON.GetValue<string>('DataField',      '');
  PicData  := JSON.GetValue<string>('PictureData',  '');
  PicClass := JSON.GetValue<string>('PictureClass', '');
  if (PicData <> '') and (PicClass <> '') then
  begin
    PicBytes  := TNetEncoding.Base64.DecodeStringToBytes(PicData);
    if Length(PicBytes) > 0 then
    begin
      PicStream := TMemoryStream.Create;
      try
        PicStream.WriteBuffer(PicBytes[0], Length(PicBytes));
        PicStream.Position := 0;
        PicClassRef := GetClass(PicClass);
        if Assigned(PicClassRef) and PicClassRef.InheritsFrom(TGraphic) then
        begin
          PicGraphic := TGraphicClass(PicClassRef);
          G := PicGraphic.Create;
          try
            try
              G.LoadFromStream(PicStream);
              Img.Picture.Assign(G);
            except
              // Corrupt/invalid embedded image data: keep the picture empty
              // (best-effort, matching the Draw path's handling of invalid
              // image files) instead of aborting the whole report load.
              // Only the graphic decode/assign operation is guarded; JSON
              // and property errors elsewhere still propagate.
            end;
          finally
            G.Free;
          end;
        end;
      finally
        PicStream.Free;
      end;
    end;
  end;
end;

{ TReportMemoObjectSerializer }

class procedure TReportMemoObjectSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
var
  Memo: TReportMemoObject;
begin
  inherited;
  Memo := TReportMemoObject(Obj);
  JSON.AddPair('AutoHeight', TJSONBool.Create(Memo.AutoHeight));
  JSON.AddPair('MinHeight',  TJSONNumber.Create(Memo.MinHeight));
  JSON.AddPair('AllowHTML',  TJSONBool.Create(Memo.AllowHTML));
end;

class procedure TReportMemoObjectSerializer.LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer);
var
  Memo: TReportMemoObject;
begin
  inherited;
  Memo := TReportMemoObject(Obj);
  Memo.AutoHeight := JSON.GetValue<Boolean>('AutoHeight', True);
  Memo.MinHeight  := Trunc(JSON.GetValue<Double>('MinHeight',  20));
  Memo.AllowHTML  := JSON.GetValue<Boolean>('AllowHTML',  False);
end;

{ TReportFieldObjectSerializer }

class procedure TReportFieldObjectSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
var
  Fld: TReportFieldObject;
begin
  inherited;
  Fld := TReportFieldObject(Obj);
  JSON.AddPair('DisplayFormat', Fld.DisplayFormat);
  JSON.AddPair('EditMask',      Fld.EditMask);
end;

class procedure TReportFieldObjectSerializer.LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer);
var
  Fld: TReportFieldObject;
begin
  inherited;
  Fld := TReportFieldObject(Obj);
  Fld.DisplayFormat := JSON.GetValue<string>('DisplayFormat', '');
  Fld.EditMask      := JSON.GetValue<string>('EditMask',      '');
end;

{ TReportSubReportObjectSerializer }

class procedure TReportSubReportObjectSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
var
  SubRep: TReportSubReportObject;
begin
  inherited;
  SubRep := TReportSubReportObject(Obj);
  JSON.AddPair('SubReportJSON', SubRep.ReportJSON);
  JSON.AddPair('DataSetName',   SubRep.DataSetName);
  JSON.AddPair('MasterField',   SubRep.MasterField);
  JSON.AddPair('DetailField',   SubRep.DetailField);
  JSON.AddPair('Transparent',   TJSONBool.Create(SubRep.Transparent));
  JSON.AddPair('Background',    TJSONNumber.Create(SubRep.Background));
  JSON.AddPair('BorderVisible', TJSONBool.Create(SubRep.BorderVisible));
  JSON.AddPair('BorderColor',   TJSONNumber.Create(SubRep.BorderColor));
  JSON.AddPair('BorderWidth',   TJSONNumber.Create(SubRep.BorderWidth));
end;

class procedure TReportSubReportObjectSerializer.LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer);
var
  SubRep: TReportSubReportObject;
begin
  inherited;
  SubRep := TReportSubReportObject(Obj);
  SubRep.ReportJSON   := JSON.GetValue<string>('SubReportJSON', '');
  SubRep.DataSetName  := JSON.GetValue<string>('DataSetName',   '');
  SubRep.MasterField  := JSON.GetValue<string>('MasterField',   '');
  SubRep.DetailField  := JSON.GetValue<string>('DetailField',   '');
  SubRep.Transparent  := JSON.GetValue<Boolean>('Transparent',  True);
  SubRep.Background   := Trunc(JSON.GetValue<Double>('Background',   Integer(clWhite)));
  SubRep.BorderVisible:= JSON.GetValue<Boolean>('BorderVisible', True);
  SubRep.BorderColor  := Trunc(JSON.GetValue<Double>('BorderColor', Integer(clSilver)));
  SubRep.BorderWidth  := Trunc(JSON.GetValue<Double>('BorderWidth', 1));
end;

{ TReportLineObjectSerializer }

class procedure TReportLineObjectSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
var
  Ln: TReportLineObject;
begin
  inherited;
  Ln := TReportLineObject(Obj);
  JSON.AddPair('Orientation', TJSONNumber.Create(Ord(Ln.Orientation)));
  JSON.AddPair('LineColor',   TJSONNumber.Create(Ln.LineColor));
  JSON.AddPair('LineWidth',   TJSONNumber.Create(Ln.LineWidth));
  JSON.AddPair('LineStyle',   TJSONNumber.Create(Ord(Ln.LineStyle)));
  JSON.AddPair('ExtendToPageBottom', TJSONBool.Create(Ln.ExtendToPageBottom));
end;

class procedure TReportLineObjectSerializer.LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer);
var
  Ln: TReportLineObject;
begin
  inherited;
  Ln := TReportLineObject(Obj);
  Ln.Orientation := TLineOrientation(Trunc(JSON.GetValue<Double>('Orientation', 0)));
  Ln.LineColor   := Trunc(JSON.GetValue<Double>('LineColor', Integer(clBlack)));
  Ln.LineWidth   := Trunc(JSON.GetValue<Double>('LineWidth', 1));
  Ln.LineStyle   := TPenStyle(Trunc(JSON.GetValue<Double>('LineStyle', 0)));
  Ln.ExtendToPageBottom := JSON.GetValue<Boolean>('ExtendToPageBottom', False);
end;

{ TReportBarcodeObjectSerializer }

class procedure TReportBarcodeObjectSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
var
  Barcode: TReportBarcodeObject;
begin
  inherited;
  Barcode := TReportBarcodeObject(Obj);
  JSON.AddPair('Value',           Barcode.Value);
  JSON.AddPair('DataField',       Barcode.DataField);
  JSON.AddPair('Symbology',       TJSONNumber.Create(Ord(Barcode.Symbology)));
  JSON.AddPair('ErrorCorrection', TJSONNumber.Create(Ord(Barcode.ErrorCorrection)));
  JSON.AddPair('ShowText',        TJSONBool.Create(Barcode.ShowText));
  JSON.AddPair('BarColor',        TJSONNumber.Create(Barcode.BarColor));
  JSON.AddPair('BackgroundColor', TJSONNumber.Create(Barcode.BackgroundColor));
end;

class procedure TReportBarcodeObjectSerializer.LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer);
var
  Barcode: TReportBarcodeObject;
begin
  inherited;
  Barcode := TReportBarcodeObject(Obj);
  Barcode.Value           := JSON.GetValue<string>('Value', '1234567890');
  Barcode.DataField       := JSON.GetValue<string>('DataField', '');
  Barcode.Symbology       := TReportBarcodeSymbology(Trunc(JSON.GetValue<Double>('Symbology', 0)));
  Barcode.ErrorCorrection := TReportQRErrorCorrection(Trunc(JSON.GetValue<Double>('ErrorCorrection', Ord(qrMedium))));
  Barcode.ShowText        := JSON.GetValue<Boolean>('ShowText', True);
  Barcode.BarColor        := Trunc(JSON.GetValue<Double>('BarColor', Integer(clBlack)));
  Barcode.BackgroundColor := Trunc(JSON.GetValue<Double>('BackgroundColor', Integer(clWhite)));
end;

{ TReportTableObjectSerializer }

class procedure TReportTableObjectSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
var
  Table: TReportTableObject;
begin
  inherited;
  Table := TReportTableObject(Obj);
  JSON.AddPair('Rows',        TJSONNumber.Create(Table.Rows));
  JSON.AddPair('Cols',        TJSONNumber.Create(Table.Cols));
  JSON.AddPair('HeaderRows',  TJSONNumber.Create(Table.HeaderRows));
  JSON.AddPair('GridColor',   TJSONNumber.Create(Table.GridColor));
  JSON.AddPair('HeaderColor', TJSONNumber.Create(Table.HeaderColor));
end;

class procedure TReportTableObjectSerializer.LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer);
var
  Table: TReportTableObject;
begin
  inherited;
  Table := TReportTableObject(Obj);
  Table.Rows        := Trunc(JSON.GetValue<Double>('Rows', 4));
  Table.Cols        := Trunc(JSON.GetValue<Double>('Cols', 4));
  Table.HeaderRows  := Trunc(JSON.GetValue<Double>('HeaderRows', 1));
  Table.GridColor   := Trunc(JSON.GetValue<Double>('GridColor', Integer(clGray)));
  Table.HeaderColor := Trunc(JSON.GetValue<Double>('HeaderColor', $00F0F0F0));
end;

{ TReportCrossTabObjectSerializer }

class procedure TReportCrossTabObjectSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
var
  CT: TReportCrossTabObject;
begin
  inherited;
  CT := TReportCrossTabObject(Obj);
  JSON.AddPair('DataSetName', CT.DataSetName);
  JSON.AddPair('RowField',    CT.RowField);
  JSON.AddPair('ColumnField', CT.ColumnField);
  JSON.AddPair('CellField',   CT.CellField);
  JSON.AddPair('Aggregate',   TJSONNumber.Create(Ord(CT.Aggregate)));
  JSON.AddPair('ShowRowGrandTotals', TJSONBool.Create(CT.ShowRowGrandTotals));
  JSON.AddPair('ShowColGrandTotals', TJSONBool.Create(CT.ShowColGrandTotals));
  JSON.AddPair('GridColor',   TJSONNumber.Create(CT.GridColor));
  JSON.AddPair('HeaderColor', TJSONNumber.Create(CT.HeaderColor));
  JSON.AddPair('CellFormat',  CT.CellFormat);
  JSON.AddPair('Font',        FontToJSON(CT.Font));
  JSON.AddPair('HeaderFont',  FontToJSON(CT.HeaderFont));
end;

class procedure TReportCrossTabObjectSerializer.LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer);
var
  CT: TReportCrossTabObject;
  JFont, JHdrFont: TJSONObject;
begin
  inherited;
  CT := TReportCrossTabObject(Obj);
  CT.DataSetName := JSON.GetValue<string>('DataSetName', '');
  CT.RowField    := JSON.GetValue<string>('RowField', '');
  CT.ColumnField := JSON.GetValue<string>('ColumnField', '');
  CT.CellField   := JSON.GetValue<string>('CellField', '');
  CT.Aggregate   := TCrossTabAggregate(Trunc(JSON.GetValue<Double>('Aggregate', Ord(caSum))));
  CT.ShowRowGrandTotals := JSON.GetValue<Boolean>('ShowRowGrandTotals', True);
  CT.ShowColGrandTotals := JSON.GetValue<Boolean>('ShowColGrandTotals', True);
  CT.GridColor   := Trunc(JSON.GetValue<Double>('GridColor', Integer(clGray)));
  CT.HeaderColor := Trunc(JSON.GetValue<Double>('HeaderColor', $00F0F0F0));
  CT.CellFormat  := JSON.GetValue<string>('CellFormat', '');
  
  if Assigned(JSON.GetValue('Font')) then JFont := JSON.GetValue('Font') as TJSONObject else JFont := nil;
  if Assigned(JFont) then JSONToFont(JFont, CT.Font);
  
  if Assigned(JSON.GetValue('HeaderFont')) then JHdrFont := JSON.GetValue('HeaderFont') as TJSONObject else JHdrFont := nil;
  if Assigned(JHdrFont) then JSONToFont(JHdrFont, CT.HeaderFont);
end;

{ TReportChartObjectSerializer }

class procedure TReportChartObjectSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
var
  Chart: TReportChartObject;
begin
  inherited;
  Chart := TReportChartObject(Obj);
  JSON.AddPair('ChartType', TJSONNumber.Create(Ord(Chart.ChartType)));
  JSON.AddPair('DataSetName', Chart.DataSetName);
  JSON.AddPair('DataFieldLabel', Chart.DataFieldLabel);
  JSON.AddPair('DataFieldValue', Chart.DataFieldValue);
  JSON.AddPair('Title', Chart.Title);
  JSON.AddPair('ShowLegend', TJSONBool.Create(Chart.ShowLegend));
end;

class procedure TReportChartObjectSerializer.LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer);
var
  Chart: TReportChartObject;
begin
  inherited;
  Chart := TReportChartObject(Obj);
  Chart.ChartType := TChartType(Trunc(JSON.GetValue<Double>('ChartType', 0)));
  Chart.DataSetName := JSON.GetValue<string>('DataSetName', '');
  Chart.DataFieldLabel := JSON.GetValue<string>('DataFieldLabel', '');
  Chart.DataFieldValue := JSON.GetValue<string>('DataFieldValue', '');
  Chart.Title := JSON.GetValue<string>('Title', '');
  Chart.ShowLegend := JSON.GetValue<Boolean>('ShowLegend', True);
end;

{ TReportBandSerializer }

class procedure TReportBandSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
var
  Band: TReportBand;
  ChildArr: TJSONArray;
  Child: TReportObject;
begin
  inherited;
  Band := TReportBand(Obj);
  JSON.AddPair('BandType',            TJSONNumber.Create(Ord(Band.BandType)));
  JSON.AddPair('Height',              TJSONNumber.Create(Band.Height));
  JSON.AddPair('DataSetName',         Band.DataSetName);
  JSON.AddPair('MasterField',         Band.MasterField);
  JSON.AddPair('DetailField',         Band.DetailField);
  JSON.AddPair('GroupField',          Band.GroupField);
  JSON.AddPair('GroupLevel',          TJSONNumber.Create(Band.GroupLevel));
  JSON.AddPair('StartNewPage',        TJSONBool.Create(Band.StartNewPage));
  JSON.AddPair('CanGrow',             TJSONBool.Create(Band.CanGrow));
  JSON.AddPair('CanShrink',           TJSONBool.Create(Band.CanShrink));
  JSON.AddPair('BackColor',           TJSONNumber.Create(Band.BackColor));
  JSON.AddPair('BackColorTransparent',TJSONBool.Create(Band.BackColorTransparent));
  JSON.AddPair('BackColorCondition',  Band.BackColorCondition);
  JSON.AddPair('OverridePageSettings',TJSONBool.Create(Band.OverridePageSettings));
  JSON.AddPair('PageSettings',        PageSettingsToJSON(Band.PageSettings));
  JSON.AddPair('OnBeforePrint',       Band.OnBeforePrint);
  JSON.AddPair('OnAfterPrint',        Band.OnAfterPrint);

  ChildArr := TJSONArray.Create;
  for Child in Band.Children do
    ChildArr.AddElement(ObjectToJSON(Child));
  JSON.AddPair('Children', ChildArr);
end;

class procedure TReportBandSerializer.LoadProperties(Obj: TReportObject; JSON: TJSONObject; AVersion: Integer);
var
  Band: TReportBand;
  ChildArr: TJSONArray;
  ChildVal: TJSONValue;
  i: Integer;
begin
  inherited;
  Band := TReportBand(Obj);
  Band.BandType             := TReportBandType(Trunc(JSON.GetValue<Double>('BandType',    0)));
  Band.Height               := Trunc(JSON.GetValue<Double>('Height',       40));
  Band.DataSetName          := JSON.GetValue<string>('DataSetName',   '');
  Band.MasterField          := JSON.GetValue<string>('MasterField',   '');
  Band.DetailField          := JSON.GetValue<string>('DetailField',   '');
  Band.GroupField           := JSON.GetValue<string>('GroupField',    '');
  Band.GroupLevel           := Trunc(JSON.GetValue<Double>('GroupLevel',   0));
  Band.StartNewPage         := JSON.GetValue<Boolean>('StartNewPage', False);
  Band.CanGrow              := JSON.GetValue<Boolean>('CanGrow',      False);
  Band.CanShrink            := JSON.GetValue<Boolean>('CanShrink',    False);
  Band.BackColor            := Trunc(JSON.GetValue<Double>('BackColor',    Integer(clWhite)));
  Band.BackColorTransparent := JSON.GetValue<Boolean>('BackColorTransparent', True);
  Band.BackColorCondition   := JSON.GetValue<string>('BackColorCondition', '');
  Band.OverridePageSettings := JSON.GetValue<Boolean>('OverridePageSettings', False);
  if Assigned(JSON.GetValue('PageSettings')) then
    JSONToPageSettings(JSON.GetValue('PageSettings') as TJSONObject, Band.PageSettings);
  Band.OnBeforePrint        := JSON.GetValue<string>('OnBeforePrint', '');
  Band.OnAfterPrint         := JSON.GetValue<string>('OnAfterPrint',  '');

  // In v1, there was no Children array persisted.
  // We're loading v2+ here, but gracefully missing.  A present but non-array
  // value must not raise a raw invalid-typecast exception (Finding E): leave
  // the children empty and let the structured loader report the problem.
  ChildVal := JSON.GetValue('Children');
  if Assigned(ChildVal) and (ChildVal is TJSONArray) then
    ChildArr := TJSONArray(ChildVal)
  else
    ChildArr := nil;
  if Assigned(ChildArr) then
    for i := 0 to ChildArr.Count - 1 do
      Band.Children.Add(
        JSONToObjectEx(ChildArr.Items[i] as TJSONObject, AVersion));
end;

// ---------------------------------------------------------------------------
// Single TReportObject <-> JSON
// ---------------------------------------------------------------------------

function ObjectToJSON(Obj: TReportObject): TJSONObject;
begin
  Result := TJSONObject.Create;
  GetSerializer(TReportObjectClass(Obj.ClassType)).SaveProperties(Obj, Result);
end;

function JSONToObject(O: TJSONObject): TReportObject;
begin
  Result := JSONToObjectEx(O, 2); // Default to current version if called externally
end;

function JSONToObjectEx(O: TJSONObject; AVersion: Integer): TReportObject;
var
  Cls: TReportObjectClass;
  DiscriminatorValue: string;
begin
  // Resolve the object class from the primary 'Class' discriminator, with
  // the legacy 'Type' key accepted as a fallback.  The resolved value is
  // kept for diagnostics so the unknown-class error always names what the
  // document actually contained, even when only 'Type' (or neither key)
  // is present.
  if O.GetValue('Class') <> nil then
    DiscriminatorValue := O.GetValue('Class').Value
  else if O.GetValue('Type') <> nil then
    DiscriminatorValue := O.GetValue('Type').Value
  else
    DiscriminatorValue := '';

  if DiscriminatorValue <> '' then
    Cls := FindObjectClass(DiscriminatorValue)
  else
    Cls := nil;

  if not Assigned(Cls) then
    raise Exception.CreateFmt(
      'Unknown report object class: "%s"',
      [DiscriminatorValue]);

  Result := Cls.Create;
  try
    GetSerializer(Cls).LoadProperties(Result, O, AVersion);
  except
    Result.Free;
    raise;
  end;
end;

// ---------------------------------------------------------------------------
// PageSettings <-> JSON
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
  PS.PaperSize    := TReportPaperSize(Trunc(O.GetValue<Double>('PaperSize',   0)));
  PS.Orientation  := TReportOrientation(Trunc(O.GetValue<Double>('Orientation', 0)));
  PS.CustomWidth  := Trunc(O.GetValue<Double>('CustomWidth',  793));
  PS.CustomHeight := Trunc(O.GetValue<Double>('CustomHeight', 1122));
  M.Left   := Trunc(O.GetValue<Double>('MarginLeft',   40));
  M.Top    := Trunc(O.GetValue<Double>('MarginTop',    40));
  M.Right  := Trunc(O.GetValue<Double>('MarginRight',  40));
  M.Bottom := Trunc(O.GetValue<Double>('MarginBottom', 40));
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
    Result := JSONToObjectEx(J, 2);
  finally
    J.Free;
  end;
end;

class function TReportSerializer.CloneReport(R: TReportModel): TReportModel;
begin
  // Round-trip through SaveToJSON/LoadFromJSON so FieldNames are preserved
  Result := LoadFromJSON(SaveToJSON(R));
end;

class function TReportSerializer.SerializeObjectListToJSON(const Objects: TArray<TReportObject>): string;
var
  Root: TJSONObject;
  Arr: TJSONArray;
  Obj: TReportObject;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('Format', 'VittixClipboard.1.0');
    Arr := TJSONArray.Create;
    for Obj in Objects do
      Arr.AddElement(ObjectToJSON(Obj));
    Root.AddPair('Objects', Arr);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

class function TReportSerializer.DeserializeObjectListFromJSON(const S: string): TArray<TReportObject>;
var
  Root: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Obj: TReportObject;
  ParsedJSON: TJSONValue;
begin
  SetLength(Result, 0);
  if Trim(S) = '' then Exit;
  
  try
    ParsedJSON := TJSONObject.ParseJSONValue(S);
    if not Assigned(ParsedJSON) or not (ParsedJSON is TJSONObject) then
    begin
      ParsedJSON.Free;
      Exit;
    end;
    
    Root := TJSONObject(ParsedJSON);
    try
      if Root.GetValue<string>('Format', '') <> 'VittixClipboard.1.0' then Exit;
      
      Arr := Root.GetValue<TJSONArray>('Objects');
      if Assigned(Arr) then
      begin
        for I := 0 to Arr.Count - 1 do
        begin
          if Arr.Items[I] is TJSONObject then
          begin
            Obj := JSONToObjectEx(TJSONObject(Arr.Items[I]), 2);
            if Assigned(Obj) then
            begin
              SetLength(Result, Length(Result) + 1);
              Result[Length(Result) - 1] := Obj;
            end;
          end;
        end;
      end;
    finally
      Root.Free;
    end;
  except
    // ignore parse errors for clipboard
  end;
end;

// ---------------------------------------------------------------------------
// Save  (FieldNames array written here)
// ---------------------------------------------------------------------------

class function TReportSerializer.SaveToJSON(R: TReportModel): string;
var
  Root:   TJSONObject;
  Arr:    TJSONArray;
  FldArr: TJSONArray;
  Obj:    TReportObject;
  I:      Integer;
begin
  if not Assigned(R) then
    raise Exception.Create('Report model must be assigned.');

  Root := TJSONObject.Create;
  try
    Root.AddPair('Version',      TJSONNumber.Create(2));
    Root.AddPair('Title',        R.Title);
    Root.AddPair('Author',       R.Author);
    Root.AddPair('Description',  R.Description);
    Root.AddPair('PageSettings', PageSettingsToJSON(R.PageSettings));

    // Persist field names so the standalone designer shows them without a DB
    FldArr := TJSONArray.Create;
    for I := 0 to R.FieldNames.Count - 1 do
      FldArr.Add(R.FieldNames[I]);
    Root.AddPair('FieldNames', FldArr);

    FldArr := TJSONArray.Create;
    for I := 0 to R.DataSetNames.Count - 1 do
      FldArr.Add(R.DataSetNames[I]);
    Root.AddPair('DataSetNames', FldArr);

    Arr := TJSONArray.Create;
    for Obj in R.Objects do
      Arr.AddElement(ObjectToJSON(Obj));
    Root.AddPair('Objects', Arr);

    Result := Root.Format(2);
  finally
    Root.Free;
  end;
end;

class procedure TReportSerializer.SaveToFile(R: TReportModel; const FN: string);
begin
  TFile.WriteAllText(FN, SaveToJSON(R), TEncoding.UTF8);
end;

function TryResolveObjectClass(O: TJSONObject; out AClass: TReportObjectClass;
  out ADiscriminatorValue: string): Boolean;
begin
  if O.GetValue('Class') <> nil then
    ADiscriminatorValue := O.GetValue('Class').Value
  else if O.GetValue('Type') <> nil then
    ADiscriminatorValue := O.GetValue('Type').Value
  else
    ADiscriminatorValue := '';

  if ADiscriminatorValue <> '' then
    AClass := FindObjectClass(ADiscriminatorValue)
  else
    AClass := nil;
  Result := Assigned(AClass);
end;

// Optional root-level string arrays (FieldNames / DataSetNames).
// Missing key -> nothing added (model defaults preserved).  Present but
// non-array -> precise structured error instead of an invalid-typecast
// exception.
procedure ReadOptionalStringArray(Root: TJSONObject; const AName: string;
  AList: TStringList; const AErrorCode: string; AResult: TReportLoadResult);
var
  V: TJSONValue;
  Arr: TJSONArray;
  i: Integer;
begin
  V := Root.GetValue(AName);
  if not Assigned(V) then Exit;
  if not (V is TJSONArray) then
  begin
    AResult.AddError(
      Format('''%s'' must be an array (found %s)', [AName, V.ClassName]),
      '', '', AErrorCode);
    Exit;
  end;
  Arr := TJSONArray(V);
  for i := 0 to Arr.Count - 1 do
    AList.Add(Arr.Items[i].Value);
end;


{ ================= Legacy Loading Wrappers ================= }

class function TReportSerializer.LoadFromJSONTolerant(const S: string;
  out AWarnings: TArray<string>): TReportModel;
var
  LoadResult: TReportLoadResult;
begin
  AWarnings := [];
  // Tolerant legacy wrapper: unknown classes are preserved with warnings.
  LoadResult := LoadFromJSONEx(S, False);
  try
    if LoadResult.Success then
    begin
      Result := LoadResult.ExtractModel;
      AWarnings := LoadResult.Warnings;
    end
    else
      raise Exception.Create(LoadResult.Errors[0]);
  finally
    LoadResult.Free;
  end;
end;

class function TReportSerializer.LoadFromFile(const FN: string): TReportModel;
var
  LoadResult: TReportLoadResult;
begin
  LoadResult := LoadFromFileEx(FN);
  try
    if LoadResult.Success then
      Result := LoadResult.ExtractModel
    else
      raise Exception.Create(LoadResult.Errors[0]);
  finally
    LoadResult.Free;
  end;
end;

class function TReportSerializer.LoadFromJSON(const S: string): TReportModel;
var
  LoadResult: TReportLoadResult;
begin
  LoadResult := LoadFromJSONEx(S);
  try
    if LoadResult.Success then
      Result := LoadResult.ExtractModel
    else
      raise Exception.Create(LoadResult.Errors[0]);
  finally
    LoadResult.Free;
  end;
end;

{ ================= Transactional Loading (Phase 4I-18) ================= }

class procedure TReportSerializer.LoadObjectsEx(Arr: TJSONArray; AVersion: Integer;
  APreserveUnknown: Boolean; AResult: TReportLoadResult; const APathPrefix: string;
  AOwner: TObjectList<TReportObject>);
var
  i: Integer;
  Obj: TReportObject;
  DiscriminatorValue: string;
  Cls: TReportObjectClass;
  UnknownObj: TReportUnknownObject;
  ObjJSON: TJSONObject;
  OwnerList: TObjectList<TReportObject>;
  ChildrenPair: TJSONPair;
  ChildrenValue: TJSONValue;
begin
  if not Assigned(Arr) then Exit;
  if Assigned(AOwner) then
    OwnerList := AOwner
  else
    OwnerList := AResult.Model.Objects;

  for i := 0 to Arr.Count - 1 do
  begin
    // A malformed entry must produce a precise diagnostic, not a raw cast
    // exception that escapes the loader.
    if not (Arr.Items[i] is TJSONObject) then
    begin
      AResult.AddError(
        Format('Object entry must be a JSON object (found %s)',
          [Arr.Items[i].ClassName]),
        Format('%s[%d]', [APathPrefix, i]), '', 'INVALID_OBJECT_ENTRY');
      Continue;
    end;

    Obj := nil;
    ChildrenPair := nil;
    try
      ObjJSON := TJSONObject(Arr.Items[i]);

      if not TryResolveObjectClass(ObjJSON, Cls, DiscriminatorValue) then
      begin
        if APreserveUnknown then
        begin
          // Preserve unknown class as raw JSON for forward compatibility
          UnknownObj := TReportUnknownObject.Create;
          UnknownObj.OriginalClassName := DiscriminatorValue;
          UnknownObj.RawJSON := ObjJSON.ToJSON;
          UnknownObj.Name := ObjJSON.GetValue<string>('Name', '');
          Obj := UnknownObj;
          AResult.AddWarning(
            Format('Unknown report object class preserved: "%s"', [DiscriminatorValue]),
            Format('%s[%d]', [APathPrefix, i]),
            DiscriminatorValue,
            'UNKNOWN_CLASS_PRESERVED');
        end
        else
        begin
          AResult.AddError(
            Format('Unknown report object class: "%s"', [DiscriminatorValue]),
            Format('%s[%d]', [APathPrefix, i]),
            DiscriminatorValue,
            'UNKNOWN_CLASS');
          Continue;
        end;
      end
      else
      begin
        // Band children are loaded by this loop through the policy-aware path
        // below.  TReportBandSerializer.LoadProperties also loads Children for
        // the legacy clone/clipboard helpers (JSONToObjectEx), so detach the
        // array here to keep exactly one ownership path: the band's own
        // Children list.  The pair is owned by this iteration and freed in
        // the finally block once the recursion is done.
        if Cls.InheritsFrom(TReportBand) then
          ChildrenPair := ObjJSON.RemovePair('Children');

        Obj := Cls.Create;
        try
          GetSerializer(Cls).LoadProperties(Obj, ObjJSON, AVersion);
        except
          Obj.Free;
          Obj := nil;
          AResult.AddError(
            Format('Failed to deserialize object: %s', [Cls.ClassName]),
            Format('%s[%d]', [APathPrefix, i]),
            Cls.ClassName,
            'DESERIALIZE_FAILED');
          Continue;
        end;
      end;

      // Load band children through the same policy-aware mechanism used for
      // top-level objects, directly into the band's Children list.
      if Assigned(ChildrenPair) then
      begin
        ChildrenValue := ChildrenPair.JsonValue;
        if ChildrenValue is TJSONArray then
          LoadObjectsEx(
            TJSONArray(ChildrenValue), AVersion, APreserveUnknown, AResult,
            Format('%s[%d].Children', [APathPrefix, i]),
            TReportBand(Obj).Children)
        else
          AResult.AddError(
            Format('''Children'' must be an array (found %s)',
              [ChildrenValue.ClassName]),
            Format('%s[%d]', [APathPrefix, i]),
            Cls.ClassName,
            'INVALID_CHILDREN');
      end;

      OwnerList.Add(Obj);
    finally
      // The detached Children array belongs to this iteration; the recursion
      // above has finished and objects hold only string copies of raw JSON.
      ChildrenPair.Free;
    end;
  end;
end;

class function TReportSerializer.LoadFromJSONEx(const S: string;
  const AStrict: Boolean): TReportLoadResult;
var
  JsonText: string;
  Root: TJSONObject;
  Parsed: TJSONValue;
  PSValue: TJSONValue;
  ObjValue: TJSONValue;
  Version: Integer;
begin
  Result := TReportLoadResult.Create;
  Root := nil;
  try
    try
      JsonText := S;
      // Strip any leading BOM
      if (JsonText <> '') and (JsonText[1] = #$FEFF) then
        Delete(JsonText, 1, 1);
      JsonText := TrimLeft(JsonText);
      if (JsonText <> '') and (JsonText[1] = #$FEFF) then
        Delete(JsonText, 1, 1);

      // ParseJSONValue returns nil for malformed text and any TJSONValue
      // subclass for well-formed text.  Check the concrete type before the
      // cast so a wrong root element (array / scalar) yields a precise
      // diagnostic instead of an invalid-typecast exception, and so the
      // parsed value is never leaked.
      Parsed := TJSONObject.ParseJSONValue(JsonText);
      if not Assigned(Parsed) then
      begin
        Result.AddError('Invalid JSON format in report', '', '', 'INVALID_JSON');
        Exit;
      end;
      if not (Parsed is TJSONObject) then
      begin
        Result.AddError(
          Format('Report JSON must be an object (found %s)', [Parsed.ClassName]),
          '', '', 'INVALID_ROOT');
        Parsed.Free;
        Exit;
      end;
      Root := TJSONObject(Parsed);

      Version := 1;
      if Assigned(Root.GetValue('Version')) then
        Version := Trunc(Root.GetValue<Double>('Version'));

      Result.Model := TReportModel.Create;
      Result.Model.Title := Root.GetValue<string>('Title', '');
      Result.Model.Author := Root.GetValue<string>('Author', '');
      Result.Model.Description := Root.GetValue<string>('Description', '');

      // PageSettings is optional: absent keeps the TReportModel constructor
      // defaults.  A present but non-object value is a structural error.
      PSValue := Root.GetValue('PageSettings');
      if Assigned(PSValue) then
      begin
        if PSValue is TJSONObject then
          JSONToPageSettings(TJSONObject(PSValue), Result.Model.PageSettings)
        else
          Result.AddError(
            Format('''PageSettings'' must be a JSON object (found %s)',
              [PSValue.ClassName]), '', '', 'INVALID_PAGESETTINGS');
      end;

      // Optional string arrays — absent in old files is fine.
      ReadOptionalStringArray(Root, 'FieldNames',
        Result.Model.FieldNames, 'INVALID_FIELDNAMES', Result);
      ReadOptionalStringArray(Root, 'DataSetNames',
        Result.Model.DataSetNames, 'INVALID_DATASETNAMES', Result);

      // Objects is optional; when present it must be an array.
      ObjValue := Root.GetValue('Objects');
      if Assigned(ObjValue) then
      begin
        if ObjValue is TJSONArray then
          LoadObjectsEx(TJSONArray(ObjValue), Version, not AStrict, Result, 'Objects', nil)
        else
          Result.AddError(
            Format('''Objects'' must be an array (found %s)', [ObjValue.ClassName]),
            '', '', 'INVALID_OBJECTS');
      end;

      // Success if no errors
      if not Result.HasErrors then
        Result.Success := True;

      // Report version info
      if Version < 2 then
        Result.AddInfo(
          Format('Loaded report with legacy version: %d', [Version]),
          '', '', 'LEGACY_VERSION');
    except
      on E: Exception do
      begin
        Result.AddError(
          Format('Failed to parse report JSON: %s', [E.Message]),
          '', '', 'PARSE_ERROR');
      end;
    end;
  finally
    // The parsed tree is transient; the model and unknown-object raw JSON
    // hold only string copies, so the tree can always be released here.
    Root.Free;
  end;
end;

class function TReportSerializer.LoadFromFileEx(const FN: string): TReportLoadResult;
var
  LoadResult: TReportLoadResult;
begin
  Result := TReportLoadResult.Create;
  try
    if not TFile.Exists(FN) then
    begin
      Result.AddError(
        Format('Report file not found: "%s"', [FN]),
        '', '', 'FILE_NOT_FOUND');
      Exit;
    end;

    LoadResult := LoadFromJSONEx(TFile.ReadAllText(FN, TEncoding.UTF8));
    try
      // Transfer ownership of the model and diagnostics
      Result.Success := LoadResult.Success;
      Result.Model := LoadResult.ExtractModel;
      // Copy diagnostics
      while LoadResult.Diagnostics.Count > 0 do
      begin
        var Diag := LoadResult.Diagnostics.Extract(LoadResult.Diagnostics[0]);
        Result.Diagnostics.Add(Diag);
      end;
    finally
      LoadResult.Free;
    end;
  except
    on E: Exception do
    begin
      Result.AddError(
        Format('Failed to read report file: %s', [E.Message]),
        '', '', 'FILE_READ_ERROR');
    end;
  end;
end;

{ TReportUnknownObjectSerializer }

class procedure TReportUnknownObjectSerializer.SaveProperties(Obj: TReportObject; JSON: TJSONObject);
var
  UnknownObj: TReportUnknownObject;
  ParsedValue: TJSONValue;
  ObjJSON: TJSONObject;
  Pair: TJSONPair;
  i: Integer;
begin
  UnknownObj := TReportUnknownObject(Obj);
  JSON.AddPair('Class', UnknownObj.OriginalClassName);
  JSON.AddPair('Name', UnknownObj.Name);

  // Preserve raw JSON by merging all original properties
  ParsedValue := TJSONObject.ParseJSONValue(UnknownObj.RawJSON);
  if Assigned(ParsedValue) then
  begin
    try
      if ParsedValue is TJSONObject then
      begin
        ObjJSON := TJSONObject(ParsedValue);
        for i := 0 to ObjJSON.Count - 1 do
        begin
          Pair := ObjJSON.Pairs[i];
          // Don't duplicate Class and Name (we already wrote them)
          if not SameText(Pair.JsonString.Value, 'Class') and
             not SameText(Pair.JsonString.Value, 'Name') then
            JSON.AddPair(Pair.JsonString.Value, Pair.JsonValue.Clone as TJSONValue);
        end;
      end;
    finally
      ParsedValue.Free;
    end;
  end;
end;

class procedure TReportUnknownObjectSerializer.LoadProperties(Obj: TReportObject;
  JSON: TJSONObject; AVersion: Integer);
var
  UnknownObj: TReportUnknownObject;
begin
  UnknownObj := TReportUnknownObject(Obj);
  UnknownObj.OriginalClassName := JSON.GetValue<string>('Class', '');
  UnknownObj.Name := JSON.GetValue<string>('Name', '');
  UnknownObj.RawJSON := JSON.ToJSON;
end;

initialization
  // The embedded-image load path resolves PictureClass through the Classes
  // streaming registry (GetClass).  Runtime VCL does not register graphic
  // classes there (that is IDE/designer-package behavior), so without this
  // registration every embedded picture is silently dropped on load.
  // Register exactly the graphic classes TPicture supports for the formats
  // this project serializes; unknown stored classes keep the existing
  // forward-compatible skip behavior in LoadProperties.
  RegisterClasses([Vcl.Graphics.TBitmap, TIcon, TMetafile,
    TPngImage, TJPEGImage, TGIFImage]);
finalization
  if Assigned(GSerializers) then
    GSerializers.Free;
end.
