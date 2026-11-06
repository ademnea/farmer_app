import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:farmer_app/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import if not already there

class AuthService {
  static String _token = '';

  static Future<void> logmein(
    BuildContext context,
    String email,
    String password,
  ) async {
    var headers = {'Accept': 'application/json'};
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://196.43.168.57/api/v1/login'),
    );
    request.fields.addAll({'email': email, 'password': password});
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      String responseBody = await response.stream.bytesToString();
      Map<String, dynamic> responseData = jsonDecode(responseBody);
      _token = responseData['token'];

      // Save token to shared preferences for persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token);

      Fluttertoast.showToast(
        msg: "Successful!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      // Navigate to Dashboard instead of navbar
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen(token: _token)),
      );
    } else {
      Fluttertoast.showToast(
        msg: "Wrong Credentials!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  // Add this new logout method
  static Future<bool> logout() async {
    try {
      // Clear the token in memory
      _token = '';

      // Clear the token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');

      // If you have a server-side logout endpoint, call it here
      // Example:
      // final response = await http.post(
      //   Uri.parse('http://196.43.168.57/api/v1/logout'),
      //   headers: {'Authorization': 'Bearer $_token'},
      // );

      // Show success message
      Fluttertoast.showToast(
        msg: "Logged out successfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      return true;
    } catch (e) {
      print('Logout error: $e');

      // Show error message
      Fluttertoast.showToast(
        msg: "Logout failed: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      return false;
    }
  }

  static Future<void> launchSupportUrl() async {
    final Uri url = Uri.parse('http://wa.me/+256755088321');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  static String getToken() {
    return _token;
  }

  // Add this method to check if user is logged in
  static Future<bool> isLoggedIn() async {
    if (_token.isNotEmpty) {
      return true;
    }

    // Check if token exists in shared preferences
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');

    if (savedToken != null && savedToken.isNotEmpty) {
      _token = savedToken; // Restore token
      return true;
    }

    return false;
  }
}

