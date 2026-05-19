class WhsTour {
  final int id;
  final int? gebruikerId;
  final String? gebruikerVoornaam;
  final String? gebruikerAchternaam;
  final String? gebruikerEmail;
  final int? vestigingId;
  final String? vestigingAddress;
  final DateTime? datum;

  WhsTour({
    required this.id,
    this.gebruikerId,
    this.gebruikerVoornaam,
    this.gebruikerAchternaam,
    this.gebruikerEmail,
    this.vestigingId,
    this.vestigingAddress,
    this.datum,
  });

  factory WhsTour.fromJson(Map<String, dynamic> json) {
    final gebruiker = json['gebruiker'] as Map<String, dynamic>?;
    final vestiging = json['vestiging'] as Map<String, dynamic>?;

    DateTime? parsedDate;
    final rawDate = json['datum'] ?? json['date'] ?? json['createdAt'];
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString());
    }

    return WhsTour(
      id: (json['id'] as num).toInt(),
      gebruikerId: gebruiker != null && gebruiker['id'] is num
          ? (gebruiker['id'] as num).toInt()
          : null,
      gebruikerVoornaam: gebruiker != null
          ? (gebruiker['voornaam'] ?? gebruiker['firstName'] ?? gebruiker['name'])?.toString()
          : null,
      gebruikerAchternaam: gebruiker != null
          ? (gebruiker['achternaam'] ?? gebruiker['lastName'])?.toString()
          : null,
      gebruikerEmail: gebruiker != null ? gebruiker['email']?.toString() : null,
      vestigingId: vestiging != null && vestiging['id'] is num
          ? (vestiging['id'] as num).toInt()
          : null,
      vestigingAddress: vestiging != null
          ? (vestiging['address'] ?? vestiging['name'])?.toString()
          : null,
      datum: parsedDate,
    );
  }
}
