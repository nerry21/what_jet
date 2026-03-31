import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:what_jet/core/config/app_config.dart';
import 'package:what_jet/core/network/api_client.dart';
import 'package:what_jet/core/storage/token_storage.dart';
import 'package:what_jet/features/auth/data/services/auth_api_service.dart';
import 'package:what_jet/features/live_chat/data/repositories/live_chat_repository.dart';
import 'package:what_jet/features/live_chat/data/services/live_chat_api_service.dart';
import 'package:what_jet/features/live_chat/presentation/pages/chat_detail_page.dart';
import 'package:what_jet/features/live_chat/presentation/pages/live_chat_page.dart';

void main() {
  testWidgets('renders conversation, opens detail, and sends a message', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(const <String, Object>{
      'mobile_access_token': 'test-access-token',
      'mobile_token_type': 'Bearer',
      'mobile_user_id': 'mlc-user-test',
      'mobile_device_id': 'mlc-device-test',
      'mobile_display_name': 'Budi',
      'mobile_email': 'budi@example.com',
      'active_conversation_id': 1,
    });

    var messageCounter = 1;

    final apiClient = ApiClient(
      httpClient: MockClient((http.Request request) async {
        final path = request.url.path;
        final method = request.method;

        if (path.endsWith('/api/mobile/auth/me') && method == 'GET') {
          return http.Response(jsonEncode(_success(_mePayload())), 200);
        }

        if (path.endsWith('/api/mobile/live-chat/conversations') &&
            method == 'GET') {
          return http.Response(
            jsonEncode(_success(_conversationListPayload())),
            200,
          );
        }

        if (path.endsWith('/api/mobile/live-chat/conversations/1/messages') &&
            method == 'GET') {
          return http.Response(
            jsonEncode(_success(_conversationMessagesPayload())),
            200,
          );
        }

        if (path.endsWith('/api/mobile/live-chat/conversations/1/mark-read') &&
            method == 'POST') {
          return http.Response(jsonEncode(_success(_markReadPayload())), 200);
        }

        if (path.endsWith('/api/mobile/live-chat/conversations/1/messages') &&
            method == 'POST') {
          messageCounter += 1;
          final payload =
              jsonDecode(request.body) as Map<String, dynamic>? ??
              <String, dynamic>{};

          return http.Response(
            jsonEncode(
              _success(
                _sendMessagePayload(
                  id: messageCounter,
                  text: payload['message']?.toString() ?? '',
                  clientMessageId:
                      payload['client_message_id']?.toString() ?? 'msg-test',
                ),
              ),
            ),
            201,
          );
        }

        if (path.endsWith('/api/mobile/live-chat/conversations/1/poll') &&
            method == 'GET') {
          return http.Response(jsonEncode(_success(_pollPayload())), 200);
        }

        return http.Response(
          jsonEncode(<String, Object>{
            'success': false,
            'message': 'Unhandled route: $path',
          }),
          404,
        );
      }),
    );

    final repository = LiveChatRepository(
      authApiService: AuthApiService(apiClient),
      liveChatApiService: LiveChatApiService(apiClient),
      tokenStorage: TokenStorage(),
    );

    addTearDown(apiClient.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppConfig.theme(),
        home: LiveChatPage(repository: repository),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('JET Support'), findsOneWidget);

    await tester.tap(find.text('JET Support'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.descendant(
        of: find.byType(ChatDetailPage),
        matching: find.text('Halo, saya butuh bantuan.'),
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).last, 'Tes dari Flutter');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.descendant(
        of: find.byType(ChatDetailPage),
        matching: find.text('Tes dari Flutter'),
      ),
      findsOneWidget,
    );
  });
}

Map<String, Object?> _success(Map<String, Object?> data) {
  return <String, Object?>{'success': true, 'message': 'OK', 'data': data};
}

Map<String, Object?> _mePayload() {
  return <String, Object?>{'customer': _customerPayload()};
}

Map<String, Object?> _conversationListPayload() {
  return <String, Object?>{
    'customer': _customerPayload(),
    'conversations': <Object?>[
      _conversationPayload(
        latestMessagePreview: 'Halo, saya butuh bantuan.',
        unreadCount: 1,
      ),
    ],
    'meta': <String, Object?>{
      'channel': 'mobile_live_chat',
      'channel_label': 'Mobile Live Chat',
      'source_app': 'what_jet_flutter',
      'source_label': 'What Jet Flutter',
      'poll_interval_ms': 3000,
    },
  };
}

Map<String, Object?> _conversationMessagesPayload() {
  return <String, Object?>{
    'customer': _customerPayload(),
    'conversation': _conversationPayload(
      latestMessagePreview: 'Halo, saya butuh bantuan.',
      unreadCount: 1,
    ),
    'messages': <Object?>[
      <String, Object?>{
        'id': 1,
        'conversation_id': 1,
        'direction': 'outbound',
        'sender_type': 'bot',
        'message_type': 'text',
        'message_text': 'Halo, saya butuh bantuan.',
        'delivery_status': 'sent',
        'client_message_id': null,
        'channel_message_id': 'srv-1',
        'read_at': null,
        'delivered_to_app_at': '2026-03-29T10:30:00+07:00',
        'sent_at': '2026-03-29T10:30:00+07:00',
        'created_at': '2026-03-29T10:30:00+07:00',
        'updated_at': '2026-03-29T10:30:00+07:00',
        'is_fallback': false,
        'is_mine': false,
      },
    ],
    'meta': <String, Object?>{
      'channel': 'mobile_live_chat',
      'channel_label': 'Mobile Live Chat',
      'source_app': 'what_jet_flutter',
      'source_label': 'What Jet Flutter',
      'poll_interval_ms': 3000,
      'latest_message_id': 1,
      'delta_count': 1,
    },
  };
}

Map<String, Object?> _markReadPayload() {
  return <String, Object?>{
    'updated_count': 1,
    'conversation': _conversationPayload(
      latestMessagePreview: 'Halo, saya butuh bantuan.',
      unreadCount: 0,
      lastReadAtCustomer: '2026-03-29T10:31:00+07:00',
    ),
    'meta': <String, Object?>{
      'channel': 'mobile_live_chat',
      'channel_label': 'Mobile Live Chat',
      'poll_interval_ms': 3000,
    },
  };
}

Map<String, Object?> _sendMessagePayload({
  required int id,
  required String text,
  required String clientMessageId,
}) {
  return <String, Object?>{
    'customer': _customerPayload(),
    'conversation': _conversationPayload(
      latestMessagePreview: text,
      unreadCount: 0,
      lastReadAtCustomer: '2026-03-29T10:32:00+07:00',
      latestMessageId: id,
      lastMessageAt: '2026-03-29T10:32:00+07:00',
    ),
    'message': <String, Object?>{
      'id': id,
      'conversation_id': 1,
      'direction': 'inbound',
      'sender_type': 'customer',
      'message_type': 'text',
      'message_text': text,
      'delivery_status': 'sent',
      'client_message_id': clientMessageId,
      'channel_message_id': 'srv-$id',
      'read_at': '2026-03-29T10:32:00+07:00',
      'delivered_to_app_at': '2026-03-29T10:32:00+07:00',
      'sent_at': '2026-03-29T10:32:00+07:00',
      'created_at': '2026-03-29T10:32:00+07:00',
      'updated_at': '2026-03-29T10:32:00+07:00',
      'is_fallback': false,
      'is_mine': true,
    },
    'duplicate': false,
    'meta': <String, Object?>{
      'channel': 'mobile_live_chat',
      'channel_label': 'Mobile Live Chat',
      'source_app': 'what_jet_flutter',
      'source_label': 'What Jet Flutter',
      'poll_interval_ms': 3000,
    },
  };
}

Map<String, Object?> _pollPayload() {
  return <String, Object?>{
    'conversation': _conversationPayload(
      latestMessagePreview: 'Halo, saya butuh bantuan.',
      unreadCount: 0,
      lastReadAtCustomer: '2026-03-29T10:31:00+07:00',
    ),
    'messages': const <Object?>[],
    'meta': <String, Object?>{
      'channel': 'mobile_live_chat',
      'channel_label': 'Mobile Live Chat',
      'source_app': 'what_jet_flutter',
      'source_label': 'What Jet Flutter',
      'poll_interval_ms': 3000,
      'latest_message_id': 1,
      'unread_count': 0,
      'delta_count': 0,
    },
  };
}

Map<String, Object?> _customerPayload() {
  return <String, Object?>{
    'id': 11,
    'mobile_user_id': 'mlc-user-test',
    'name': 'Budi',
    'email': 'budi@example.com',
    'display_contact': 'Budi',
    'preferred_channel': 'mobile_live_chat',
    'mobile_device_id': 'mlc-device-test',
    'status': 'active',
    'last_interaction_at': '2026-03-29T10:30:00+07:00',
  };
}

Map<String, Object?> _conversationPayload({
  required String latestMessagePreview,
  required int unreadCount,
  String lastMessageAt = '2026-03-29T10:30:00+07:00',
  String? lastReadAtCustomer,
  int latestMessageId = 1,
}) {
  return <String, Object?>{
    'id': 1,
    'channel': 'mobile_live_chat',
    'channel_label': 'Mobile Live Chat',
    'is_whatsapp': false,
    'is_mobile_live_chat': true,
    'channel_conversation_id': 'mobile-1',
    'source_app': 'what_jet_flutter',
    'source_label': 'What Jet Flutter',
    'is_from_mobile_app': true,
    'status': 'active',
    'operational_mode': 'bot_active',
    'operational_mode_label': 'Bot Active',
    'needs_human': false,
    'handoff_mode': null,
    'started_at': '2026-03-29T10:30:00+07:00',
    'last_message_at': lastMessageAt,
    'last_read_at_customer': lastReadAtCustomer,
    'last_read_at_admin': null,
    'unread_count': unreadCount,
    'latest_message_id': latestMessageId,
    'latest_message_preview': latestMessagePreview,
    'customer': _customerPayload(),
  };
}
