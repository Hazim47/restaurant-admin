import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final supabase = Supabase.instance.client;

  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    await supabase.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
    });
  }
}
