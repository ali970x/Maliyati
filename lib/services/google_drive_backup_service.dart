import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class GoogleDriveBackupFile {
  const GoogleDriveBackupFile({
    required this.id,
    required this.name,
    required this.modifiedAt,
    required this.size,
  });

  final String id;
  final String name;
  final DateTime? modifiedAt;
  final int size;
}

/// Stores only files created by Maliyati in the signed-in user's Google Drive.
class GoogleDriveBackupService {
  GoogleDriveBackupService({GoogleSignIn? signIn, http.Client? client})
    : _signIn =
          signIn ??
          GoogleSignIn(
            clientId: kIsWeb ? AppConfig.googleWebClientId : null,
            scopes: const [_driveFileScope],
          ),
      _client = client ?? http.Client();

  static const _driveFileScope = 'https://www.googleapis.com/auth/drive.file';
  static const _filePrefix = 'maliyati-backup-';

  final GoogleSignIn _signIn;
  final http.Client _client;

  Future<GoogleDriveBackupFile> uploadBackup(
    Map<String, dynamic> backup, {
    bool allowInteractiveSignIn = true,
  }) async {
    final token = await _accessToken(
      allowInteractiveSignIn: allowInteractiveSignIn,
    );
    final savedAt = '${backup['savedAt'] ?? DateTime.now().toIso8601String()}';
    final fileName = '$_filePrefix$savedAt.json';
    const boundary = 'maliyati_drive_backup_boundary';
    final metadata = jsonEncode({
      'name': fileName,
      'mimeType': 'application/json',
      'description': 'Maliyati financial data backup',
    });
    final body = StringBuffer()
      ..write('--$boundary\r\n')
      ..write('Content-Type: application/json; charset=UTF-8\r\n\r\n')
      ..write(metadata)
      ..write('\r\n--$boundary\r\n')
      ..write('Content-Type: application/json; charset=UTF-8\r\n\r\n')
      ..write(jsonEncode(backup))
      ..write('\r\n--$boundary--\r\n');

    final response = await _client.post(
      Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,modifiedTime,size',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: utf8.encode(body.toString()),
    );
    final data = _decodeResponse(response, action: 'save the backup');
    return _fileFromJson(data);
  }

  Future<List<GoogleDriveBackupFile>> listBackups() async {
    final token = await _accessToken();
    final response = await _client.get(
      Uri.https('www.googleapis.com', '/drive/v3/files', {
        'q': "name contains '$_filePrefix' and trashed = false",
        'orderBy': 'modifiedTime desc',
        'pageSize': '10',
        'fields': 'files(id,name,modifiedTime,size)',
      }),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _decodeResponse(response, action: 'list backups');
    final files = data['files'];
    if (files is! List) {
      return const [];
    }
    return files
        .whereType<Map>()
        .map((item) => _fileFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> downloadBackup(String fileId) async {
    final token = await _accessToken();
    final response = await _client.get(
      Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {
        'alt': 'media',
      }),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _decodeResponse(response, action: 'download the backup');
    if (data['transactions'] is! List) {
      throw const GoogleDriveBackupException(
        'The Google Drive backup is invalid.',
      );
    }
    return data;
  }

  Future<String> _accessToken({bool allowInteractiveSignIn = true}) async {
    final account =
        _signIn.currentUser ??
        await _signIn.signInSilently() ??
        (allowInteractiveSignIn ? await _signIn.signIn() : null);
    if (account == null) {
      throw const GoogleDriveBackupException(
        'Google Drive connection was cancelled.',
      );
    }
    final granted = await _signIn.requestScopes(const [_driveFileScope]);
    if (!granted) {
      throw const GoogleDriveBackupException(
        'Google Drive permission is required to back up your data.',
      );
    }
    final token = (await account.authentication).accessToken;
    if (token == null || token.isEmpty) {
      throw const GoogleDriveBackupException(
        'Google Drive could not provide an access token. Enable the Google Drive API for this app, then try again.',
      );
    }
    return token;
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response, {
    required String action,
  }) {
    final decoded = response.body.trim().isEmpty
        ? null
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? '${decoded['error'] is Map ? decoded['error']['message'] : decoded['error']}'
          : 'HTTP ${response.statusCode}';
      throw GoogleDriveBackupException('Could not $action: $message');
    }
    if (decoded is! Map) {
      throw GoogleDriveBackupException(
        'Could not $action: invalid Google Drive response.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  GoogleDriveBackupFile _fileFromJson(Map<String, dynamic> data) {
    return GoogleDriveBackupFile(
      id: '${data['id'] ?? ''}',
      name: '${data['name'] ?? 'Maliyati backup'}',
      modifiedAt: DateTime.tryParse('${data['modifiedTime'] ?? ''}'),
      size: int.tryParse('${data['size'] ?? ''}') ?? 0,
    );
  }
}

class GoogleDriveBackupException implements Exception {
  const GoogleDriveBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}
