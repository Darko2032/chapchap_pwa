import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _commandes = [];
  bool _isLoading = true;
  bool _isRefreshing = false; // Pour l'indicateur d'actualisation silencieuse
  DateTime? _lastRefreshTime; // Pour afficher quand la dernière actualisation a eu lieu
  Timer? _refreshTimer;
  final int _refreshIntervalSeconds = 5; // Actualisation toutes les 5 secondes

  @override
  void initState() {
    super.initState();
    _loadCommandes();
    
    // Configurer un timer pour l'actualisation automatique
    _refreshTimer = Timer.periodic(Duration(seconds: _refreshIntervalSeconds), (timer) {
      if (mounted) {
        _loadCommandes(showLoadingIndicator: false);
      }
    });
  }
  
  @override
  void dispose() {
    // Annuler le timer lorsque l'écran est détruit
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCommandes({bool showLoadingIndicator = true}) async {
    // Si une actualisation silencieuse est demandée, mettre à jour l'indicateur d'actualisation
    if (!showLoadingIndicator && mounted) {
      setState(() {
        _isRefreshing = true;
      });
    }
    
    // Vérifier si le serveur est disponible au début 
    bool serverAvailable = false;
    try {
      serverAvailable = await ApiService.isServerAvailable();
    } catch (e) {
      print('Erreur lors de la vérification du serveur: $e');
    }
    
    if (!mounted) return;
    
    // Afficher l'indicateur de chargement uniquement si demandé
    if (showLoadingIndicator) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // 1. Essayer de récupérer les commandes depuis le serveur si disponible
      List<Map<String, dynamic>> commandesServeur = [];
      if (serverAvailable) {
        try {
          commandesServeur = await ApiService.getCommandes();
          if (commandesServeur.isNotEmpty && mounted) {
            // Trier les commandes du serveur par date (plus récent en premier)
            commandesServeur.sort((a, b) {
              final DateTime dateA = DateTime.parse(a['date'] ?? a['statut_date'] ?? DateTime.now().toString());
              final DateTime dateB = DateTime.parse(b['date'] ?? b['statut_date'] ?? DateTime.now().toString());
              return dateB.compareTo(dateA);
            });
            
            // Si on a des commandes du serveur, on les utilise
            setState(() {
              _commandes = commandesServeur;
              _isLoading = false;
            });
            return; // On sort de la fonction
          }
        } catch (serverError) {
          print('Impossible de récupérer les commandes du serveur: $serverError');
          // Si échec, on continue avec les données locales
        }
      } else {
        print('Serveur non disponible, utilisation des données locales uniquement');
      }
      
      // 2. Si le serveur n'est pas disponible, on utilise les données locales
      final prefs = await SharedPreferences.getInstance();
      final List<String> historyJson = prefs.getStringList('commandes_history') ?? [];
      
      final List<Map<String, dynamic>> commandes = historyJson
          .map((item) => Map<String, dynamic>.from(json.decode(item)))
          .toList();
      
      // Trier par date (plus récent en premier)
      commandes.sort((a, b) {
        final DateTime dateA = DateTime.parse(a['date']);
        final DateTime dateB = DateTime.parse(b['date']);
        return dateB.compareTo(dateA);
      });

      if (!mounted) return;
      
      setState(() {
        _commandes = commandes;
        _isLoading = false;
        _isRefreshing = false;
        _lastRefreshTime = DateTime.now();
      });
    } catch (e) {
      print('Erreur lors du chargement des commandes: $e');
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        // On met quand même à jour l'heure de dernière tentative d'actualisation
        _lastRefreshTime = DateTime.now();
      });
    }
  }

  Future<void> _deleteCommande(String id) async {
    bool serverAvailable = false;
    try {
      serverAvailable = await ApiService.isServerAvailable();
    } catch (e) {
      print('Erreur lors de la vérification du serveur: $e');
    }

    try {
      // 1. Essayer de supprimer la commande sur le serveur si disponible
      if (serverAvailable) {
        try {
          await ApiService.deleteCommande(id);
          // Succès avec le serveur
        } catch (serverError) {
          print('Impossible de supprimer la commande sur le serveur: $serverError');
        }
      }
      
      // 2. Supprimer en local dans tous les cas
      final prefs = await SharedPreferences.getInstance();
      final List<String> historyJson = prefs.getStringList('commandes_history') ?? [];
      
      final List<String> updatedHistory = historyJson.where((item) {
        final commande = Map<String, dynamic>.from(json.decode(item));
        return commande['id'] != id;
      }).toList();
      
      await prefs.setStringList('commandes_history', updatedHistory);
      
      // Vérifier si le widget est toujours monté
      if (!mounted) return;
      
      setState(() {
        _commandes.removeWhere((commande) => commande['id'] == id);
      });
    } catch (e) {
      print('Erreur lors de la suppression de la commande: $e');
    }
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final DateTime dateTime = DateTime.parse(dateTimeString);
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des commandes'),
        actions: [
          // Afficher un indicateur d'actualisation quand l'actualisation silencieuse est en cours
          if (_isRefreshing)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadCommandes(showLoadingIndicator: true),
            tooltip: 'Actualiser manuellement',
          ),
        ],
      ),
      body: Column(
        children: [
          // Indicateur de dernière mise à jour
          if (_lastRefreshTime != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dernière mise à jour: ${_formatDateTime(_lastRefreshTime.toString())}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text(
                    'Actualisation auto: ${_refreshIntervalSeconds}s',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _commandes.isEmpty
                    ? Center(
                        child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune commande dans l\'historique',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Faire une commande'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _commandes.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final commande = _commandes[index];
                    final String reseau = commande['reseau'] ?? 'N/A';
                    final String type = commande['type'] ?? 'N/A';
                    final String numero = commande['numero'] ?? 'N/A';
                    final String montant = commande['total'] ?? 'N/A';
                    final String date = _formatDateTime(commande['date'] ?? '');
                    final String details = type == 'Forfait' 
                        ? commande['forfait'] ?? 'N/A' 
                        : '$montant FCFA';
                    final String id = commande['id'] ?? '';
                    final String statut = commande['statut'] ?? 'En attente';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: InkWell(
                        onTap: () {
                          _showCommandeDetails(commande);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _getOperatorColor(reseau),
                                    child: Text(
                                      reseau.substring(0, 1),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$type - $details',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('$numero - $date'),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(statut),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            statut,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Supprimer'),
                                          content: const Text('Voulez-vous supprimer cette commande de l\'historique ?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Annuler'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                _deleteCommande(id);
                                              },
                                              child: const Text('Supprimer'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ),
          ],
        ),
    );
  }

  Color _getOperatorColor(String operateur) {
    switch (operateur.toLowerCase()) {
      case 'orange':
        return Colors.orange;
      case 'mtn':
        return Colors.yellow[800] ?? Colors.yellow;
      case 'moov':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  Color _getStatusColor(String statut) {
    switch (statut.toLowerCase()) {
      case 'validée':
      case 'validee':
      case 'effectuée':
      case 'effectuee':
        return Colors.green;
      case 'en attente':
        return Colors.orange;
      case 'en cours':
        return Colors.blue;
      case 'annulée':
      case 'annulee':
        return Colors.red;
      case 'refusée':
      case 'refusee':
        return Colors.red[700] ?? Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showCommandeDetails(Map<String, dynamic> commande) async {
    // Vérifier si le widget est toujours monté avant de continuer
    if (!mounted) return;
    
    String reseau = commande['reseau'] ?? 'N/A';
    String type = commande['type'] ?? 'N/A';
    String numero = commande['numero'] ?? 'N/A';
    String montant = commande['montant'] ?? 'N/A';
    String frais = commande['frais'] ?? '0';
    String total = commande['total'] ?? 'N/A';
    String numeroTransaction = commande['numero_transaction'] ?? 'N/A';
    String date = _formatDateTime(commande['date'] ?? '');
    String forfait = commande['forfait'] ?? 'N/A';
    String statut = commande['statut'] ?? 'En attente';
    String statutDate = _formatDateTime(commande['statut_date'] ?? commande['date'] ?? '');
    final String id = commande['id'] ?? '';
    
    // Vérifier si le serveur est disponible
    bool serverAvailable = false;
    try {
      serverAvailable = await ApiService.isServerAvailable();
    } catch (e) {
      print('Erreur lors de la vérification du serveur: $e');
    }
    
    // Essayer de récupérer les dernières informations du serveur si disponible
    if (id.isNotEmpty && serverAvailable) {
      try {
        final updatedCommande = await ApiService.getCommande(id);
        if (updatedCommande['id'] != null) {
          // Mettre à jour les détails avec les informations du serveur
          statut = updatedCommande['statut'] ?? statut;
          statutDate = _formatDateTime(updatedCommande['statut_date'] ?? statutDate);
        }
      } catch (e) {
        print('Impossible de récupérer les détails à jour de la commande: $e');
        // Continuer avec les informations locales
      }
    }
    
    // Vérifier à nouveau si le widget est monté avant d'afficher la boîte de dialogue
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.all(16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Détails de la commande'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getStatusColor(statut),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statut,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Date', date),
              _buildDetailItem('Opérateur', reseau),
              _buildDetailItem('Type', type),
              _buildDetailItem('Numéro', numero),
              if (type == 'Forfait') 
                _buildDetailItem('Forfait', forfait)
              else 
                _buildDetailItem('Montant', '$montant FCFA'),
              _buildDetailItem('Frais de service', '$frais FCFA'),
              const Divider(),
              _buildDetailItem('Total', '$total FCFA', isBold: true),
              _buildDetailItem('Numéro de transaction', numeroTransaction),
              const Divider(),
              _buildDetailItem('Statut', statut),
              _buildDetailItem('Dernière mise à jour', statutDate),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? Theme.of(context).colorScheme.primary : null,
                fontSize: isBold ? 16 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
