enum DownloadStatus { notDownloaded, downloading, downloaded, failed }

class PdfFileModel {
  final String id;
  final String name;
  final String? driveFileId;
  final String? url;
  final String subject;
  DownloadStatus status;
  double progress;

  PdfFileModel({
    required this.id,
    required this.name,
    this.driveFileId,
    this.url,
    required this.subject,
    this.status = DownloadStatus.notDownloaded,
    this.progress = 0.0,
  }) : assert(driveFileId != null || url != null);

  String get downloadUrl {
    if (driveFileId != null) {
      return 'https://docs.google.com/uc?export=download&id=$driveFileId';
    }
    return url!;
  }
}

final List<PdfFileModel> allPdfs = [
  // Example PDFs. You should populate this from your backend or topper store.
  PdfFileModel(
    id: 'physics_notes_ch1',
    name: 'Physics Chapter 1 Notes',
    driveFileId: 'YOUR_DRIVE_FILE_ID_HERE',
    subject: 'Physics',
  ),
];
