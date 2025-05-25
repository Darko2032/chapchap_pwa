import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Configuration EmailJS
const SERVICE_ID = "service_s8zfepr";
const TEMPLATE_ID = "template_k398kvi";
const PUBLIC_KEY = "cQhNB0TrFt3QrQQ87";

Future<Map<String, dynamic>> sendEmailWithEmailJS({
  required String serviceId,
  required String templateId,
  required String publicKey,
  required Map<String, dynamic> templateParams,
}) async {
  const String url = 'https://api.emailjs.com/api/v1.0/email/send';
  
  try {
    // Vérifier la connexion Internet d'abord
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw Exception('Pas de connexion Internet');
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Vérifiez votre connexion Internet et réessayez.',
        'details': 'Erreur de connexion: $e',
      };
    }

    // Construction du corps de la requête
    final Map<String, dynamic> body = {
      'service_id': serviceId,
      'template_id': templateId,
      'user_id': publicKey,
      'template_params': templateParams,
    };

    final String bodyEncoded = json.encode(body);

    // Envoi de la requête avec un timeout de 30 secondes
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'origin': 'https://www.chapchap.app',
        'Content-Type': 'application/json',
      },
      body: bodyEncoded,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {
        'success': true,
        'message': 'Email envoyé avec succès!',
        'details': 'Status: ${response.statusCode}',
      };
    } else {
      return {
        'success': false,
        'message': 'Erreur lors de l\'envoi: Code ${response.statusCode}',
        'details': 'Réponse: ${response.body}',
      };
    }
  } catch (e) {
    // Gestion d'erreur détaillée
    return {
      'success': false,
      'message': 'Une erreur s\'est produite',
      'details': 'Exception: ${e.toString()}',
    };
  }
}
