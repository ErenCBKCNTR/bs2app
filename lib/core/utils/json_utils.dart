import 'package:pocketbase/pocketbase.dart';

class JsonUtils {
  static Map<String, dynamic> deeplySerializeRecord(RecordModel record) {
    final data = record.toJson();
    if (data['expand'] != null && data['expand'] is Map) {
       final expandMap = data['expand'] as Map<String, dynamic>;
       final newExpand = <String, dynamic>{};
       expandMap.forEach((key, value) {
         if (value is List) {
           newExpand[key] = value.map((e) {
             try {
               if (e is RecordModel) return deeplySerializeRecord(e);
               return e;
             } catch (_) {
               return e;
             }
           }).toList();
         } else if (value is RecordModel) {
           try {
             newExpand[key] = deeplySerializeRecord(value);
           } catch (_) {
             newExpand[key] = value.toJson();
           }
         } else {
           newExpand[key] = value;
         }
       });
       data['expand'] = newExpand;
    }
    return data;
  }
}
