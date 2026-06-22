import 'package:flutter_test/flutter_test.dart';

import 'package:what_jet/features/omnichannel/data/models/omnichannel_thread_model.dart';
import 'package:what_jet/features/omnichannel/presentation/widgets/omnichannel_center_pane.dart';

void main() {
  Map<String, dynamic> msg(int id, String text) => <String, dynamic>{
    'id': id,
    'message_type': 'text',
    'text': text,
  };

  OmnichannelThreadGroupModel buildGroup(
    String label,
    List<Map<String, dynamic>> messages,
  ) => OmnichannelThreadGroupModel.fromJson(<String, dynamic>{
    'label': label,
    'messages': messages,
  });

  group('omnichannelInChatSearchMatchIds (BRIEF 3F)', () {
    final groups = <OmnichannelThreadGroupModel>[
      buildGroup('Kemarin', <Map<String, dynamic>>[
        msg(1, 'Halo, mau tanya pasir pengaraian'),
        msg(2, 'Stok kosong'),
      ]),
      buildGroup('Hari Ini', <Map<String, dynamic>>[
        msg(3, 'PASIR sudah ready'),
        msg(4, ''),
        msg(5, 'oke siap'),
      ]),
    ];

    test('1. query kosong -> []', () {
      expect(omnichannelInChatSearchMatchIds(groups, ''), <int>[]);
    });

    test('2. query hanya spasi -> []', () {
      expect(omnichannelInChatSearchMatchIds(groups, '   '), <int>[]);
    });

    test('3. tanpa kecocokan -> []', () {
      expect(omnichannelInChatSearchMatchIds(groups, 'zzz tidak ada'), <int>[]);
    });

    test('4. case-insensitive contains, urut thread', () {
      expect(omnichannelInChatSearchMatchIds(groups, 'pasir'), <int>[1, 3]);
    });

    test('5. query ber-spasi di-trim', () {
      expect(omnichannelInChatSearchMatchIds(groups, '  pasir  '), <int>[1, 3]);
    });

    test('6. pesan text kosong tidak crash & tidak match', () {
      expect(omnichannelInChatSearchMatchIds(groups, 'ready'), <int>[3]);
      expect(omnichannelInChatSearchMatchIds(groups, 'siap'), <int>[5]);
    });

    test('7. groups kosong -> []', () {
      expect(
        omnichannelInChatSearchMatchIds(
          const <OmnichannelThreadGroupModel>[],
          'pasir',
        ),
        <int>[],
      );
    });
  });
}
