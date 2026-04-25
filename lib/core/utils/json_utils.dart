import 'package:pocketbase/pocketbase.dart';

class JsonUtils {
  static Map<String, dynamic> deeplySerializeRecord(RecordModel record, [Set<String>? serializedIds]) {
    serializedIds ??= {};
    
    if (record.id.isNotEmpty && serializedIds.contains(record.id)) {
       return {'id': record.id, 'collectionId': record.collectionId, '_circular': true};
    }
    
    if (record.id.isNotEmpty) {
      serializedIds.add(record.id);
    }

    final data = Map<String, dynamic>.from(record.toJson());
    final processedData = <String, dynamic>{};

    dynamic processValue(dynamic value) {
      if (value is RecordModel) {
        return deeplySerializeRecord(value, Set.from(serializedIds!));
      } else if (value is List) {
        return value.map((e) => processValue(e)).toList();
      } else if (value is Map) {
        final subMap = <String, dynamic>{};
        value.forEach((k, v) {
          subMap[k.toString()] = processValue(v);
        });
        return subMap;
      }
      return value;
    }

    data.forEach((key, value) {
      processedData[key] = processValue(value);
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
