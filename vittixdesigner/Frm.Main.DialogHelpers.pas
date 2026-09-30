unit Frm.Main.DialogHelpers;

interface

uses
  System.SysUtils,
  Vcl.Dialogs;

type
  { Runs the requested save and reports whether the document was actually
    written.  False = cancelled dialog or failed write (DP-24). }
  TSaveConfirmationFunc = reference to function: Boolean;

{ Prompts to save when there are unsaved changes.  Returns True when the
  caller may proceed (no changes, chose "No", or the save completed); False
  when the user cancelled or the save did not complete.

  DP-24 / M-19: this used to raise Abort on cancel, which escaped through
  the call stack as a silent EAbort and could not stop a form close; the
  result is now explicit and every caller acts on it. }
function ConfirmSaveIfModified(
  AModified, AReportMetadataDirty: Boolean;
  const AOnSave: TSaveConfirmationFunc): Boolean;

implementation

function ConfirmSaveIfModified(
  AModified, AReportMetadataDirty: Boolean;
  const AOnSave: TSaveConfirmationFunc): Boolean;
begin
  Result := True;
  if not (AModified or AReportMetadataDirty) then
    Exit;
  case Integer(MessageDlg('The report has unsaved changes. Save now?',
                          mtConfirmation, [mbYes, mbNo, mbCancel], 0)) of
    6:  // mrYes
      if Assigned(AOnSave) then
        Result := AOnSave();
    2:  // mrCancel
      Result := False;
  end;
end;

end.
