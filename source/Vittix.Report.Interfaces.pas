unit Vittix.Report.Interfaces;

{
  Vittix.Report.Interfaces
  ========================
  Core interface contracts for the VittixReport framework.

  Dependency Direction (must stay clean — no circular refs):
    Interfaces  ◄─  All other units
    (this unit imports nothing from the framework)

  Interfaces Defined
  ------------------
  IReportExporter     Export rendered metafile pages to a target (PDF, HTML …)
  IReportPlugin       Allow third-party object types to self-register
  IReportProgress     Callback contract for long-running engine operations
}

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics;

// ---------------------------------------------------------------------------
// IReportExporter
//   Implement this interface to create a new output format (PDF, XLSX, HTML…)
//   Call: ExportPages(Engine.Pages, 'output.pdf')
// ---------------------------------------------------------------------------
type
  IReportExporter = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']

    /// <summary>Export a list of rendered metafile pages to a file.</summary>
    procedure ExportPages(
      const Pages: TObjectList<TMetafile>;
      const FileName: string);

    /// <summary>Human-readable format name shown in UI menus.</summary>
    function FormatName: string;

    /// <summary>Default file extension (without dot), e.g. 'pdf'.</summary>
    function DefaultExtension: string;
  end;

// ---------------------------------------------------------------------------
// IReportPlugin
//   Implement to register a custom TReportObject subclass with the framework
//   and expose design-time metadata (display name, toolbox icon).
// ---------------------------------------------------------------------------
type
  IReportPlugin = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']

    /// <summary>Register the custom class with the global object registry.</summary>
    procedure RegisterObjects;

    /// <summary>Unregister when the plugin is unloaded (design-time only).</summary>
    procedure UnregisterObjects;

    /// <summary>Short display name listed in the toolbox.</summary>
    function PluginName: string;
  end;

// ---------------------------------------------------------------------------
// IReportProgress
//   Passed to TReportEngine.Prepare so callers can show progress UI and
//   support cancellation without coupling the engine to a form.
// ---------------------------------------------------------------------------
type
  IReportProgress = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']

    /// <summary>
    ///   Called once the total number of rows is known.
    ///   May be 0 if the dataset does not support RecordCount.
    /// </summary>
    procedure SetTotal(const Total: Integer);

    /// <summary>Called after each master-data row is processed.</summary>
    procedure Advance(const Current: Integer);

    /// <summary>
    ///   Return True to request that the engine stop building pages.
    ///   The engine will finish the current page cleanly before stopping.
    /// </summary>
    function IsCancelled: Boolean;
  end;

implementation

end.
