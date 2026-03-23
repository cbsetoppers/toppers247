class PdfUtils {
  static String? extractDriveId(String url) {
    // Patterns: /d/ID/view, /file/d/ID, id=ID, open?id=ID, uc?id=ID
    final reg1 = RegExp(r'\/d\/([a-zA-Z0-9_-]{20,})');
    final reg2 = RegExp(r'[?&]id=([a-zA-Z0-9_-]{20,})');
    final reg3 = RegExp(r'id[_=]([a-zA-Z0-9_-]{20,})');
    
    final match1 = reg1.firstMatch(url);
    if (match1 != null) return match1.group(1);
    
    final match2 = reg2.firstMatch(url);
    if (match2 != null) return match2.group(1);
    
    final match3 = reg3.firstMatch(url);
    if (match3 != null) return match3.group(1);
    
    return null;
  }
}
