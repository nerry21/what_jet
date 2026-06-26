import 'package:flutter_test/flutter_test.dart';
import 'package:what_jet/features/omnichannel/data/models/omnichannel_thread_model.dart';

Map<String, dynamic> _msg(int id, String sentAt) => <String, dynamic>{
  'id': id,
  'sent_at': sentAt,
  'text': 'm$id',
};

Map<String, dynamic> _groupsPayload(List<Map<String, dynamic>> messages) =>
    <String, dynamic>{
      'thread_groups': <Map<String, dynamic>>[
        <String, dynamic>{'messages': messages},
      ],
    };

Map<String, dynamic> _flatPayload(List<Map<String, dynamic>> messages) =>
    <String, dynamic>{'messages': messages};

List<int> _ids(List<OmnichannelThreadGroupModel> groups) =>
    groups.expand((g) => g.messages).map((m) => m.id).toList();

void main() {
  group('fromSources merge + label (BRIEF #2A v2)', () {
    test('(a) direct & poll beda isi DIGABUNG (5 unik)', () {
      final result = OmnichannelThreadGroupModel.fromSources(
        messagesPayload: _groupsPayload(<Map<String, dynamic>>[
          _msg(1, '2026-06-26T10:00:00+07:00'),
          _msg(2, '2026-06-26T10:01:00+07:00'),
          _msg(3, '2026-06-26T10:02:00+07:00'),
        ]),
        pollPayload: _groupsPayload(<Map<String, dynamic>>[
          _msg(3, '2026-06-26T10:02:00+07:00'),
          _msg(4, '2026-06-26T10:03:00+07:00'),
          _msg(5, '2026-06-26T10:04:00+07:00'),
        ]),
      );
      expect(_ids(result), <int>[1, 2, 3, 4, 5]);
    });

    test('(b) id sama tak dobel', () {
      final result = OmnichannelThreadGroupModel.fromSources(
        messagesPayload: _groupsPayload(<Map<String, dynamic>>[
          _msg(1, '2026-06-26T10:00:00+07:00'),
          _msg(2, '2026-06-26T10:01:00+07:00'),
        ]),
        pollPayload: _groupsPayload(<Map<String, dynamic>>[
          _msg(2, '2026-06-26T10:01:00+07:00'),
          _msg(3, '2026-06-26T10:02:00+07:00'),
        ]),
      );
      expect(_ids(result), <int>[1, 2, 3]);
    });

    test('(c) urutan ASC sentAt (poll lebih awal)', () {
      final result = OmnichannelThreadGroupModel.fromSources(
        messagesPayload: _groupsPayload(<Map<String, dynamic>>[
          _msg(1, '2026-06-26T12:00:00+07:00'),
        ]),
        pollPayload: _groupsPayload(<Map<String, dynamic>>[
          _msg(2, '2026-06-26T10:00:00+07:00'),
          _msg(3, '2026-06-26T11:00:00+07:00'),
        ]),
      );
      expect(_ids(result), <int>[2, 3, 1]);
    });

    test('(d) flat-path fallback (tanpa thread_groups) tetap gabung', () {
      final result = OmnichannelThreadGroupModel.fromSources(
        messagesPayload: _flatPayload(<Map<String, dynamic>>[
          _msg(1, '2026-06-26T10:00:00+07:00'),
          _msg(2, '2026-06-26T10:01:00+07:00'),
        ]),
        pollPayload: _flatPayload(<Map<String, dynamic>>[
          _msg(2, '2026-06-26T10:01:00+07:00'),
          _msg(3, '2026-06-26T10:02:00+07:00'),
        ]),
      );
      expect(_ids(result), <int>[1, 2, 3]);
    });

    test('(e) label ramah: Hari Ini / Kemarin / d Mmm yyyy', () {
      // Pakai tengah-hari (noon) supaya hari jelas; satu-satunya window flake =
      // mikrodetik pergantian hari (DateTime.now() internal _groupLabel) — diterima.
      final now = DateTime.now();
      final todayNoon = DateTime(now.year, now.month, now.day, 12);
      final yesterdayNoon = todayNoon.subtract(const Duration(days: 1));

      final today = OmnichannelThreadGroupModel.fromSources(
        messagesPayload: _groupsPayload(<Map<String, dynamic>>[
          _msg(1, todayNoon.toIso8601String()),
        ]),
      );
      expect(today.single.label, 'Hari Ini');

      final yesterday = OmnichannelThreadGroupModel.fromSources(
        messagesPayload: _groupsPayload(<Map<String, dynamic>>[
          _msg(2, yesterdayNoon.toIso8601String()),
        ]),
      );
      expect(yesterday.single.label, 'Kemarin');

      final fixed = OmnichannelThreadGroupModel.fromSources(
        messagesPayload: _groupsPayload(<Map<String, dynamic>>[
          _msg(3, DateTime(2020, 6, 24).toIso8601String()),
        ]),
      );
      expect(fixed.single.label, '24 Jun 2020');
    });
  });
}
