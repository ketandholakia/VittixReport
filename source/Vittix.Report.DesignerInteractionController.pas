unit Vittix.Report.DesignerInteractionController;

interface

uses
  System.Types,
  System.Generics.Collections,
  Vcl.Controls,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.DesignerInteraction;

type
  TDesignerInteractionState = record
    MouseDown: Boolean;
    MouseStart: TPoint;
    Mode: Integer;
    ResizeHandle: TResizeHandle;
    DragStartBounds: TDictionary<TReportObject, TRect>;
    BandResizeBand: TReportBand;
    BandResizeOrigH: Integer;
    RubberRect: TRect;
    Rubbering: Boolean;
  end;

implementation

end.
