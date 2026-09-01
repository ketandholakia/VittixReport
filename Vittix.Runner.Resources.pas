unit Vittix.Runner.Resources;

{
  Phase 3F-4: process resource measurement mechanics for the runner.

  Owns ONLY obtaining the raw process resource counters:

    - GDI handle count  (GetGuiResources, GR_GDIOBJECTS)
    - USER object count (GetGuiResources, GR_USEROBJECTS)
    - process memory    (AllocMemSize, exact legacy value semantics)

  Purity rules:
    - No thresholds, no leak classification, no delta calculation.
    - No timing decisions: callers own when snapshots are captured.
    - No console I/O, no Halt, no configuration, no global mutable state.

  Measurement mechanisms are preserved exactly from
  Vittix.Runner.Console.pas (same APIs, same flags, same types):
    GDI/USER : GetGuiResources(GetCurrentProcess, ...) -> DWORD/Cardinal
    Memory   : AllocMemSize -> Int64 (deprecated symbol, warning suppressed)
}

interface

uses
  Winapi.Windows;

type
  {
    Raw process resource counters captured at one instant. Field types
    match the legacy Console variables and TProcessResourceSummary exactly
    (DWORD/Cardinal for GDI and USER, Int64 for memory).
  }
  TProcessResourceSnapshot = record
    GDI: Cardinal;
    User: Cardinal;
    MemoryBytes: Int64;
  end;

{
  Captures the current GDI handle count only. Used at the per-report
  measurement points, which historically read GDI handles alone (no USER
  or memory read is introduced at those points).
}
function CaptureGdiHandleCount: DWORD;

{
  Captures the full process resource snapshot (GDI, USER, memory) in the
  legacy order: GDI handles, then USER objects, then AllocMemSize.
}
function CaptureProcessResourceSnapshot: TProcessResourceSnapshot;

implementation

uses
  System.SysUtils;

function CaptureGdiHandleCount: DWORD;
begin
  Result := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);
end;

function CaptureProcessResourceSnapshot: TProcessResourceSnapshot;
begin
  Result.GDI := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);
  Result.User := GetGuiResources(GetCurrentProcess, GR_USEROBJECTS);
  {$WARN SYMBOL_DEPRECATED OFF}
  Result.MemoryBytes := AllocMemSize;
  {$WARN SYMBOL_DEPRECATED ON}
end;

end.