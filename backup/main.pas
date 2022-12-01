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
    Label1: TLabel;
    Label2: TLabel;
    LabelOutput: TLabel;
    OpenPictureDialog1: TOpenPictureDialog;
    RadioBlack: TRadioButton;
    RadioWhite: TRadioButton;
    procedure ButtonExtractClick(Sender: TObject);
    procedure ButtonLoadClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);

    procedure Preprocessing();
    procedure Segmentasi();
    procedure SegmentasiHuruf();
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


type
  Obj = Record
    Xpos, Ypos : Integer;
    Width, Height : Integer;
    Population : Array[0..3,0..3] of Single;
    PopSum : Single;
  end;

var
  BmpGray, BmpBiner : Array[0..1000, 0..1000] of integer;
  Objects : Array[0..7] of Obj;
  ObjCount : Integer = 0;
  MainFeature : Single;
  MainObject : Obj;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  LabelOutput.Visible := False;
  ObjCount := 0;
end;

procedure TFormMain.ButtonLoadClick(Sender: TObject);
var
  i, j, R, G, B : Integer;
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
    end;
  end;


  for i:=0 to ImageInput.Width-1 do
  begin
    for j:=0 to ImageInput.Height-1 do
    begin
      if (i = 0) or (j = 0) or (i = ImageInput.width-1) or (j = ImageInput.height-1) then
      begin
        if i = 0 then
        begin
          BmpGray[i-1,j] := BmpGray[i,j];
        end;
        if j = 0 then
        begin
          BmpGray[i,j-1] := BmpGray[i,j];
        end;
        if i = ImageInput.width-1 then
        begin
          BmpGray[i+1,j] := BmpGray[i,j];
        end;
        if j = ImageInput.height-1 then
        begin
          BmpGray[i,j+1] := BmpGray[i,j];
        end;
      end;
    end;
    end;

end;

procedure TFormMain.ButtonExtractClick(Sender: TObject);
begin
  Preprocessing();
end;

procedure TFormMain.Preprocessing();
var
  i, j, k, ki, kj : Integer;
  BmpTemp : Array[-1..1000,-1..1000] of Integer;
  SmoothingFilter : Array[0..2,0..2] of Single = ((1/9,1/9,1/9),(1/9,1/9,1/9),(1/9,1/9,1/9));
begin
  for i:=0 to ImageInput.Width-1 do
  begin
    for j:=0 to ImageInput.Height-1 do
    begin
      k:=0;

      for ki:=0 to 2 do
      begin
        for kj:=0 to 2 do
        begin
          k := round(k + BmpGray[i+ki-1,j+kj-1] * SmoothingFilter[ki,kj]);
        end;
      end;

      BmpTemp[i,j] := k;

      if BmpTemp[i,j] > 127
      then
        BmpBiner[i,j] := 1
      else
        BmpBiner[i,j] := 0;

      ImageInput.Canvas.Pixels[i,j] := RGB(BmpBiner[i,j]*255, BmpBiner[i,j]*255, BmpBiner[i,j]*255);
    end;
  end;

  Segmentasi();
  SegmentasiHuruf();
end;

procedure TFormMain.Segmentasi();
var
  i, j : Integer;
  TepiAtas, TepiBawah, TepiKiri, TepiKanan, ObjectWidth, ObjectHeight : Integer;

label
  LabelAtas, LabelKanan, LabelBawah, LabelDraw;
begin
    for i:=0 to ImageInput.Width-1 do
    begin
      for j:=0 to ImageInput.Height-1 do
      begin
        if (BmpBiner[i,j] = 0) then
        begin
          TepiKiri := i;
          goto LabelAtas;
        end;
      end;
    end;

//    tepi atas
    LabelAtas:
    for i:=0 to ImageInput.height-1 do
    begin
      for j:=0 to ImageInput.width-1 do
      begin
        if (BmpBiner[j,i] = 0) then
        begin
          TepiAtas := i;
          goto LabelKanan;
        end;
      end;
    end;

//    tepi kanan
    LabelKanan:
    i:=ImageInput.width-1;
    while i >= 0 do
    begin
      for j:=0 to ImageInput.Height-1 do
      begin
        if (BmpBiner[i,j] = 0) then
        begin
          TepiKanan := i;
          goto LabelBawah;
        end;
      end;
      i := i-1;
    end;

//    tepi bawah
    LabelBawah:
    i:=ImageInput.height-1;
    while i >= 0 do
    begin
      j:=ImageInput.width-1;
      while j >= 0 do
      begin
        if (BmpBiner[j,i] = 0) then
        begin
          TepiBawah := i;
          goto LabelDraw;
        end;
        j := j-1;
      end;
      i := i-1;
    end;

    LabelDraw:

    ObjectWidth := TepiKanan - TepiKiri;
    ObjectHeight := TepiBawah - TepiAtas;

    MainObject.Xpos := TepiKiri;
    MainObject.Ypos := TepiAtas;
    MainObject.Width := ObjectWidth;
    MainObject.Height := ObjectHeight;
end;

procedure TFormMain.SegmentasiHuruf();
var
  i, j, obji, objj : Integer;
  TepiAtas, TepiBawah : Integer;
  BlackCount : Array[0..1000] of  Integer;

label
  LabelBawah, LabelEnd , LabelBawah2, LabelEnd2;
begin
  for i := MainObject.Xpos to MainObject.Xpos + MainObject.Width do
  begin
    BlackCount[i] := 0;

    for j := MainObject.Ypos to MainObject.Ypos + MainObject.Height do
    begin
      if (BmpBiner[i,j] = 0) then Inc(BlackCount[i]);

      //if BmpBiner[i-1,j] = 1 then
      //begin
        //Inc(ObjCount);
        //Objects[ObjCount-1].Xpos := i;
        //Objects[ObjCount-1].Ypos := j;
      //end;

//      awal object
      if (j = MainObject.Ypos + MainObject.Height) and (BlackCount[i] <> 0) and (BlackCount[i-1] = 0) then
      begin
        Inc(ObjCount);
        Objects[ObjCount-1].Xpos := i;
        Objects[ObjCount-1].Ypos := MainObject.Ypos;
      end;

//      akhir object
      if (j = MainObject.Ypos + MainObject.Height) and (BlackCount[i] = 0) and (BlackCount[i-1] <> 0) then
      begin
        Objects[ObjCount-1].Width := i - Objects[ObjCount-1].Xpos;
        Objects[ObjCount-1].Height := MainObject.Height;

        for obji := MainObject.Ypos to MainObject.Ypos + Objects[ObjCount-1].Height do
        begin
          for objj := Objects[ObjCount-1].Xpos to Objects[ObjCount-1].Xpos + Objects[ObjCount-1].Width do
          begin
            if (BmpBiner[objj,obji] = 0) then
            begin
              TepiAtas := obji;
              goto LabelBawah;
            end;
          end;
        end;

        LabelBawah:
        obji := MainObject.Ypos + MainObject.Height;
        while obji >= TepiAtas do
        begin
          objj := Objects[ObjCount-1].Xpos + Objects[ObjCount-1].Width;
          while objj >= Objects[ObjCount-1].Xpos do
          begin
            if (BmpBiner[objj,obji] = 0) then
            begin
              TepiBawah := obji;
              goto LabelEnd;
            end;
            objj := objj-1;
          end;
          obji := obji-1;
        end;  

        LabelEnd:

        Objects[ObjCount-1].Ypos := TepiAtas;
        Objects[ObjCount-1].Height := TepiBawah - TepiAtas;
      end;

//      akhir object pada tepi kanan main object
      if (i = MainObject.Xpos + MainObject.Width) and (j = MainObject.Ypos + MainObject.Height) and (BlackCount[i] <> 0) then
      begin
        Objects[ObjCount-1].Width := i - Objects[ObjCount-1].Xpos;
        Objects[ObjCount-1].Height := MainObject.Height;

        for obji := MainObject.Ypos to MainObject.Ypos + MainObject.Height do
        begin
          for objj := Objects[ObjCount-1].Xpos to Objects[ObjCount-1].Xpos + Objects[ObjCount-1].Width do
          begin
            if (BmpBiner[objj,obji] = 0) then
            begin
              TepiAtas := obji;
              goto LabelBawah2;
            end;
          end;
        end;

        LabelBawah2:
        obji := Objects[ObjCount-1].Height + MainObject.Height;
        while obji >= MainObject.Height do
        begin
          objj := Objects[ObjCount-1].Xpos + Objects[ObjCount-1].Width;
          while objj >= Objects[ObjCount-1].Xpos do
          begin
            if (BmpBiner[objj,obji] = 0) then
            begin
              TepiBawah := obji;
              goto LabelEnd2;
            end;
            objj := objj-1;
          end;
          obji := obji-1;
        end;

        LabelEnd2:

        Objects[ObjCount-1].Ypos := TepiAtas;
        Objects[ObjCount-1].Height := TepiBawah - TepiAtas;
      end;
    end;
  end;

  for i := 0 to ObjCount-1 do
  begin
    ImageInput.Canvas.Pen.Color := ClRed;

    ImageInput.Canvas.MoveTo(Objects[i].Xpos, Objects[i].Ypos);
    ImageInput.Canvas.LineTo(Objects[i].Xpos + Objects[i].Width, Objects[i].Ypos);
    ImageInput.Canvas.LineTo(Objects[i].Xpos + Objects[i].Width, Objects[i].Ypos + Objects[i].Height);
    ImageInput.Canvas.LineTo(Objects[i].Xpos, Objects[i].Ypos + Objects[i].Height);
    ImageInput.Canvas.LineTo(Objects[i].Xpos, Objects[i].Ypos);
  end;
end;

end.

