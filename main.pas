unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ExtDlgs;

type

  { TFormMain }

  TFormMain = class(TForm)
    ButtonLoad: TButton;
    ButtonExtract: TButton;
    ImageInput: TImage;
    LabelOutput: TLabel;
    OpenPictureDialog1: TOpenPictureDialog;
    procedure ButtonExtractClick(Sender: TObject);
    procedure ButtonLoadClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  FormMain: TFormMain;

implementation

{$R *.lfm}

{ TFormMain }

uses
  windows;

var
  BmpGray, BmpBinary : array[0..1000, 0..1000] of integer;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  LabelOutput.Visible := False;
end;

procedure TFormMain.ButtonLoadClick(Sender: TObject);
var
  i, j, R, G, B : integer;
begin
  if (OpenPictureDialog1.Execute) then
  begin
    ImageInput.Picture.LoadFromFile(OpenPictureDialog1.FileName);
  end;

  for i:=0 to ImageInput.Width-1 do
  begin
    for j:=0 to ImageInput.Height-1 do
    begin
      R := GetRValue(ImageInput.Canvas.Pixels[i,j]);
      G := GetGValue(ImageInput.Canvas.Pixels[i,j]);
      B := GetBValue(ImageInput.Canvas.Pixels[i,j]);

      BmpGray[i,j] := (R + G + B) div 3;

//      thresholding nilai biner
      if BmpGray[i,j] > 127
      then
        BmpBinary[i,j] := 1
      else
        BmpBinary[i,j] := 0;
    end;
  end;
end;

procedure TFormMain.ButtonExtractClick(Sender: TObject);
begin

end;

end.

