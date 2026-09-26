import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Connected directly to the VPS Public API
  static const String baseUrl = 'https://ultraflow.boxpower.store';

  /**
   * Performs client authentication and stores JWT token in SharedPreferences
   */
  static Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String token = data['token'];

        // Persist token locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('username', data['user']['username']);

        return data;
      }
      return null;
    } catch (e) {
      print('ApiService Login error: $e');
      return null;
    }
  }

  /**
   * Retrieves list of available Flow workspaces assigned to the authenticated user
   */
  static Future<List<dynamic>> fetchAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/accounts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('ApiService fetchAccounts error: $e');
      return [];
    }
  }

  /**
   * Fetches decrypted session cookies for a specific Flow profile
   */
  static Future<Map<String, dynamic>?> fetchSessionCookies(String accountId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/accounts/$accountId/session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('ApiService fetchSessionCookies error: $e');
      return null;
    }
  }

  /**
   * Performs user logout, clearing SharedPreferences token data
   */
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('username');
  }

  /**
   * Retrieves current logged in username
   */
  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username') ?? 'Cliente';
  }
}
