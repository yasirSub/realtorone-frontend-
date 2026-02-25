import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL for Production VPS
  static const String baseUrl = 'http://api.aanantbishthealing.com/api';

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }
}

