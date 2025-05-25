import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/forfait_model.dart';
import '../screens/logs_screen.dart';

class LocalStorage {
  // Clés de stockage
  static const String _commandesKey = 'commandes_history';
  static const String _forfaitsKey = 'forfaitsData';
  static const String _logsKey = 'system_logs';

  // Méthodes pour les commandes
  static Future<List<Commande>> getCommandes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> historyJson = prefs.getStringList(_commandesKey) ?? [];
      
      final List<Commande> commandes = historyJson
          .map((item) => Commande.fromJson(json.decode(item)))
          .toList();
      
      // Trier par date (plus récent d'abord)
      commandes.sort((a, b) => b.date.compareTo(a.date));
      
      return commandes;
    } catch (e) {
      LogsScreen.addLog(
        message: 'Erreur lors du chargement des commandes',
        type: 'error',
        details: e.toString(),
        source: 'LocalStorage.getCommandes',
      );
      return [];
    }
  }

  static Future<bool> saveCommande(Commande commande) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> historyJson = prefs.getStringList(_commandesKey) ?? [];
      
      historyJson.add(json.encode(commande.toJson()));
      
      final success = await prefs.setStringList(_commandesKey, historyJson);
      
      if (success) {
        LogsScreen.addLog(
          message: 'Nouvelle commande enregistrée',
          type: 'info',
          details: 'ID: ${commande.id}, Réseau: ${commande.reseau}, Montant: ${commande.total}',
          source: 'LocalStorage.saveCommande',
        );
      }
      
      return success;
    } catch (e) {
      LogsScreen.addLog(
        message: 'Erreur lors de l\'enregistrement d\'une commande',
        type: 'error',
        details: e.toString(),
        source: 'LocalStorage.saveCommande',
      );
      return false;
    }
  }

  static Future<bool> deleteCommande(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> historyJson = prefs.getStringList(_commandesKey) ?? [];
      
      historyJson = historyJson.where((item) {
        final commande = Commande.fromJson(json.decode(item));
        return commande.id != id;
      }).toList();
      
      final success = await prefs.setStringList(_commandesKey, historyJson);
      
      if (success) {
        LogsScreen.addLog(
          message: 'Commande supprimée',
          type: 'info',
          details: 'ID: $id',
          source: 'LocalStorage.deleteCommande',
        );
      }
      
      return success;
    } catch (e) {
      LogsScreen.addLog(
        message: 'Erreur lors de la suppression d\'une commande',
        type: 'error',
        details: e.toString(),
        source: 'LocalStorage.deleteCommande',
      );
      return false;
    }
  }

  // Méthodes pour les forfaits
  static Future<Map<String, dynamic>> getForfaitsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_forfaitsKey);
      
      if (cachedData != null) {
        return json.decode(cachedData);
      }
      
      return {};
    } catch (e) {
      LogsScreen.addLog(
        message: 'Erreur lors du chargement des forfaits',
        type: 'error',
        details: e.toString(),
        source: 'LocalStorage.getForfaitsData',
      );
      return {};
    }
  }

  static Future<bool> saveForfaitsData(String jsonString) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Vérifions que c'est un JSON valide
      json.decode(jsonString);
      
      final success = await prefs.setString(_forfaitsKey, jsonString);
      
      if (success) {
        LogsScreen.addLog(
          message: 'Données forfaits mises à jour',
          type: 'info',
          source: 'LocalStorage.saveForfaitsData',
        );
      }
      
      return success;
    } catch (e) {
      LogsScreen.addLog(
        message: 'Erreur lors de l\'enregistrement des forfaits',
        type: 'error',
        details: e.toString(),
        source: 'LocalStorage.saveForfaitsData',
      );
      return false;
    }
  }

  // Utilitaire pour vider le cache (pour le débogage)
  static Future<bool> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Ne supprime pas les logs mais tout le reste
      final List<String> logsJson = prefs.getStringList(_logsKey) ?? [];
      await prefs.clear();
      await prefs.setStringList(_logsKey, logsJson);
      
      LogsScreen.addLog(
        message: 'Cache effacé',
        type: 'info',
        source: 'LocalStorage.clearCache',
      );
      
      return true;
    } catch (e) {
      LogsScreen.addLog(
        message: 'Erreur lors de l\'effacement du cache',
        type: 'error',
        details: e.toString(),
        source: 'LocalStorage.clearCache',
      );
      return false;
    }
  }
}
