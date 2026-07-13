import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart' as ex;
import 'package:csv/csv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';

class TimetableParserService {
  final _picker = ImagePicker();

  /// Pick an image and return its base64 representation.
  Future<String> parseImageToBase64(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return '';

    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  /// Parse a PDF by rendering its pages to base64 images.
  Future<List<String>> parsePdfToBase64(String pdfPath) async {
    final document = await PdfDocument.openFile(pdfPath);
    final List<String> base64Images = [];

    try {
      for (int i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2, // scale up for vision models
          height: page.height * 2,
          format: PdfPageImageFormat.jpeg,
        );

        if (pageImage != null) {
          base64Images.add(base64Encode(pageImage.bytes));
        }
        await page.close();
      }
    } finally {
      await document.close();
    }

    return base64Images;
  }

  /// Read Excel file and convert it to a structured text representation.
  Future<String> parseExcel(String filePath) async {
    final bytes = File(filePath).readAsBytesSync();
    final excel = ex.Excel.decodeBytes(bytes);
    final StringBuffer buffer = StringBuffer();

    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null) continue;
      buffer.writeln("--- Worksheet: $table ---");
      for (int r = 0; r < sheet.maxRows; r++) {
        final row = sheet.rows[r];
        final List<String> rowTexts = [];
        for (int c = 0; c < sheet.maxColumns; c++) {
          final cell = row.length > c ? row[c] : null;
          final val = cell?.value?.toString().trim() ?? '';
          rowTexts.add(val.isEmpty ? '[Empty]' : val);
        }
        buffer.writeln("Row ${r + 1}: ${rowTexts.join(' | ')}");
      }
    }

    return buffer.toString();
  }

  /// Read CSV file and convert it to a structured text representation.
  Future<String> parseCsv(String filePath) async {
    final csvString = await File(filePath).readAsString();
    final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
    final StringBuffer buffer = StringBuffer();

    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      final List<String> rowTexts = row.map((cell) => cell?.toString().trim() ?? '').toList();
      buffer.writeln("Row ${r + 1}: ${rowTexts.join(' | ')}");
    }

    return buffer.toString();
  }
}
