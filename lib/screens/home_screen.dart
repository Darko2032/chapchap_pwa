import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../email_test.dart';
import '../services/api_service.dart';
import 'logs_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final ValueNotifier<bool> _formFilledNotifier = ValueNotifier(false);
  String _numeroTransaction = '';
  
  // Easter egg pour accès admin aux logs
  int _titleTapCount = 0;
  final int _requiredTapsForAdmin = 10;
  DateTime? _lastTapTime;

  String? _selectedNetwork;  // Opérateur sélectionné (Orange, MTN, Moov)
  String? _selectedType;     // Type de recharge (Unités ou Forfait)
  Map<String, dynamic>? _selectedForfait; // Forfait sélectionné
  String _phone = '';        // Numéro à recharger
  String _amount = '';       // Montant si type=Unités
  
  // Forfaits disponibles par catégories
  Map<String, List<Map<String, dynamic>>> _forfaitsParCategorie = {};
  Map<String, dynamic> _forfaitsData = {};
  bool _isLoading = true;
  bool _forfaitsInitialized = false;
  
  // Gestion de l'interface accordéon
  String? _expandedCategory;
  
  // Informations de paiement pour les opérateurs
  final Map<String, String> paymentNumbers = {
    'Orange Money': '0716007383',
    'MTN Mobile Money': '0586468167',
    'Moov Money': '0142828966',
    'Wave': 'https://pay.wave.com/m/M_ci_3uPY5tahPf8f/c/ci/',
  };

  @override
  void initState() {
    super.initState();
    _loadForfaitsData();
  }

  // Charge les forfaits depuis le fichier JSON local ou le cache
  Future<void> _loadForfaitsData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Vérifier si les données sont en cache
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('forfaitsData');
      
      if (cachedData != null) {
        setState(() {
          _forfaitsData = json.decode(cachedData);
          _isLoading = false;
          _forfaitsInitialized = true;
        });
      } else {
        // Charger depuis le fichier local à la racine du projet
        String jsonString = await rootBundle.loadString('forfaits.json');
        final data = json.decode(jsonString);
        
        // Sauvegarder dans le cache
        await prefs.setString('forfaitsData', jsonString);
        
        setState(() {
          _forfaitsData = data;
          _isLoading = false;
          _forfaitsInitialized = true;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des forfaits: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateForfaitsParCategorie() {
    if (_selectedNetwork != null && _forfaitsData.containsKey(_selectedNetwork!.toLowerCase())) {
      Map<String, dynamic> networkData = _forfaitsData[_selectedNetwork!.toLowerCase()];
      Map<String, List<Map<String, dynamic>>> result = {};
      
      networkData.forEach((key, value) {
        if (value is List) {
          result[key] = List<Map<String, dynamic>>.from(
            value.map((item) => Map<String, dynamic>.from(item))
          );
        }
      });
      
      setState(() {
        _forfaitsParCategorie = result;
      });
    } else {
      setState(() {
        _forfaitsParCategorie = {};
      });
    }
  }

  void _resetForm() {
    setState(() {
      _selectedNetwork = null;
      _selectedType = null;
      _selectedForfait = null;
      _phone = '';
      _amount = '';
      _expandedCategory = null;
    });
    _formKey.currentState?.reset();
    _formFilledNotifier.value = false;
  }

  // Calcule le montant total en tenant compte des frais
  double _calculateTotalAmount() {
    double baseAmount = 0;
    double fees = 0;
    
    if (_selectedType == 'Unités') {
      baseAmount = double.tryParse(_amount) ?? 0;
    } else if (_selectedType == 'Forfait' && _selectedForfait != null) {
      baseAmount = double.tryParse(_selectedForfait!['prix'].toString()) ?? 0;
    }
    
    // Règles de calcul des frais sans trous dans les plages
    if (baseAmount >= 100 && baseAmount <= 500) {
      fees = baseAmount * 0.1; // 10% du montant de base
    } else if (baseAmount >= 501 && baseAmount <= 599) {
      // Plage 501-599 manquante, utilisons les frais de la plage précédente (10%)
      fees = 50; // Minimum 50F pour cette plage
    } else if (baseAmount >= 600 && baseAmount <= 999) {
      fees = 50; // Inclure 901-999 dans cette plage
    } else if (baseAmount >= 1000 && baseAmount <= 4999) {
      fees = 100;
    } else if (baseAmount >= 5000 && baseAmount <= 10000) {
      fees = 150;
    } else if (baseAmount > 10000) {
      fees = 200;
    }
    
    return baseAmount + fees;
  }

  Future<Map<String, dynamic>> _directEmailJSSend({
    required String serviceId,
    required String templateId,
    required String publicKey,
    required Map<String, dynamic> templateParams,
  }) async {
    return sendEmailWithEmailJS(
      serviceId: serviceId,
      templateId: templateId,
      publicKey: publicKey,
      templateParams: templateParams,
    );
  }

  void _showPaymentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16, right: 16, top: 20,
            ),
            child: LimitedBox(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // En-tête et détails de la commande
                    Text(
                      'Finaliser la commande',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Résumé de la commande
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Résumé de la commande', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildOrderDetail('Opérateur', _selectedNetwork ?? ''),
                            _buildOrderDetail('Type', _selectedType ?? ''),
                            _buildOrderDetail('Numéro', _phone),
                            if (_selectedType == 'Unités')
                              _buildOrderDetail('Montant', '$_amount FCFA')
                            else if (_selectedForfait != null)
                              _buildOrderDetail('Forfait', 
                                '${_selectedForfait!['description']} - ${_selectedForfait!['validite']} - ${_selectedForfait!['prix']} FCFA'),
                            const Divider(),
                            _buildOrderDetail('Montant de base', '${_selectedType == 'Unités' ? _amount : _selectedForfait!['prix']} FCFA'),
                            _buildOrderDetail('Frais de service', '${_calculateTotalAmount() - (_selectedType == 'Unités' ? double.parse(_amount) : double.parse(_selectedForfait!['prix'].toString()))} FCFA'),
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(color: Theme.of(context).colorScheme.primary),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('TOTAL À PAYER', 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '${_calculateTotalAmount().toStringAsFixed(0)} FCFA',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Liste des options de paiement
                    _buildPaymentInstructions(),
                    const SizedBox(height: 16),
                    
                    // Formulaire pour le numéro de transaction
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Numéro pour paiement',
                        hintText: 'Numéro ayant effectué le paiement',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: (value) {
                        setModalState(() {
                          _numeroTransaction = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Bouton de soumission
                    ElevatedButton(
                      onPressed: _numeroTransaction.length >= 8 
                          ? () => _submitPayment(context)
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Confirmer la transaction'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentInstructions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Méthodes de paiement',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            for (var entry in paymentNumbers.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: entry.key == 'Wave' 
                  ? Container(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _launchWavePayment(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DC8FF), // Couleur Wave
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 3,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'PAYER AVEC WAVE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text(
                          entry.value,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Veuillez effectuer votre paiement à l\'un des numéros ci-dessus, puis entrez le numéro utilisé pour le paiement ci-dessous.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _launchWavePayment() async {
    final url = paymentNumbers['Wave']!;
    // Utilise le package url_launcher pour ouvrir l'URL dans le navigateur externe
    try {
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      )) {
        throw 'Impossible d\'ouvrir $url';
      }
    } catch (e) {
      // Afficher un dialogue d'erreur
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erreur'),
          content: Text('Impossible d\'ouvrir Wave. $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildOrderDetail(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPayment(BuildContext context) async {
    // Afficher indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Préparer les détails de la commande
      final String formattedDate = DateTime.now().toString().substring(0, 16);
      final String forfaitText = _selectedType == 'Forfait' 
                               ? '${_selectedForfait!['description']} - ${_selectedForfait!['validite']}' 
                               : 'N/A';
      final String montantBase = _selectedType == 'Unités' ? _amount : _selectedForfait!['prix'].toString();
      final String fraisService = (_calculateTotalAmount() - double.parse(montantBase)).toStringAsFixed(0);
                               
      // Préparer les données de la commande pour l'API et l'historique
      final Map<String, dynamic> commandeDetails = {
        // Variables standard pour l'historique
        'date': formattedDate,
        'reseau': _selectedNetwork,     // Clé utilisée dans l'historique
        'type': _selectedType,
        'numero': _phone,               // Clé utilisée dans l'historique
        'montant': montantBase,
        'frais': fraisService,
        'forfait': forfaitText,
        'numero_transaction': _numeroTransaction,
        'total': _calculateTotalAmount().toStringAsFixed(0),
        'statut': 'En attente',        // Statut initial de la commande
        'statut_date': formattedDate,   // Date du dernier changement de statut
        
        // Variables pour EmailJS (doublons avec les bons noms)
        'network': _selectedNetwork,    // Pour le template EmailJS
        'phone': _phone,                // Pour le template EmailJS
      };

      // 1. Envoyer la commande au serveur
      bool serverSuccess = false;
      
      try {
        // Importer ApiService dans les imports en haut du fichier
        // Envoyer la commande au serveur
        final serverResult = await ApiService.createCommande(commandeDetails);
        
        // Mise à jour des détails avec les données du serveur
        if (serverResult['id'] != null) {
          commandeDetails['id'] = serverResult['id'];
          commandeDetails['statut'] = serverResult['statut'] ?? 'En attente';
          serverSuccess = true;
        }
      } catch (serverError) {
        print('Erreur lors de la communication avec le serveur: $serverError');
        // Continuer avec l'envoi d'email même si le serveur est indisponible
      }

      // 2. Envoyer l'email via EmailJS
      final result = await _directEmailJSSend(
        serviceId: SERVICE_ID,
        templateId: TEMPLATE_ID,
        publicKey: PUBLIC_KEY,
        templateParams: commandeDetails,
      );

      // Fermer la boîte de dialogue de chargement
      Navigator.pop(context);

      if (result['success']) {
        // Fermer la modal de paiement
        Navigator.pop(context);
        
        // Sauvegarder dans l'historique local si pas déjà fait par le service API
        if (!serverSuccess) {
          // Générer un ID unique local
          commandeDetails['id'] = DateTime.now().millisecondsSinceEpoch.toString();
          _saveToHistory(commandeDetails);
        }
        
        // Afficher animation de confirmation
        showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierLabel: "Confirmation",
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, __, ___) {
            return SuccessAnimationDialog(
              commandeDetails: commandeDetails,
              onClose: () {
                // Utiliser une référence au BuildContext qui sera capturée au moment de la création du dialogue
                // et non au moment de l'exécution du callback
                _closeDialogsAndResetForm(context);
              },
            );
          },
          transitionBuilder: (_, animation, __, child) {
            return ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        );
      } else {
        // Afficher erreur
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Erreur'),
              content: Text('Une erreur s\'est produite: ${result['message']}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // Fermer la boîte de dialogue de chargement
      Navigator.pop(context);
      
      // Afficher erreur
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Erreur'),
            content: Text('Une erreur inattendue s\'est produite: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _saveToHistory(Map<String, dynamic> commandeDetails) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> historyJson = prefs.getStringList('commandes_history') ?? [];
      
      // Ajouter l'ID unique à la commande
      commandeDetails['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      
      historyJson.add(json.encode(commandeDetails));
      await prefs.setStringList('commandes_history', historyJson);
    } catch (e) {
      print('Erreur lors de l\'enregistrement dans l\'historique: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            // Easter egg pour accéder aux logs (admin)
            final now = DateTime.now();
            if (_lastTapTime != null && 
                now.difference(_lastTapTime!).inSeconds < 3) {
              _titleTapCount++;
              if (_titleTapCount >= _requiredTapsForAdmin) {
                _titleTapCount = 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LogsScreen()),
                );
              }
            } else {
              _titleTapCount = 1;
            }
            _lastTapTime = now;
          },
          child: const Text('CHAP-CHAP'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              onChanged: () {
                _formKey.currentState?.validate();
                _updateFormStatus();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sélection de l'opérateur
                    _buildOperatorSelection(),
                    const SizedBox(height: 16),
                    
                    // Sélection du type (Unités ou Forfait)
                    if (_selectedNetwork != null) ...[
                      _buildTypeSelection(),
                      const SizedBox(height: 16),
                    ],
                    
                    // Numéro à recharger
                    if (_selectedType != null) ...[
                      _buildPhoneInput(),
                      const SizedBox(height: 16),
                    ],
                    
                    // Sélection du montant ou forfait
                    if (_selectedType != null && _phone.isNotEmpty) ...[
                      if (_selectedType == 'Unités')
                        _buildAmountInput()
                      else if (_selectedType == 'Forfait')
                        _buildForfaitSelection(),
                      const SizedBox(height: 24),
                    ],
                    
                    // Bouton de paiement
                    ValueListenableBuilder<bool>(
                      valueListenable: _formFilledNotifier,
                      builder: (context, isFormFilled, child) {
                        bool canProceed = isFormFilled && 
                            (_selectedType == 'Unités' ? _amount.isNotEmpty : _selectedForfait != null);
                        
                        return ElevatedButton(
                          onPressed: canProceed ? _showPaymentModal : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Procéder au paiement',
                            style: TextStyle(fontSize: 16),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOperatorSelection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sélectionnez un opérateur',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOperatorOption('Orange', 'assets/images/orange.png'),
                _buildOperatorOption('MTN', 'assets/images/mtn.png'),
                _buildOperatorOption('Moov', 'assets/images/moov.png'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorOption(String name, String imagePath) {
    final isSelected = _selectedNetwork == name;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedNetwork = name;
          _selectedType = null;
          _selectedForfait = null;
          _updateForfaitsParCategorie();
        });
        _updateFormStatus();
      },
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(name),
        ],
      ),
    );
  }

  Widget _buildTypeSelection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Type de recharge',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTypeOption('Unités', Icons.toll),
                _buildTypeOption('Forfait', Icons.all_inclusive),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(String type, IconData icon) {
    final isSelected = _selectedType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _selectedForfait = null;
        });
        _updateFormStatus();
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 8),
            Text(
              type,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Numéro à recharger',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'Entrez le numéro',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un numéro';
                }
                if (value.length != 10) {
                  return 'Le numéro doit contenir exactement 10 chiffres';
                }
                
                // Vérification des préfixes selon l'opérateur
                if (_selectedNetwork == 'Orange' && !value.startsWith('07')) {
                  return 'Un numéro Orange doit commencer par 07';
                }
                if (_selectedNetwork == 'Moov' && !value.startsWith('01')) {
                  return 'Un numéro Moov doit commencer par 01';
                }
                if (_selectedNetwork == 'MTN' && !value.startsWith('05')) {
                  return 'Un numéro MTN doit commencer par 05';
                }
                
                // Assurez-vous que seuls des chiffres sont saisis
                if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                  return 'Le numéro ne doit contenir que des chiffres';
                }
                
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _phone = value;
                });
                _updateFormStatus();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Montant',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'Entrez le montant en FCFA',
                prefixIcon: Icon(Icons.monetization_on),
                suffixText: 'FCFA',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un montant';
                }
                final amount = int.tryParse(value);
                if (amount == null) {
                  return 'Montant invalide';
                }
                if (amount < 100) {
                  return 'Le montant minimum est de 100 FCFA';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _amount = value;
                });
                _formKey.currentState?.validate();
                _updateFormStatus();
              },
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Montants rapides',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickAmountChip('500'),
                      _buildQuickAmountChip('1000'),
                      _buildQuickAmountChip('2000'),
                      _buildQuickAmountChip('5000'),
                      _buildQuickAmountChip('10000'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountChip(String amount) {
    final bool isSelected = _amount == amount;
    
    return Container(
      margin: const EdgeInsets.only(right: 8.0, bottom: 4.0),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _amount = amount;
          });
          _formKey.currentState?.validate();
          _updateFormStatus();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected 
              ? Theme.of(context).colorScheme.primary 
              : Colors.grey[100],
          foregroundColor: isSelected 
              ? Colors.white 
              : Colors.black87,
          elevation: isSelected ? 2 : 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary 
                  : Colors.grey.shade300,
              width: 1,
            ),
          ),
        ),
        child: Text(
          '$amount FCFA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildForfaitSelection() {
    if (_forfaitsParCategorie.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('Aucun forfait disponible pour cet opérateur.'),
          ),
        ),
      );
    }
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sélectionnez un forfait',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...(_forfaitsParCategorie.entries.map((entry) {
              final category = entry.key;
              final forfaits = entry.value;
              
              return Column(
                children: [
                  // En-tête de catégorie (accordéon)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _expandedCategory = _expandedCategory == category ? null : category;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatCategoryName(category),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Icon(
                            _expandedCategory == category 
                                ? Icons.keyboard_arrow_up 
                                : Icons.keyboard_arrow_down,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Liste des forfaits de cette catégorie (si développée)
                  if (_expandedCategory == category)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: forfaits.length,
                      itemBuilder: (context, index) {
                        final forfait = forfaits[index];
                        final isSelected = _selectedForfait == forfait;
                        
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedForfait = forfait;
                            });
                            _updateFormStatus();
                          },
                          child: Card(
                            elevation: isSelected ? 2 : 0,
                            color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Radio<Map<String, dynamic>>(
                                    value: forfait,
                                    groupValue: _selectedForfait,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedForfait = value;
                                      });
                                      _updateFormStatus();
                                    },
                                    activeColor: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${forfait['description']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('${forfait['validite']}'),
                                            Text(
                                              '${forfait['prix']} FCFA',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                  const SizedBox(height: 8),
                ],
              );
            }).toList()),
          ],
        ),
      ),
    );
  }

  String _formatCategoryName(String name) {
    // Convertit snake_case en format lisible (ex: "izy_heures_plus" -> "Izy Heures Plus")
    return name
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // Vérifie si le format du numéro est valide pour l'opérateur sélectionné
  bool _validatePhoneFormat() {
    if (_phone.isEmpty || _phone.length != 10 || _selectedNetwork == null) return false;
    
    if (!RegExp(r'^[0-9]+$').hasMatch(_phone)) return false;
    
    if (_selectedNetwork == 'Orange' && !_phone.startsWith('07')) return false;
    if (_selectedNetwork == 'Moov' && !_phone.startsWith('01')) return false;
    if (_selectedNetwork == 'MTN' && !_phone.startsWith('05')) return false;
    
    return true;
  }
  
  // Met à jour l'état complet du formulaire
  void _updateFormStatus() {
    final isPhoneValid = _validatePhoneFormat();
    final isAmountValid = _selectedType == 'Unités' ? (_amount.isNotEmpty && double.tryParse(_amount) != null && double.parse(_amount) >= 100) : true;
    final isForfaitValid = _selectedType == 'Forfait' ? _selectedForfait != null : true;
    
    _formFilledNotifier.value = isPhoneValid && 
                               _selectedNetwork != null && 
                               _selectedType != null && 
                               (isAmountValid || isForfaitValid);
  }
  
  // Méthode sécurisée pour fermer les dialogues et réinitialiser le formulaire
  void _closeDialogsAndResetForm(BuildContext context) {
    try {
      // Utiliser Navigator.pop() directement qui est plus robuste
      // Fermer jusqu'à deux niveaux de dialogues s'ils existent
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Erreur lors de la fermeture des dialogues: $e');
    }
    
    // Réinitialiser le formulaire après un court délai pour s'assurer que les dialogues sont fermés
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _resetForm();
      }
    });
  }
  
  @override
  bool get wantKeepAlive => true;
}

// Widget d'animation de confirmation pour les demandes
class SuccessAnimationDialog extends StatefulWidget {
  final Map<String, dynamic> commandeDetails;
  final VoidCallback onClose;

  const SuccessAnimationDialog({
    Key? key,
    required this.commandeDetails,
    required this.onClose,
  }) : super(key: key);

  @override
  State<SuccessAnimationDialog> createState() => _SuccessAnimationDialogState();
}

class _SuccessAnimationDialogState extends State<SuccessAnimationDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _checkAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.elasticOut),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.elasticOut),
      ),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );
    
    _controller.forward().then((_) {
      // Afficher les détails après l'animation
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _showDetails = true;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10.0,
              offset: Offset(0.0, 10.0),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animation du cercle avec coche
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(60, 60),
                        painter: CheckmarkPainter(
                          animation: _checkAnimation.value,
                          color: Theme.of(context).colorScheme.primary,
                          strokeWidth: 4.0,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // Titre avec animation
            AnimatedOpacity(
              opacity: _opacityAnimation.value,
              duration: const Duration(milliseconds: 300),
              child: Text(
                'Demande reçue !',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Animation pour les détails
            AnimatedOpacity(
              opacity: _showDetails ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // Badge de statut
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.commandeDetails['statut'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Détails de la commande
                  _buildDetailItem('Réseau', widget.commandeDetails['reseau']),
                  _buildDetailItem('Type', widget.commandeDetails['type']),
                  _buildDetailItem('Numéro', widget.commandeDetails['numero']),
                  widget.commandeDetails['type'] == 'Unités'
                      ? _buildDetailItem('Montant', '${widget.commandeDetails['montant']} FCFA')
                      : _buildDetailItem('Forfait', widget.commandeDetails['forfait']),
                  _buildDetailItem('Total', '${widget.commandeDetails['total']} FCFA', isTotal: true),
                  const SizedBox(height: 15),
                  const Text(
                    'Votre demande sera traitée dans les plus brefs délais. Vous pouvez suivre son état dans l\'historique.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Bouton de fermeture
            AnimatedOpacity(
              opacity: _showDetails ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: ElevatedButton(
                onPressed: () {
                  // Fermer ce dialogue d'abord
                  Navigator.of(context).pop();
                  // Puis appeler la fonction onClose du parent après un court délai
                  // pour s'assurer que ce dialogue est complètement fermé
                  Future.delayed(const Duration(milliseconds: 50), () {
                    widget.onClose();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text(
                  'Terminé',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailItem(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Theme.of(context).colorScheme.primary : Colors.black,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Peintre personnalisé pour dessiner une coche animée
class CheckmarkPainter extends CustomPainter {
  final double animation;
  final Color color;
  final double strokeWidth;

  CheckmarkPainter({
    required this.animation,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final tickPath = createTickPath(size);
    
    // Mesurer la longueur du chemin
    final pathMetrics = tickPath.computeMetrics().toList();
    
    for (var metric in pathMetrics) {
      final length = metric.length;
      final extractPath = metric.extractPath(
        0,
        length * animation,
      );
      path.addPath(extractPath, Offset.zero);
    }
    
    canvas.drawPath(path, paint);
  }

  Path createTickPath(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    
    // Dessiner la coche (checkmark)
    path.moveTo(width * 0.2, height * 0.5);
    path.lineTo(width * 0.45, height * 0.75);
    path.lineTo(width * 0.8, height * 0.25);
    
    return path;
  }

  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) => 
      animation != oldDelegate.animation ||
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth;
}
