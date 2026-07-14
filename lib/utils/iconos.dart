import 'package:flutter/material.dart';

class Iconos {
  // Mapa de íconos Material para medios de pago
  static const Map<String, IconData> mapa = {
    'credit_card':    Icons.credit_card,
    'debit_card':     Icons.payment,
    'cash':           Icons.attach_money,
    'transfer':       Icons.swap_horiz,
    'savings':        Icons.savings,
    'phone':          Icons.phone_android,
    'wallet':         Icons.account_balance_wallet,
    'bank':           Icons.account_balance,
    // Categorías (fallback si se usa ícono antiguo)
    'food':           Icons.restaurant,
    'supermercado':   Icons.shopping_cart,
    'home':           Icons.home,
    'health':         Icons.local_pharmacy,
    'transport':      Icons.directions_car,
    'entertainment':  Icons.movie,
    'education':      Icons.school,
    'travel':         Icons.flight,
    'others':         Icons.more_horiz,
  };

  static IconData get(String? icono) =>
      mapa[icono] ?? Icons.category;

  // ── Emojis para categorías ─────────────────────────────────────────────────
  static const Map<String, String> emojis = {
    // 🍽 Alimentación
    '🛒': 'Supermercado',
    '🍔': 'Comida rápida',
    '🛵': 'Delivery',
    '☕': 'Café',
    '🍺': 'Bar/Tragos',
    '🍕': 'Pizza',
    '🌮': 'Restorán',
    '🍣': 'Sushi',
    '🍦': 'Helado',
    '🍷': 'Vinos',
    '🥗': 'Ensaladas',
    '🧃': 'Bebidas',
    // 🚗 Transporte
    '🚗': 'Auto',
    '⛽': 'Bencina',
    '🅿️': 'Estacionamiento',
    '🚌': 'Bus/Metro',
    '✈️': 'Vuelos',
    '🚕': 'Taxi/Uber',
    '🚲': 'Bicicleta',
    '🛳️': 'Barco/Ferry',
    // 🏠 Hogar
    '🏠': 'Arriendo/Dividendo',
    '💡': 'Luz/Electricidad',
    '📡': 'Internet/Cable',
    '🛋️': 'Muebles',
    '🧹': 'Limpieza',
    '🌱': 'Jardín',
    '🔧': 'Mantención',
    '🔒': 'Seguridad',
    '🍳': 'Electrodomésticos',
    // 👕 Vestuario
    '👕': 'Ropa',
    '👟': 'Zapatos',
    '👜': 'Accesorios',
    '🕶️': 'Lentes',
    '🧥': 'Abrigos',
    // 💊 Salud
    '💊': 'Farmacia',
    '🏥': 'Médico',
    '🦷': 'Dental',
    '💪': 'Gym',
    '🧘': 'Bienestar',
    '🧴': 'Higiene',
    '🏃': 'Deporte',
    '🏊': 'Natación',
    '⚽': 'Fútbol',
    '🥾': 'Senderismo',
    // 🎬 Entretenimiento
    '🎬': 'Cine',
    '🎮': 'Videojuegos',
    '🎵': 'Música',
    '📺': 'Streaming',
    '🎟️': 'Eventos',
    '📚': 'Libros',
    '🎭': 'Teatro',
    '🎲': 'Juegos',
    // ✈️ Viajes
    '🏨': 'Hotel',
    '🗺️': 'Turismo',
    '🧳': 'Maletas',
    '🏖️': 'Playa',
    '⛷️': 'Ski',
    // 💻 Tecnología
    '📱': 'Celular',
    '💻': 'Computador',
    '🎧': 'Audífonos',
    '📷': 'Fotografía',
    '🖨️': 'Impresora',
    '☁️': 'Nube/Storage',
    '📲': 'Apps/Suscripciones',
    // 🐾 Mascotas
    '🐶': 'Mascotas',
    '🐱': 'Gato',
    '🐾': 'Veterinario',
    '🦴': 'Comida mascota',
    // 🎓 Educación
    '🎓': 'Educación',
    '📖': 'Cursos',
    '✏️': 'Útiles',
    '🏫': 'Colegio',
    // 💰 Finanzas
    '🏦': 'Banco',
    '🛡️': 'Seguro',
    '💳': 'Tarjeta',
    '📈': 'Inversión',
    '💸': 'Impuestos',
    '🧾': 'Comisiones',
    // 👶 Bebés
    '👶': 'Bebé',
    '🧸': 'Juguetes',
    '🍼': 'Productos bebé',
    // 💅 Belleza
    '💅': 'Belleza/Spa',
    '💈': 'Peluquería',
    '🪥': 'Cuidado personal',
    // 👔 Trabajo
    '💼': 'Trabajo',
    '🏢': 'Oficina',
    // 🎁 Otros
    '🎁': 'Regalos',
    '🙏': 'Donaciones',
    '⛪': 'Iglesia',
    '📄': 'Documentos',
    '❓': 'Otros',
  };

  // Lista ordenada para el selector
  static List<String> get listaEmojis => emojis.keys.toList();

  /// Devuelve true si el string es un emoji (no un key de Material)
  static bool esEmoji(String icono) {
    if (icono.isEmpty) return false;
    // Los keys Material son ASCII puro, los emojis tienen codepoints > 127
    return icono.runes.any((r) => r > 127);
  }

  /// Mapa de conversión de keys antiguos a emojis
  static const Map<String, String> legacyToEmoji = {
    'supermercado': '🛒', 'food': '🍔', 'delivery': '🛵', 'cafe': '☕',
    'bar': '🍺', 'car': '🚗', 'bencina': '⛽', 'parking': '🅿️',
    'transport': '🚗', 'bus': '🚌', 'home': '🏠', 'utilities': '💡',
    'internet': '📡', 'furniture': '🛋️', 'cleaning': '🧹',
    'clothing': '👕', 'shoes': '👟', 'shopping': '🛒', 'accessories': '👜',
    'health': '💊', 'doctor': '🏥', 'dental': '🦷', 'gym': '💪',
    'wellness': '🧘', 'hygiene': '🧴', 'entertainment': '🎬',
    'gaming': '🎮', 'music': '🎵', 'streaming': '📺', 'events': '🎟️',
    'books': '📚', 'travel': '✈️', 'hotel': '🏨', 'tourism': '🗺️',
    'luggage': '🧳', 'phone': '📱', 'computer': '💻', 'electronics': '📲',
    'tech': '🎧', 'pets': '🐶', 'vet': '🐾', 'pet_food': '🦴',
    'education': '🎓', 'courses': '📖', 'school': '🏫',
    'account_balance': '🏦', 'insurance': '🛡️', 'credit_card': '💳',
    'investment': '📈', 'tools': '🔧', 'gift': '🎁', 'haircut': '💈',
    'laundry': '🧹', 'others': '❓', 'fast_food': '🍔', 'pizza': '🍕',
    'ice_cream': '🍦', 'wine': '🍷', 'subscription': '📲', 'cloud': '☁️',
    'app': '📲', 'donation': '🙏', 'documents': '📄', 'taxes': '🧾',
    'fees': '💸', 'baby': '👶', 'toy': '🧸', 'baby_food': '🍼',
    'sport': '⚽', 'bike': '🚲', 'swimming': '🏊', 'hiking': '🥾',
    'beauty': '💅', 'spa': '💅', 'makeup': '💅', 'rent': '🏠',
    'garden': '🌱', 'security': '🔒', 'appliance': '🍳',
    'work': '💼', 'office': '🏢', 'parking_work': '🅿️',
  };

  /// Convierte un ícono (legacy key o emoji) a emoji para mostrar
  static String toEmoji(String icono) {
    if (esEmoji(icono)) return icono;
    return legacyToEmoji[icono] ?? '❓';
  }

  // Lista de íconos Material para medios de pago
  static const List<Map<String, dynamic>> opcionesMedioPago = [
    {'key': 'credit_card', 'label': 'TC'},
    {'key': 'debit_card',  'label': 'Débito'},
    {'key': 'cash',        'label': 'Efectivo'},
    {'key': 'transfer',    'label': 'Transfer'},
    {'key': 'savings',     'label': 'Ahorro'},
    {'key': 'wallet',      'label': 'Billetera'},
    {'key': 'bank',        'label': 'Banco'},
    {'key': 'phone',       'label': 'App pago'},
  ];
}
