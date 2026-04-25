import 'package:pocketbase/pocketbase.dart';

class JsonUtils {
  static Map<String, dynamic> deeplySerializeRecord(RecordModel record) {
    final data = Map<String, dynamic>.from(record.toJson());
    final processedData = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is RecordModel) {
        processedData[key] = deeplySerializeRecord(value);
      } else if (value is List) {
        processedData[key] = value.map((e) {
          if (e is RecordModel) return deeplySerializeRecord(e);
          return e;
        }).toList();
      } else if (value is Map) {
        final subMap = <String, dynamic>{};
        value.forEach((k, v) {
          if (v is RecordModel) {
            subMap[k.toString()] = deeplySerializeRecord(v);
          } else if (v is List) {
            subMap[k.toString()] = v.map((e) {
              if (e is RecordModel) return deeplySerializeRecord(e);
              return e;
            }).toList();
          } else {
            subMap[k.toString()] = v;
          }
        });
        processedData[key] = subMap;
      } else {
        processedData[key] = value;
      }
    });

    return processedData;
  }

  static RecordModel deeplyDeserializeRecord(Map<String, dynamic> json) {
    final record = RecordModel.fromJson(json);

    // Recursively process expand
    if (json.containsKey('expand') && json['expand'] is Map) {
      final Map<String, dynamic> rawExpand = json['expand'];
      final fixedExpand = <String, List<RecordModel>>{};
      
      rawExpand.forEach((key, value) {
        if (value is List) {
          fixedExpand[key] = value.map((e) {
            if (e is Map<String, dynamic>) {
              return deeplyDeserializeRecord(e);
            } else if (e is RecordModel) {
              return e;
            }
            return RecordModel();
          }).toList();
        } else if (value is Map<String, dynamic>) {
          fixedExpand[key] = [deeplyDeserializeRecord(value)];
        }
      });
      
      // Since record.expand might be unmodifiable or we just need to set it,
      // in Pocketbase SDK 0.17+, `expand` is just a Map property.
      record.expand.clear(); // Safe clear if modifiable
      fixedExpand.forEach((k, v) => record.expand[k] = v);
    }

    return record;
  }
}
