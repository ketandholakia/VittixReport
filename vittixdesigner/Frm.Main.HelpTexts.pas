unit Frm.Main.HelpTexts;

interface

function KeyboardShortcutsText: string;
function ExpressionHelpText: string;

implementation

uses
  System.SysUtils;

function KeyboardShortcutsText: string;
begin
  Result :=
    'File:' + sLineBreak +
    '- Ctrl+N = New Report' + sLineBreak +
    '- Ctrl+O = Open Report' + sLineBreak +
    '- Ctrl+S = Save Report' + sLineBreak + sLineBreak +
    'Canvas:' + sLineBreak +
    '- Delete = Delete selected object' + sLineBreak +
    '- Arrow Keys = Nudge selected object' + sLineBreak +
    '- Ctrl + Arrow = Move selected object by 1' + sLineBreak +
    '- Shift + Arrow = Resize selected object by 1' + sLineBreak +
    '- Ctrl + Shift + Arrow = Move selected object by grid size' + sLineBreak + sLineBreak +
    'Property Panel:' + sLineBreak +
    '- Ctrl+C = Copy selected text' + sLineBreak +
    '- Ctrl+X = Cut selected text' + sLineBreak +
    '- Ctrl+V = Paste text' + sLineBreak +
    '- Delete = Delete selected text/value' + sLineBreak +
    '- Arrow Keys = Edit/navigate property value' + sLineBreak + sLineBreak +
    'Notes:' + sLineBreak +
    '- Keyboard move/resize works when canvas has focus.' + sLineBreak +
    '- Property panel shortcuts work when editing a property value.';
end;

function ExpressionHelpText: string;
begin
  Result :=
    'Expression Help' + sLineBreak + sLineBreak +
    'Field token syntax:' + sLineBreak +
    '[FieldName]' + sLineBreak + sLineBreak +
    'Common examples:' + sLineBreak +
    '[Qty] * [Rate]' + sLineBreak +
    '[Amount] > 1000' + sLineBreak +
    '[GroupName] = ''Labels''' + sLineBreak +
    '[Qty] > 5' + sLineBreak +
    '[CustomerName] <> ' + QuotedStr('') + sLineBreak +
    '[RecNo]' + sLineBreak + sLineBreak +
    'Use expressions in:' + sLineBreak +
    'Expression' + sLineBreak +
    'PrintWhen' + sLineBreak +
    'BackgroundCondition' + sLineBreak +
    'FontColorCondition' + sLineBreak +
    'BorderColorCondition' + sLineBreak + sLineBreak +
    'Tips:' + sLineBreak +
    'Use the Expression Helper ellipsis button in the property panel.' + sLineBreak +
    'Use Preview to verify the result.' + sLineBreak +
    'Open Report -> Demo Reports -> Expression Usage Demo for live examples.';
end;

end.
