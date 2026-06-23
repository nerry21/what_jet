import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:what_jet/core/network/api_client.dart';
import 'package:what_jet/core/storage/admin_token_storage.dart';
import 'package:what_jet/features/admin_auth/data/repositories/admin_auth_repository.dart';
import 'package:what_jet/features/admin_auth/data/services/admin_auth_api_service.dart';
import 'package:what_jet/features/omnichannel/data/repositories/omnichannel_repository.dart';
import 'package:what_jet/features/omnichannel/data/services/omnichannel_api_service.dart';
import 'package:what_jet/features/omnichannel/presentation/widgets/whatsapp_attachment_sheet.dart';

class _CapturingApiClient extends ApiClient {
  Map<String, Object?>? lastBody;
  Map<String, Object?>? lastFields;
  List<ApiMultipartFile>? lastFiles;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, Object?> body = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
  }) {
    lastBody = body;
    return Future<Map<String, dynamic>>.value(<String, dynamic>{});
  }

  @override
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, Object?> fields = const <String, Object?>{},
    List<ApiMultipartFile> files = const <ApiMultipartFile>[],
    Map<String, String> headers = const <String, String>{},
  }) {
    lastFields = fields;
    lastFiles = files;
    return Future<Map<String, dynamic>>.value(<String, dynamic>{});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OmnichannelApiService reply_to_message_id (Wave 2B-4c-1)', () {
    late _CapturingApiClient client;
    late OmnichannelApiService service;

    setUp(() {
      client = _CapturingApiClient();
      service = OmnichannelApiService(client);
    });

    tearDown(() {
      client.dispose();
    });

    test('1. text includes reply_to_message_id (int) when provided', () async {
      await service.sendAdminReply(
        accessToken: 'token',
        conversationId: 1,
        message: 'halo',
        replyToMessageId: 42,
      );

      expect(client.lastBody!['reply_to_message_id'], 42);
      expect(client.lastBody!['message_type'], 'text');
      expect(client.lastBody!['message'], 'halo');
    });

    test('2. text omits reply_to_message_id when null (default)', () async {
      await service.sendAdminReply(
        accessToken: 'token',
        conversationId: 1,
        message: 'halo',
      );

      expect(client.lastBody!.containsKey('reply_to_message_id'), isFalse);
      expect(client.lastBody!['message_type'], 'text');
      expect(client.lastBody!['message'], 'halo');
    });

    test(
      '3. image includes reply_to_message_id (string) when provided',
      () async {
        await service.sendAdminImageReply(
          accessToken: 'token',
          conversationId: 1,
          fileBytes: <int>[1, 2, 3],
          fileName: 'a.jpg',
          replyToMessageId: 7,
        );

        expect(client.lastFields!['reply_to_message_id'], '7');
        expect(client.lastFields!['message_type'], 'image');
      },
    );

    test(
      '4. image/audio/document omit reply_to_message_id when null',
      () async {
        await service.sendAdminImageReply(
          accessToken: 'token',
          conversationId: 1,
          fileBytes: <int>[1, 2, 3],
          fileName: 'a.jpg',
        );
        expect(client.lastFields!.containsKey('reply_to_message_id'), isFalse);

        await service.sendAdminAudioReply(
          accessToken: 'token',
          conversationId: 1,
          fileBytes: <int>[1, 2, 3],
          fileName: 'a.ogg',
        );
        expect(client.lastFields!.containsKey('reply_to_message_id'), isFalse);

        await service.sendAdminDocumentReply(
          accessToken: 'token',
          conversationId: 1,
          fileBytes: <int>[1, 2, 3],
          fileName: 'a.pdf',
        );
        expect(client.lastFields!.containsKey('reply_to_message_id'), isFalse);
      },
    );

    test(
      '5. existing entries unchanged when reply id null (regression)',
      () async {
        await service.sendAdminAudioReply(
          accessToken: 'token',
          conversationId: 1,
          fileBytes: <int>[1, 2, 3],
          fileName: 'a.ogg',
          mimeType: 'audio/ogg',
          caption: 'cap',
        );

        expect(client.lastFields!['message_type'], 'audio');
        expect(client.lastFields!['voice'], '1');
        expect(client.lastFields!['caption'], 'cap');
        expect(client.lastFields!['mime_type'], 'audio/ogg');
        expect(client.lastFields!.containsKey('reply_to_message_id'), isFalse);
      },
    );
  });

  group(
    'OmnichannelRepository forwards reply_to_message_id (Wave 2B-4c-1)',
    () {
      late _CapturingApiClient client;
      late OmnichannelRepository repository;

      setUp(() {
        SharedPreferences.setMockInitialValues(const <String, Object>{
          'admin_mobile_access_token': 'admin-test-token',
        });
        client = _CapturingApiClient();
        repository = OmnichannelRepository(
          apiService: OmnichannelApiService(client),
          adminAuthRepository: AdminAuthRepository(
            authApiService: AdminAuthApiService(client),
            tokenStorage: AdminTokenStorage(),
          ),
        );
      });

      tearDown(() {
        client.dispose();
      });

      test('6. repository forwards reply id to text api (post)', () async {
        await repository.sendAdminReply(
          conversationId: 1,
          message: 'halo',
          replyToMessageId: 42,
        );

        expect(client.lastBody!['reply_to_message_id'], 42);
      });

      test(
        '7. repository forwards reply id to image api (multipart)',
        () async {
          await repository.sendAdminImageReply(
            conversationId: 1,
            fileBytes: <int>[1, 2, 3],
            fileName: 'a.jpg',
            replyToMessageId: 7,
          );

          expect(client.lastFields!['reply_to_message_id'], '7');
        },
      );
    },
  );

  group('OmnichannelApiService video reply (BRIEF 4B-APP)', () {
    late _CapturingApiClient client;
    late OmnichannelApiService service;

    setUp(() {
      client = _CapturingApiClient();
      service = OmnichannelApiService(client);
    });

    tearDown(() {
      client.dispose();
    });

    test(
      '8. video sets message_type video + multipart video_file + reply id',
      () async {
        await service.sendAdminVideoReply(
          accessToken: 'token',
          conversationId: 1,
          fileBytes: <int>[1, 2, 3],
          fileName: 'clip.mp4',
          mimeType: 'video/mp4',
          replyToMessageId: 9,
        );

        expect(client.lastFields!['message_type'], 'video');
        expect(client.lastFields!['reply_to_message_id'], '9');

        final file = client.lastFiles!.single;
        expect(file.field, 'video_file');
        expect(file.filename, 'clip.mp4');
        expect(file.contentType, 'video/mp4');
        expect(file.bytes, <int>[1, 2, 3]);
      },
    );

    test('9. video omits reply_to_message_id when null', () async {
      await service.sendAdminVideoReply(
        accessToken: 'token',
        conversationId: 1,
        fileBytes: <int>[1, 2, 3],
        fileName: 'clip.mp4',
        mimeType: 'video/mp4',
      );

      expect(client.lastFields!.containsKey('reply_to_message_id'), isFalse);
      expect(client.lastFields!['message_type'], 'video');
      expect(client.lastFiles!.single.field, 'video_file');
    });
  });

  group('Attachment tray video gate (BRIEF 4B-APP)', () {
    testWidgets('10. tray ON: tile Video hadir (setelah Kamera)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showWhatsAppAttachmentSheet(
                  context: ctx,
                  onGalleryTap: () async {},
                  onCameraTap: () async {},
                  onLocationTap: () async {},
                  onContactTap: () async {},
                  onDocumentTap: () async {},
                  onAudioTap: () async {},
                  onPollTap: () async {},
                  onEventTap: () async {},
                  onVideoFileTap: () async {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Kamera'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
    });

    testWidgets('11. tray OFF: tile Video absen, tray lama identik', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showWhatsAppAttachmentSheet(
                  context: ctx,
                  onGalleryTap: () async {},
                  onCameraTap: () async {},
                  onLocationTap: () async {},
                  onContactTap: () async {},
                  onDocumentTap: () async {},
                  onAudioTap: () async {},
                  onPollTap: () async {},
                  onEventTap: () async {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Kamera'), findsOneWidget);
      expect(find.text('Video'), findsNothing);
    });
  });
}
