unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, mysql56conn, mysql57conn, SQLDB, Forms, Controls, Graphics,
  Dialogs, StdCtrls, ExtCtrls, ExtDlgs;

type

  { TFormMain }

  TFormMain = class(TForm)
    ButtonLoad: TButton;
    ButtonRun: TButton;
    GroupBox1: TGroupBox;
    ImageInput: TImage;
    LabelOutput: TLabel;
    mysql: TMySQL57Connection;
    OpenPictureDialog1: TOpenPictureDialog;
    q1: TSQLQuery;
    RadioWhite: TRadioButton;
    RadioBlack: TRadioButton;
    SQLTransaction1: TSQLTransaction;

    procedure ButtonRunClick(Sender: TObject);
    procedure ButtonLoadClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);

    procedure Preprocessing();
    procedure Segmentasi();
    procedure SegmentasiHuruf();
    procedure FetchFeatures();
    procedure CompareFeature();
  private

  public

  end;

var
  FormMain: TFormMain;

implementation

{$R *.lfm}

{ TFormMain }

uses
  windows, math;

type
  Obj = Record
    Xpos, Ypos : Integer;
    Width, Height : Integer;
    Feature : Array[0..24] of Double;
    ObjLabel : String;
    FeatureSum : Double;
  end;

var
  BmpGray, BmpBiner : Array[0..1000, 0..1000] of integer;
  Objects : Array[0..7] of Obj;
  ObjCount : Integer = 0;
  MainObject : Obj;
  MatrixCount : Integer = 5;
  FetchedFeatureCount : Integer;
  FetchedFeatures : Array[0..1000, 0..1000] of Double;
  FetchedLabels : Array[0..1000] of String;
  kVal : Integer = 5;
  ObjFeatures : Array[0..1000, 0..1000] of Double;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  LabelOutput.Visible := False;
end;

procedure TFormMain.ButtonLoadClick(Sender: TObject);
var
  i, j, R, G, B : Integer;
begin      
  ObjCount := 0;
  if (OpenPictureDialog1.Execute) then
  begin
    ImageInput.Picture.LoadFromFile(OpenPictureDialog1.FileName);
  end;
             
  LabelOutput.Caption := '';

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

procedure TFormMain.ButtonRunClick(Sender: TObject);
begin
  Preprocessing();
  Segmentasi();
  SegmentasiHuruf();
  FetchFeatures();
  CompareFeature();
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

//      smoothing untuk mereduksi noise
      k:=0;

      for ki:=0 to 2 do
      begin
        for kj:=0 to 2 do
        begin
          k := round(k + BmpGray[i+ki-1,j+kj-1] * SmoothingFilter[ki,kj]);
        end;
      end;

      BmpTemp[i,j] := k;

//       binerisasi
      if RadioWhite.Checked = True then
      begin
        if BmpTemp[i,j] > 127
        then
          BmpBiner[i,j] := 1
        else
          BmpBiner[i,j] := 0;
      end else
      begin
//        jika background input = hitam maka object dan background di-inverse
        if BmpTemp[i,j] > 127
        then
          BmpBiner[i,j] := 0
        else
          BmpBiner[i,j] := 1;
      end;

      ImageInput.Canvas.Pixels[i,j] := RGB(BmpBiner[i,j]*255, BmpBiner[i,j]*255, BmpBiner[i,j]*255);
    end;
  end;
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
  MatrixRow, MatrixCol, MatrixWidth, MatrixHeight : Integer;
  BinaryCount : Integer;
  FeatureIndex : Integer;
label
  LabelBawah, LabelEnd;
begin
  for i := MainObject.Xpos - 1 to MainObject.Xpos + MainObject.Width + 1 do
  begin
    BlackCount[i] := 0;

    for j := MainObject.Ypos to MainObject.Ypos + MainObject.Height do
    begin
      if (BmpBiner[i,j] = 0) then Inc(BlackCount[i]);

//     deteksi awal object
      if (j = MainObject.Ypos + MainObject.Height) and (BlackCount[i] <> 0) and (BlackCount[i-1] = 0) then
      begin
        Inc(ObjCount);
        Objects[ObjCount-1].Xpos := i;
        Objects[ObjCount-1].Ypos := MainObject.Ypos;
      end;

//     deteksi akhir object
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
    end;
  end;

  for i := 0 to ObjCount-1 do
  begin                                           
//  highlight object dengan persegi berwarna merah
    ImageInput.Canvas.Pen.Color := ClRed;

    ImageInput.Canvas.MoveTo(Objects[i].Xpos, Objects[i].Ypos);
    ImageInput.Canvas.LineTo(Objects[i].Xpos + Objects[i].Width, Objects[i].Ypos);
    ImageInput.Canvas.LineTo(Objects[i].Xpos + Objects[i].Width, Objects[i].Ypos + Objects[i].Height);
    ImageInput.Canvas.LineTo(Objects[i].Xpos, Objects[i].Ypos + Objects[i].Height);
    ImageInput.Canvas.LineTo(Objects[i].Xpos, Objects[i].Ypos);

    Objects[i].FeatureSum := 0;

    MatrixWidth := Ceil(Objects[i].Width / MatrixCount);
    MatrixHeight := Ceil(Objects[i].Height / MatrixCount);

//    menghitung fitur
    for obji := 0 to MatrixCount-1 do
    begin
      for objj := 0 to MatrixCount-1 do
      begin      
        BinaryCount := 0;

        for MatrixRow := 0 to MatrixWidth-1 do
        begin
          for MatrixCol := 0 to MatrixHeight-1 do
          begin
            if BmpBiner[Objects[i].Xpos + (obji*MatrixWidth) + MatrixRow, Objects[i].Ypos + (objj*MatrixHeight) + MatrixCol] = 0 then
              Inc(BinaryCount);
          end;
        end;

        FeatureIndex := obji*MatrixCount + objj;

        Objects[i].Feature[FeatureIndex] := BinaryCount / (MatrixWidth * MatrixHeight);
        Objects[i].FeatureSum += Objects[i].Feature[FeatureIndex];

        ObjFeatures[i, FeatureIndex] := Objects[i].Feature[FeatureIndex];
      end;
    end;
  end;
end;

procedure TFormMain.FetchFeatures();
var
  i, j : Integer;
  Count : Integer = 0;
begin          
  q1.Close;

  try        
    mysql.Connected := True;
    mysql.Open;
  except
    on E: ESQLDatabaseError do
      Application.MessageBox(PChar('Database not connected, error : ' + E.ToString()), 'Database error', MB_ICONINFORMATION)
  end;

  q1.Sql.Text := 'select * from letter';
  q1.Open;

  while not q1.EOF do
  begin
    FetchedLabels[Count] := q1.Fields[0].AsString;

    for i := 0 to MatrixCount * MatrixCount -1 do
    begin
//      fields[ i + 1 ] : karena index pertama adalah label
      FetchedFeatures[Count, i] := q1.Fields[i+1].AsFloat;
    end;

    Inc(Count);
    q1.Next;
  end;

  FetchedFeatureCount := Count;
  q1.Close;
end;

procedure TFormMain.CompareFeature();
var
  i, j, k : Integer;
  Res, MinRes : Array[0..1000] of Double;
  MinResIndex : Integer;
  Undetected : String = 'not-found';
  UndetectedCount : Integer = 0;
  Result : String = '';
begin
  for i := 0 to ObjCount-1 do
  begin
    for j := 0 to FetchedFeatureCount-1 do
    begin                  
      Res[j] := 0;

      for k := 0 to MatrixCount * MatrixCount - 1 do
      begin
        Res[j] += Abs(Objects[i].Feature[k] - FetchedFeatures[j,k]);
      end;
    end;
    
    MinRes[i] := 100;

    for j := 0 to FetchedFeatureCount-1 do
    begin
      if Res[j] < MinRes[i] then
      begin
        MinRes[i] := Res[j];
        MinResIndex := j;
      end;
    end;
                            
    if MinRes[i] > kVal then
    begin
      Objects[i].ObjLabel := Undetected;
      Inc(UndetectedCount);
    end
    else
    begin
      Objects[i].ObjLabel := FetchedLabels[MinResIndex]; 
      Result += Objects[i].ObjLabel;
    end;
  end;

  LabelOutput.Visible := True;

  if UndetectedCount > 0 then
  begin
    Result += (LineEnding + 'Not detected : ' + IntToStr(UndetectedCount));
  end;
                                
  LabelOutput.Caption := Result;
end;

end.

