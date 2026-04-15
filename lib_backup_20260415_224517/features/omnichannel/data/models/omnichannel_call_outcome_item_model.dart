import 'omnichannel_payload_parser.dart';

class OmnichannelCallOutcomeItemModel {
  const OmnichannelCallOutcomeItemModel({
    required this.finalStatus,
    required this.label,
    required this.count,
    required this.percentage,
  });

  final String finalStatus;
  final String label;
  final int count;
  final double percentage;

  factory OmnichannelCallOutcomeItemModel.fromJson(Map<String, dynamic> json) {
    return OmnichannelCallOutcomeItemModel(
      finalStatus:
          omnichannelFirstMapped<String>(
            json,
            const <String>['final_status'],
            omnichannelString,
          ) ??
          'in_progress',
      label:
          omnichannelFirstMapped<String>(
            json,
            const <String>['label'],
            omnichannelString,
          ) ??
          'Sedang berlangsung',
      count:
          omnichannelFirstMapped<int>(
            json,
            const <String>['count'],
            omnichannelInt,
          ) ??
          0,
      percentage:
          omnichannelFirstMapped<double>(json, const <String>['percentage'], (
            value,
          ) {
            if (value is num) {
              return value.toDouble();
            }

            return double.tryParse(value?.toString() ?? '');
          }) ??
          0,
    );
  }
}
