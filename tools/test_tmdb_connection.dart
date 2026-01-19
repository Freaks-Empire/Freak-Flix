import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://api.themoviedb.org/3/configuration?api_key=90250756a36b99eecb42e86132af35cb');
  print('Testing connection to: $url');
  
  try {
    final client = http.Client();
    final response = await client.get(url);
    print('Status Code: ${response.statusCode}');
    print('Response Body length: ${response.body.length}');
    if (response.statusCode == 200) {
      print('✅ Connection Successful!');
    } else {
      print('❌ FAILED with status: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ EXCEPTION: $e');
    if (e is HandshakeException) {
      print('Detailed Handshake Exception: $e');
    }
  }
}
