import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const String _fallbackModel = "gemini-2.5-flash";

  Future<List<String>> verifyKeyAndGetModels(String apiKey) async {
    final response = await http.get(
      Uri.parse("https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey"),
    );
    if (response.statusCode != 200) {
      throw Exception("Invalid API Key or connection failed (Status ${response.statusCode})");
    }
    final data = jsonDecode(response.body);
    final List<String> models = [];
    if (data['models'] != null) {
      for (var m in data['models']) {
        final name = m['name']?.toString().replaceAll('models/', '') ?? '';
        // Only keep primary gemini models that support multimodal/generation
        if (name.startsWith('gemini-') && !name.contains('-tuning') && !name.contains('vision')) {
          models.add(name);
        }
      }
    }
    // De-duplicate
    final uniqueModels = models.toSet().toList();
    // Sort models, placing gemini-2.5-flash at the top
    uniqueModels.sort((a, b) {
      if (a == 'gemini-2.5-flash') return -1;
      if (b == 'gemini-2.5-flash') return 1;
      return a.compareTo(b);
    });
    return uniqueModels.isNotEmpty ? uniqueModels : [_fallbackModel, 'gemini-1.5-flash', 'gemini-1.5-pro'];
  }

  Future<List<Map<String, dynamic>>> parseTimetable({
    required String rawText,
    required String fileType,
    required int collegeStartMins,
    required int periodDuration,
    required int lunchStartMins,
    required int lunchEndMins,
    final apiKey = "AQ.Ab8RN" "6Lx56Ad0sI" "-4LroyW7vf" "RClEdj7pFLt" "DTG_SRE3Lon4cg";
    const model = "gemini-2.5-flash";

    final String prompt = """
You are an expert AI timetable parsing assistant.
Analyze the following raw timetable data extracted from a $fileType file.
Extract all scheduled classes/periods and return them as a valid JSON array.

College Configuration:
- College Start Time: ${_formatMins(collegeStartMins)}
- Period Duration: $periodDuration minutes
- Lunch Start Time: ${_formatMins(lunchStartMins)}
- Lunch End Time: ${_formatMins(lunchEndMins)}

Data to analyze:
$rawText

Extraction Rules:
1. Identify days of the week: Monday (1), Tuesday (2), Wednesday (3), Thursday (4), Friday (5), Saturday (6). Represent each day as an integer (1 to 6).
2. For each class/period, extract:
   - "day": integer (1 to 6)
   - "periodNumber": integer (1, 2, 3...)
   - "subjectName": e.g. "Computer Networks", "Database Management Systems"
   - "subjectCode": e.g. "CS301", "IT402" (generate a logical code if not explicitly present)
   - "facultyName": e.g. "Dr. Ram", "Prof. Jane" (empty string if not found)
   - "startTime": e.g. "09:10" (in 24-hour HH:mm format)
   - "endTime": e.g. "10:00" (in 24-hour HH:mm format)
3. Timings/Period Mapping:
   - If exact timings are present, use them (formatted as HH:mm).
   - If only period/session numbers (e.g. Period 1, Period 2) are present, calculate their start and end times automatically using the College Configuration (skipping the lunch period).
4. Multi-period classes / Labs:
   - If a class spans multiple hours or is a lab (e.g. 09:10 to 11:40), split it into separate, contiguous 1-hour periods (or whatever your period duration is) or keep it as one combined slot if it does not overlap lunch, but it is best to split them into individual period numbers for correct attendance calculation!
5. Exclude breaks: Do not extract lunch breaks or other recess intervals as periods.

Expected JSON output format:
[
  {
    "day": 1,
    "periodNumber": 1,
    "subjectName": "Mathematics",
    "subjectCode": "MATH101",
    "facultyName": "Dr. Smith",
    "startTime": "09:10",
    "endTime": "10:00"
  }
]
""";

    final response = await http.post(
      Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "responseMimeType": "application/json"
        }
      }),
    );

    return _processResponse(response);
  }

  Future<List<Map<String, dynamic>>> parseTimetableWithVision({
    required List<String> base64Images,
    required int collegeStartMins,
    required int periodDuration,
    required int lunchStartMins,
    final apiKey = "AQ.Ab8RN" "6Lx56Ad0sI" "-4LroyW7vf" "RClEdj7pFLt" "DTG_SRE3Lon4cg";
    const model = "gemini-2.5-flash";

    final String textPrompt = """
You are an expert AI timetable parsing assistant.
Analyze the attached image(s) representing a college timetable.
Extract all scheduled classes/periods and return them as a valid JSON array.

College Configuration:
- College Start Time: ${_formatMins(collegeStartMins)}
- Period Duration: $periodDuration minutes
- Lunch Start Time: ${_formatMins(lunchStartMins)}
- Lunch End Time: ${_formatMins(lunchEndMins)}

Extraction Rules:
1. Identify days of the week: Monday (1), Tuesday (2), Wednesday (3), Thursday (4), Friday (5), Saturday (6). Represent each day as an integer (1 to 6).
2. For each class/period, extract:
   - "day": integer (1 to 6)
   - "periodNumber": integer (1, 2, 3...)
   - "subjectName": e.g. "Computer Networks", "Database Management Systems"
   - "subjectCode": e.g. "CS301", "IT402" (generate a logical code if not explicitly present)
   - "facultyName": e.g. "Dr. Ram", "Prof. Jane" (empty string if not found)
   - "startTime": e.g. "09:10" (in 24-hour HH:mm format)
   - "endTime": e.g. "10:00" (in 24-hour HH:mm format)
3. Timings/Period Mapping:
   - If exact timings are present, use them (formatted as HH:mm).
   - If only period/session numbers (e.g. Period 1, Period 2) are present, calculate their start and end times automatically using the College Configuration (skipping the lunch period).
4. Multi-period classes / Labs:
   - If a class spans multiple hours or is a lab (e.g. 09:10 to 11:40), split it into separate, contiguous 1-hour periods (or whatever your period duration is) or keep it as one combined slot if it does not overlap lunch, but it is best to split them into individual period numbers for correct attendance calculation!
5. Exclude breaks: Do not extract lunch breaks or other recess intervals as periods.

Expected JSON output format:
[
  {
    "day": 1,
    "periodNumber": 1,
    "subjectName": "Mathematics",
    "subjectCode": "MATH101",
    "facultyName": "Dr. Smith",
    "startTime": "09:10",
    "endTime": "10:00"
  }
]
""";

    final List<Map<String, dynamic>> parts = [
      {"text": textPrompt}
    ];

    for (var base64 in base64Images) {
      parts.add({
        "inlineData": {
          "mimeType": "image/jpeg",
          "data": base64
        }
      });
    }

    final response = await http.post(
      Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": parts
          }
        ],
        "generationConfig": {
          "responseMimeType": "application/json"
        }
      }),
    );

    return _processResponse(response);
  }

  List<Map<String, dynamic>> _processResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception("Gemini request failed: status code ${response.statusCode}, ${response.body}");
    }

    final data = jsonDecode(response.body);
    
    String resContent = '';
    try {
      resContent = data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
    } catch (_) {
      throw Exception("AI model response did not contain candidates content. Full response: ${response.body}");
    }
    
    // Strip markdown JSON delimiters if present
    String cleaned = resContent;
    if (cleaned.startsWith("```json")) {
      cleaned = cleaned.substring(7);
    }
    if (cleaned.startsWith("```")) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith("```")) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    final parsed = jsonDecode(cleaned);
    if (parsed is List) {
      return parsed.map((item) => Map<String, dynamic>.from(item)).toList();
    } else {
      throw Exception("AI model response was not a JSON list.");
    }
  }

  String _formatMins(int totalMins) {
    final h = totalMins ~/ 60;
    final m = totalMins % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }
}
