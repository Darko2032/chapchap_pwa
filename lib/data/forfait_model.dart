class Forfait {
  final String description;
  final String validite;
  final int prix;

  Forfait({
    required this.description,
    required this.validite,
    required this.prix,
  });

  // Convertir un JSON en objet Forfait
  factory Forfait.fromJson(Map<String, dynamic> json) {
    return Forfait(
      description: json['description'] ?? '',
      validite: json['validite'] ?? '',
      prix: json['prix'] is String 
        ? int.tryParse(json['prix']) ?? 0 
        : json['prix'] ?? 0,
    );
  }

  // Convertir un objet Forfait en JSON
  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'validite': validite,
      'prix': prix,
    };
  }

  @override
  String toString() {
    return '$description - $validite - $prix FCFA';
  }
}

class Commande {
  final String id;
  final DateTime date;
  final String reseau;
  final String type;
  final String numero;
  final String montant;
  final String? forfait;
  final String numeroTransaction;
  final String total;
  final String? statut;

  Commande({
    required this.id,
    required this.date,
    required this.reseau,
    required this.type,
    required this.numero,
    required this.montant,
    this.forfait,
    required this.numeroTransaction,
    required this.total,
    this.statut,
  });

  // Convertir un JSON en objet Commande
  factory Commande.fromJson(Map<String, dynamic> json) {
    return Commande(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: json['date'] != null 
        ? DateTime.tryParse(json['date']) ?? DateTime.now() 
        : DateTime.now(),
      reseau: json['reseau'] ?? '',
      type: json['type'] ?? '',
      numero: json['numero'] ?? '',
      montant: json['montant'] ?? '',
      forfait: json['forfait'],
      numeroTransaction: json['numero_transaction'] ?? '',
      total: json['total'] ?? '',
      statut: json['statut'],
    );
  }

  // Convertir un objet Commande en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'reseau': reseau,
      'type': type,
      'numero': numero,
      'montant': montant,
      'forfait': forfait,
      'numero_transaction': numeroTransaction,
      'total': total,
      'statut': statut,
    };
  }
}
