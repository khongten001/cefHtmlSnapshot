unit uCEFSnapshotParameters;

interface

uses
   System.Classes, System.SysUtils, Vcl.Graphics,
   uCEFTypes, uCEFMiscFunctions;

const
   cChromiumSubFolder = 'Chromium87';
   cDLLSubfolder = 'Libraries';

type
   TSnapshotOutputFormat = ( sofUnknown, sofBMP, sofJPG, sofPNG, sofPDF );

   TSnapshotParameters = record
      ErrorText : String;        // if not empty, parsing ended up with errors
      URL : ustring;
      Width : Integer;
      Height : Integer;
      Scale : Double;
      DelayMSec : Integer;
      OutputFilePath : String;
      OutputFormat : TSnapshotOutputFormat;
      JPEGQuality : Integer;
      PNGCompressionLevel : Integer;
      PDFOptions : TCefPdfPrintSettings;
      PDFTitle, PDFURL : String;

      procedure SaveBitmap(bmp : TBitmap);
   end;

function ParseCommandLineParameters : TSnapshotParameters;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

uses LibTurboJPEG, Vcl.Imaging.pngimage;

const
   cHelp = 'cefHtmlSnapshot [-arg1 value1] [-arg2 value2] ...'#10#10
         + '  -?, -h, -help    This inline documentation'#10
         + '  -url             URL of the website or file to be snapshotted (required)'#10
         + '  -delay, -d       Delay in milliseconds, between 100 ms and 30 sec (default 1 sec)'#10
         + '  -out             Output file pathname, extension determines format (default snapshot.bmp)'#10
         + '                   Supported formats: JPEG, PNG, BMP and PDF'#10
         + #10
         + '  -width, -w       Width of the snapshot, between 1 and 2048 (default 1024)'#10
         + '  -height, -h      Height of the snapshot, between 1 and 2048 (default 768)'#10
         + '                   When output format is a PDF, this parameter is ignored'#10
         + '  -scale, -s       Scale of the website relative to 96dpi, between 0.1 and 10.0 (default 1.0)'#10
         + '  -quality         Output JPEG quality (1 to 100, default 90)'#10
         + '  -compression     Output PNG compresson level (0 to 9, default 7)'#10
         + #10
         + '  -pdf-xxx         PDF output options outlined below'#10
         + '       page-width      page width in microns (default 210000)'#10
         + '       page-height     page height in microns (default 297000)'#10
         + '       margin-top      top margin in points (default 20)'#10
         + '       margin-left     left margin in points (default 20)'#10
         + '       margin-right    right margin in points (default 20)'#10
         + '       margin-bottom   bottom margin in points (default 20)'#10
         + '       landscape       portait (default, 0) or landscape (1)'#10
         + '       backgrounds     enable backgrounds (1) or not (default, 0)'#10
         ;

// ParseCommandLineParameters
//
function ParseCommandLineParameters : TSnapshotParameters;

   function TryParseIntegerParameter(const name, p : String; var value : Integer; mini, maxi : Integer) : String;
   begin
      value := StrToIntDef(p, mini-1);
      if (value < mini) or (value > maxi) then begin
         Result := 'Invalid ' + name + ' value: "' + p + '"';
      end else Result := '';
   end;

   function TryParseFloatParameter(const name, p : String; var value : Double; mini, maxi : Double) : String;
   begin
      value := StrToFloatDef(p, mini-1);
      if (value < mini) or (value > maxi) then begin
         Result := 'Invalid ' + name + ' value: "' + p + '"';
      end else Result := '';
   end;

begin
   if ParamCount = 0 then begin
      Result.ErrorText := cHelp;
      Exit;
   end;

   Result.OutputFormat := sofBMP; // TODO
   Result.Width  := 1024;
   Result.Height := 768;
   Result.Scale := 1.0;
   Result.DelayMSec := 1000;
   Result.OutputFilePath := 'snapshot.bmp';
   Result.JPEGQuality := 90;
   Result.PNGCompressionLevel := 7;

   Result.PDFOptions.page_width := 210000;
   Result.PDFOptions.page_height := 297000;
   Result.PDFOptions.margin_type := PDF_PRINT_MARGIN_CUSTOM;
   Result.PDFOptions.margin_top := 20;
   Result.PDFOptions.margin_left := 20;
   Result.PDFOptions.margin_right := 20;
   Result.PDFOptions.margin_bottom := 20;
   Result.PDFOptions.landscape := 0;
   Result.PDFOptions.backgrounds_enabled := 0;

   var lastP := '';
   for var i := 1 to ParamCount do begin
      var p := ParamStr(i);
      if p = '' then continue;
      case p[1] of
         '-', '/' : begin
            lastP := LowerCase(Copy(p, 2));
         end;
      else
         if (lastP = '?') or (lastP = 'h') or (lastP = 'help') then begin
            Result.ErrorText := cHelp;
         end else if lastP = 'url' then begin
            Result.URL := p;
            // TODO: basic syntax check
         end else if (lastP = 'width') or (lastP = 'w') then begin
            Result.ErrorText := TryParseIntegerParameter('Width', p, Result.Width, 1, 2048);
         end else if (lastP = 'height') or (lastP = 'h') then begin
            Result.ErrorText := TryParseIntegerParameter('Height', p, Result.Height, 1, 2048);
         end else if (lastP = 'scale') or (lastP = 's') then begin
            Result.ErrorText := TryParseFloatParameter('Scale', p, Result.Scale, 0.1, 10);
         end else if (lastP = 'delay') or (lastP = 'd') then begin
            Result.ErrorText := TryParseIntegerParameter('Delay', p, Result.DelayMSec, 100, 30000);
         end else if lastP = 'out' then begin
            Result.OutputFilePath := p;
         end else if lastP = 'quality' then begin
            Result.ErrorText := TryParseIntegerParameter('Quality', p, Result.JPEGQuality, 1, 100);
         end else if lastP = 'compression' then begin
            Result.ErrorText := TryParseIntegerParameter('Compression', p, Result.PNGCompressionLevel, 0, 9);
         end else if lastP = 'pdf-page-width' then begin
            Result.ErrorText := TryParseIntegerParameter('PDF-page-width', p, Result.PDFOptions.page_width, 10000, 10000000);
         end else if lastP = 'pdf-page-height' then begin
            Result.ErrorText := TryParseIntegerParameter('PDF-page-height', p, Result.PDFOptions.page_height, 10000, 10000000);
         end else if lastP = 'pdf-margin-top' then begin
            Result.ErrorText := TryParseIntegerParameter('PDF-margin-top', p, Result.PDFOptions.margin_top, 0, 10000);
         end else if lastP = 'pdf-margin-left' then begin
            Result.ErrorText := TryParseIntegerParameter('PDF-margin-left', p, Result.PDFOptions.margin_left, 0, 10000);
         end else if lastP = 'pdf-margin-right' then begin
            Result.ErrorText := TryParseIntegerParameter('PDF-margin-right', p, Result.PDFOptions.margin_right, 0, 10000);
         end else if lastP = 'pdf-margin-bottom' then begin
            Result.ErrorText := TryParseIntegerParameter('PDF-margin-bottom', p, Result.PDFOptions.margin_bottom, 0, 10000);
         end else if lastP = 'pdf-landscape' then begin
            Result.ErrorText := TryParseIntegerParameter('PDF-landscape', p, Result.PDFOptions.landscape, 0, 1);
         end else if lastP = 'pdf-title' then begin
            Result.PDFTitle := p;
         end else if lastP = 'pdf-url' then begin
            Result.PDFURL := p;
         end else if lastP = 'pdf-backgrounds' then begin
            Result.ErrorText := TryParseIntegerParameter('PDF-backgrounds', p, Result.PDFOptions.backgrounds_enabled, 0, 1);
//      property scale_factor          : integer                 read Fscale_factor             write Fscale_factor          default 0;
//      property header_footer_enabled : boolean                 read Fheader_footer_enabled    write Fheader_footer_enabled default False;
//      property selection_only        : boolean                 read Fselection_only           write Fselection_only        default False;
//      property landscape             : boolean                 read Flandscape                write Flandscape             default False;
//      property backgrounds_enabled   : boolean                 read Fbackgrounds_enabled      write Fbackgrounds_enabled   default False;
         end else begin
            Result.ErrorText := 'Unsupported parameter "' + p + '"';
         end;
         lastP := '';
      end;
      if Result.ErrorText <> '' then Exit;
   end;

   if CustomPathIsRelative(Result.OutputFilePath) then
      Result.OutputFilePath := IncludeTrailingPathDelimiter(GetCurrentDir) + Result.OutputFilePath;
   var ext := LowerCase(ExtractFileExt(Result.OutputFilePath));
   if ext = '.bmp' then
      Result.OutputFormat := sofBMP
   else if (ext = '.jpg') or (ext = '.jpeg') then
      Result.OutputFormat := sofJPG
   else if ext = '.png' then
      Result.OutputFormat := sofPNG
   else if ext = '.pdf' then
      Result.OutputFormat := sofPDF
   else begin
      Result.ErrorText := 'Unsupported output file format "' + Result.OutputFilePath + '"';
      Exit;
   end;

   if lastP <> '' then begin
      Result.ErrorText := 'Argument missing for parameter "' + lastP + '"';
   end else if Result.URL = '' then begin
      Result.ErrorText := 'Missing URL parameter, it is required';
   end;
end;

// SaveBitmapToJPEG
//
procedure SaveBitmapToJPEG(bmp : TBitmap; const fileName : String; quality : Integer);
begin
   LoadTurboJPEG(ExtractFilePath(ParamStr(0)) + cDLLSubfolder + '\turbojpeg-32.dll');
   var format := TJPF_UNKNOWN;
   case bmp.PixelFormat of
      pf32bit : format := TJPF_BGRA;
      pf24bit : format := TJPF_BGR;
   else
      Assert(False, 'Unsupported Bitmap PixelFormat');
   end;
   if format <> TJPF_UNKNOWN then begin
      var jpeg := TJ.InitCompress;
      try
         var outBuf : Pointer := nil;
         var outSize : Cardinal := 0;
         var pitch := 0;
         if bmp.Height > 1 then
            pitch := IntPtr(bmp.ScanLine[1]) - IntPtr(bmp.ScanLine[0]);
         if pitch >= 0 then begin
            if TJ.Compress2(jpeg, bmp.ScanLine[0], bmp.Width, pitch, bmp.Height, format,
                            @outBuf, @outSize, TJSAMP_420, quality, TJFLAG_PROGRESSIVE) <> 0 then
               RaiseLastTurboJPEGError(jpeg);
         end else begin
            if TJ.Compress2(jpeg, bmp.ScanLine[bmp.Height-1], bmp.Width, -pitch, bmp.Height, format,
                            @outBuf, @outSize, TJSAMP_420, quality, TJFLAG_PROGRESSIVE or TJFLAG_BOTTOMUP) <> 0 then
               RaiseLastTurboJPEGError(jpeg);
         end;
         try
            var fs := TFileStream.Create(fileName, fmCreate);
            try
               fs.Write(outBuf^, outSize);
            finally
               fs.Free;
            end;
         finally
           TJ.Free(outBuf);
         end;
      finally
         TJ.Destroy(jpeg);
      end;
      Exit;
   end;
end;

procedure SaveBitmapToPNG(bmp : TBitmap; const fileName : String; compressionLevel : Integer);
begin
   var png := TPNGImage.Create;
   try
      png.CompressionLevel := compressionLevel;
      png.Assign(bmp);
      png.SaveToFile(fileName);
   finally
      png.Free;
   end;
end;

// SaveBitmap
//
procedure TSnapshotParameters.SaveBitmap(bmp : TBitmap);
begin
   case OutputFormat of
      sofBMP : bmp.SaveToFile(OutputFilePath);
      sofJPG : SaveBitmapToJPEG(bmp, OutputFilePath, JPEGQuality);
      sofPNG : SaveBitmapToPNG(bmp, OutputFilePath, PNGCompressionLevel);
   end;
end;

end.
