unit Frm.Main.DialogHelpers;

interface

uses
  System.SysUtils,
  Vcl.Dialogs;

type
  TSaveConfirmationProc = reference to procedure;

procedure ConfirmSaveIfModified(
  AModified, AReportMetadataDirty: Boolean;
  const AOnSave: TSaveConfirmationProc);

implementation

procedure ConfirmSaveIfModified(
  AModified, AReportMetadataDirty: Boolean;
  const AOnSave: TSaveConfirmationProc);
begin
  if not (AModified or AReportMetadataDirty) then
    Exit;
  case Integer(MessageDlg('The report has unsaved changes. Save now?',
                          mtConfirmation, [mbYes, mbNo, mbCancel], 0)) of
    6:  // mrYes
      if Assigned(AOnSave) then
        AOnSave();
    2:  // mrCancel
      Abort;
  end;
end;

end.
