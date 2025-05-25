import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // URLs du serveur - nous essayons plusieurs configurations
  static const List<String> _serverUrls = [
    'https://chapchap-server.onrender.com', // URL de production (PRIORITAIRE)
    'http://192.168.1.2:3000',              // Adresse IP réelle de l'ordinateur local
    'http://10.0.2.2:3000',                 // Pour l'émulateur Android standard
    'http://10.0.3.2:3000',                 // Pour l'émulateur Genymotion
    'http://localhost:3000',                // Pour le web ou le développement local
  ];
  
  // URL de base du serveur - sera déterminée automatiquement
  static String baseUrl = _serverUrls[0]; // Valeur par défaut
  
  // Vérifier si le serveur est disponible en essayant toutes les URLs possibles
  static Future<bool> isServerAvailable() async {
    bool serverReachable = false;
    
    // Essayons toutes les URLs possibles
    for (String url in _serverUrls) {
      try {
        print('Tentative de connexion à $url');
        final response = await http.get(
          Uri.parse(url),
        ).timeout(const Duration(seconds: 2)); // Timeout encore plus court pour chaque essai
        
        if (response.statusCode == 200) {
          print('Connexion réussie à $url');
          baseUrl = url; // Mise à jour de l'URL qui fonctionne
          serverReachable = true;
          break;
        }
      } catch (e) {
        print('$url indisponible: $e');
        // Continuer avec l'URL suivante
      }
    }
    
    return serverReachable;
  }

  // Timeout pour les requêtes HTTP
  static const Duration timeoutDuration = Duration(seconds: 10);

  // Récupérer toutes les commandes
  static Future<List<Map<String, dynamic>>> getCommandes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/commandes'),
      ).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Échec de la récupération des commandes: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la récupération des commandes: $e');
      
      // En cas d'échec, on essaie de récupérer les commandes locales
      return await _getLocalCommandes();
    }
  }

  // Récupérer une commande spécifique
  static Future<Map<String, dynamic>> getCommande(String id) async {
    try {
      final url = '$baseUrl/api/commandes/$id';
      print('Tentative de récupération de la commande à: $url');
      final response = await http.get(
        Uri.parse(url),
      ).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Échec de la récupération de la commande: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la récupération de la commande: $e');
      
      // En cas d'échec, on essaie de récupérer la commande localement
      final commandes = await _getLocalCommandes();
      final commande = commandes.firstWhere(
        (c) => c['id'] == id, 
        orElse: () => {'error': 'Commande non trouvée'}
      );
      return commande;
    }
  }

  // Créer une nouvelle commande
  static Future<Map<String, dynamic>> createCommande(Map<String, dynamic> commande) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/commandes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(commande),
      ).timeout(timeoutDuration);

      if (response.statusCode == 201) {
        final createdCommande = json.decode(response.body);
        
        // Sauvegarder localement aussi
        await _saveLocalCommande(createdCommande);
        
        return createdCommande;
      } else {
        throw Exception('Échec de la création de la commande: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la création de la commande: $e');
      
      // En cas d'échec, on sauvegarde uniquement localement
      commande['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      commande['statut'] = 'En attente (Local)';
      commande['statut_date'] = DateTime.now().toString();
      
      await _saveLocalCommande(commande);
      return commande;
    }
  }

  // Mettre à jour le statut d'une commande
  static Future<Map<String, dynamic>> updateCommandeStatus(String id, String statut) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/commandes/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'statut': statut}),
      ).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final updatedCommande = json.decode(response.body);
        
        // Mettre à jour localement aussi
        await _updateLocalCommande(updatedCommande);
        
        return updatedCommande;
      } else {
        throw Exception('Échec de la mise à jour de la commande: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la mise à jour de la commande: $e');
      throw e;
    }
  }

  // Supprimer une commande
  static Future<void> deleteCommande(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/commandes/$id'),
      ).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        // Supprimer localement aussi
        await _deleteLocalCommande(id);
      } else {
        throw Exception('Échec de la suppression de la commande: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la suppression de la commande: $e');
      
      // On essaie quand même de supprimer localement
      await _deleteLocalCommande(id);
    }
  }

  // Synchroniser les commandes locales avec le serveur
  static Future<void> syncCommandes() async {
    try {
      // Récupérer les commandes locales
      final localCommandes = await _getLocalCommandes();
      
      // Pour chaque commande locale, on essaie de la synchroniser avec le serveur
      for (var commande in localCommandes) {
        // Si la commande a un statut "Local", on essaie de la créer sur le serveur
        if (commande['statut']?.contains('Local') ?? false) {
          try {
            // Nettoyer les données
            final cleanCommande = {...commande};
            cleanCommande.remove('id'); // Laisser le serveur générer un ID
            
            // Créer la commande sur le serveur
            final response = await http.post(
              Uri.parse('$baseUrl/api/commandes'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(cleanCommande),
            ).timeout(timeoutDuration);

            if (response.statusCode == 201) {
              // Supprimer l'ancienne commande locale
              await _deleteLocalCommande(commande['id']);
              
              // Sauvegarder la nouvelle commande avec l'ID du serveur
              await _saveLocalCommande(json.decode(response.body));
            }
          } catch (e) {
            print('Erreur lors de la synchronisation de la commande ${commande['id']}: $e');
            // Continuer avec les autres commandes
          }
        }
      }
    } catch (e) {
      print('Erreur lors de la synchronisation des commandes: $e');
    }
  }

  // Méthodes privées pour la gestion locale des commandes

  // Récupérer les commandes locales
  static Future<List<Map<String, dynamic>>> _getLocalCommandes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> historyJson = prefs.getStringList('commandes_history') ?? [];
      
      return historyJson.map((item) => Map<String, dynamic>.from(json.decode(item))).toList();
    } catch (e) {
      print('Erreur lors de la récupération des commandes locales: $e');
      return [];
    }
  }

  // Sauvegarder une commande localement
  static Future<void> _saveLocalCommande(Map<String, dynamic> commande) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> historyJson = prefs.getStringList('commandes_history') ?? [];
      
      // Ajouter la nouvelle commande
      historyJson.add(json.encode(commande));
      
      await prefs.setStringList('commandes_history', historyJson);
    } catch (e) {
      print('Erreur lors de la sauvegarde locale de la commande: $e');
    }
  }

  // Mettre à jour une commande localement
  static Future<void> _updateLocalCommande(Map<String, dynamic> updatedCommande) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> historyJson = prefs.getStringList('commandes_history') ?? [];
      
      // Convertir en objets
      List<Map<String, dynamic>> commandes = historyJson
          .map((item) => Map<String, dynamic>.from(json.decode(item)))
          .toList();
      
      // Trouver l'index de la commande à mettre à jour
      final index = commandes.indexWhere((c) => c['id'] == updatedCommande['id']);
      
      if (index != -1) {
        // Remplacer la commande
        commandes[index] = updatedCommande;
        
        // Reconvertir en JSON et sauvegarder
        historyJson = commandes.map((c) => json.encode(c)).toList();
        await prefs.setStringList('commandes_history', historyJson);
      }
    } catch (e) {
      print('Erreur lors de la mise à jour locale de la commande: $e');
    }
  }

  // Supprimer une commande localement
  static Future<void> _deleteLocalCommande(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> historyJson = prefs.getStringList('commandes_history') ?? [];
      
      // Convertir en objets
      List<Map<String, dynamic>> commandes = historyJson
          .map((item) => Map<String, dynamic>.from(json.decode(item)))
          .toList();
      
      // Filtrer la commande à supprimer
      commandes.removeWhere((c) => c['id'] == id);
      
      // Reconvertir en JSON et sauvegarder
      historyJson = commandes.map((c) => json.encode(c)).toList();
      await prefs.setStringList('commandes_history', historyJson);
    } catch (e) {
      print('Erreur lors de la suppression locale de la commande: $e');
    }
  }
}
