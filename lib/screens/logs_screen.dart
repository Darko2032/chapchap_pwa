import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({Key? key}) : super(key: key);

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> logsJson = prefs.getStringList('system_logs') ?? [];
      
      final List<Map<String, dynamic>> logs = logsJson
          .map((item) => Map<String, dynamic>.from(json.decode(item)))
          .toList();
      
      // Trier par date (plus récent en premier)
      logs.sort((a, b) {
        final DateTime dateA = DateTime.parse(a['timestamp']);
        final DateTime dateB = DateTime.parse(b['timestamp']);
        return dateB.compareTo(dateA);
      });

      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des logs: $e');
      setState(() {
        _isLoading = false;
        _logs = [
          {
            'type': 'error',
            'message': 'Erreur lors du chargement des logs: $e',
            'timestamp': DateTime.now().toIso8601String(),
            'details': e.toString(),
          }
        ];
      });
    }
  }

  Future<void> _clearLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('system_logs', []);
      
      setState(() {
        _logs = [];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs effacés')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredLogs() {
    if (_filter.isEmpty) {
      return _logs;
    }
    
    final lowerFilter = _filter.toLowerCase();
    return _logs.where((log) {
      final String message = log['message']?.toString().toLowerCase() ?? '';
      final String details = log['details']?.toString().toLowerCase() ?? '';
      return message.contains(lowerFilter) || details.contains(lowerFilter);
    }).toList();
  }

  List<Map<String, dynamic>> _getLogsByType(String type) {
    return _getFilteredLogs().where((log) => log['type'] == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _getFilteredLogs();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs Système'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.view_list),
              text: 'Tous (${filteredLogs.length})',
            ),
            Tab(
              icon: Icon(Icons.info_outline, color: Colors.blue),
              text: 'Info (${_getLogsByType('info').length})',
            ),
            Tab(
              icon: Icon(Icons.error_outline, color: Colors.red),
              text: 'Erreur (${_getLogsByType('error').length})',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Effacer les logs'),
                  content: const Text('Voulez-vous vraiment effacer tous les logs? Cette action est irréversible.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _clearLogs();
                      },
                      child: const Text('Effacer'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _filter = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Filtrer les logs...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _filter.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _filter = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLogList(filteredLogs),
                      _buildLogList(_getLogsByType('info')),
                      _buildLogList(_getLogsByType('error')),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLogList(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return const Center(
        child: Text('Aucun log à afficher'),
      );
    }
    
    return ListView.builder(
      itemCount: logs.length,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemBuilder: (context, index) {
        final log = logs[index];
        final String type = log['type'] ?? 'info';
        final String message = log['message'] ?? 'N/A';
        final String timestamp = _formatDateTime(log['timestamp'] ?? '');
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: type == 'error' ? Colors.red[50] : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: type == 'error' ? Colors.red : Colors.blue,
              child: Icon(
                type == 'error' ? Icons.error : Icons.info,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(message),
            subtitle: Text(timestamp),
            onTap: () {
              _showLogDetails(log);
            },
          ),
        );
      },
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final DateTime dateTime = DateTime.parse(dateTimeString);
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          log['type'] == 'error' ? 'Erreur' : 'Information',
          style: TextStyle(
            color: log['type'] == 'error' ? Colors.red : Colors.blue,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Timestamp', _formatDateTime(log['timestamp'] ?? '')),
              _buildDetailRow('Message', log['message'] ?? 'N/A'),
              if (log.containsKey('details') && log['details'] != null)
                _buildDetailRow('Détails', log['details']),
              if (log.containsKey('source'))
                _buildDetailRow('Source', log['source']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
  
  // Outil d'ajout de log (statique pour être appelé de n'importe où)
  static Future<void> addLog({
    required String message,
    required String type,
    String? details,
    String? source,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> logsJson = prefs.getStringList('system_logs') ?? [];
      
      // Limiter le nombre de logs stockés (garder max 1000)
      if (logsJson.length >= 1000) {
        logsJson = logsJson.sublist(0, 999);
      }
      
      final Map<String, dynamic> log = {
        'type': type,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        if (details != null) 'details': details,
        if (source != null) 'source': source,
      };
      
      logsJson.insert(0, json.encode(log));
      await prefs.setStringList('system_logs', logsJson);
    } catch (e) {
      print('Erreur lors de l\'ajout d\'un log: $e');
    }
  }
}
