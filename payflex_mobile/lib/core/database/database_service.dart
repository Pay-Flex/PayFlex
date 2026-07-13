import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../logging/payflex_error_logger.dart';
import '../security/secret_compare.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  static const String _kRemoteSessionPhone = 'remote_session_phone';
  static const String _kRemoteSessionPin = 'remote_session_pin';
  static const String _kRemoteProfileJson = 'remote_profile_json';

  static const String _kPendingRegPhone = 'pending_reg_phone';
  static const String _kPendingRegPin = 'pending_reg_pin';
  static const String _kPendingRegName = 'pending_reg_name';
  static const String _kPendingRegRole = 'pending_reg_role';
  static const String _kPendingRegId = 'pending_reg_id';
  static const String _kPendingRegAgentId = 'pending_reg_agent_id';
  static String _kPushCursorNotif(int userId) => 'push_cursor_notif_$userId';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'payflex_elite.db');

      final db = await openDatabase(
        path,
        version: 6,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      await _seedCatalogue(db);
      return db;
    } catch (e, st) {
      PayflexErrorLogger.logError('SQLite', e, st);
      rethrow;
    }
  }

  Future _onCreate(Database db, int version) async {
    // 1. Users table (Stores Role, PIN, Secret Code and Assignments)
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        phone TEXT,
        role TEXT NOT NULL, -- 'agent', 'client', 'admin'
        pin TEXT NOT NULL, -- Password
        secret_code TEXT, -- Code unique pour validation physique (Cas 1)
        profession TEXT,
        agent_id INTEGER, -- ID de l'agent assigné (si client)
        current_project_id TEXT, -- Projet actif du client (cotisations)
        is_approved INTEGER DEFAULT 0, -- Soumis à validation admin
        is_active INTEGER DEFAULT 1
      )
    ''');

    // 2. Projects table
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        target_amount REAL NOT NULL,
        saved_amount REAL DEFAULT 0,
        daily_suggested REAL NOT NULL
      )
    ''');

    // 3. Transactions table (The "Carnet")
    // Note: en SQLite, pas de colonnes après une contrainte FOREIGN KEY — la FK doit être en dernier.
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        project_id TEXT,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        rejection_reason TEXT,
        agent_id INTEGER,
        client_user_id INTEGER,
        catchup_year INTEGER,
        catchup_month INTEGER,
        catchup_day INTEGER,
        FOREIGN KEY (project_id) REFERENCES projects (id)
      )
    ''');
    
    // 4. Reports (Signalement) table
    await db.execute('''
      CREATE TABLE reports (
        id TEXT PRIMARY KEY,
        agent_id TEXT,
        client_id TEXT,
        reason TEXT,
        media_path TEXT,
        date TEXT NOT NULL
      )
    ''');

    // 5. Chat Messages table
    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        sender_role TEXT NOT NULL, -- 'admin' ou 'user'
        timestamp TEXT NOT NULL
      )
    ''');

    // 6. Custom Requests table
    await db.execute('''
      CREATE TABLE custom_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_name TEXT NOT NULL,
        description TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        status TEXT DEFAULT 'en_attente',
        timestamp TEXT NOT NULL
      )
    ''');

    // 7. Catalogue items table
    await db.execute('''
      CREATE TABLE catalogue_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        price REAL NOT NULL,
        daily_min REAL NOT NULL,
        is_featured INTEGER DEFAULT 0,
        image_url TEXT NOT NULL,
        description TEXT NOT NULL
      )
    ''');

    // 8. Session config table (Persistence of logged user)
    await db.execute('''
      CREATE TABLE config (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    
    // Injection des produits de démonstration
    await _seedCatalogue(db);
    
    // Message de bienvenue Admin
    await db.insert('chat_messages', {
      'text': 'Bonjour ! Bienvenue sur PayFlex Elite Support. Comment pouvons-nous vous aider dans votre projet d\'équipement aujourd\'hui ?',
      'sender_role': 'admin',
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Insertion d'un Agent de démo (Jean Dupont)
    await db.insert('users', {
      'name': 'Jean Dupont',
      'phone': '+221 77 123 45 67',
      'role': 'agent',
      'pin': '1111',
      'is_approved': 1,
    });

    // Seeding des 2 autres agents demandés
    await db.insert('users', {
      'name': 'Marie Diallo',
      'phone': '+221 78 123 45 67',
      'role': 'agent',
      'pin': '2222',
      'is_approved': 1,
    });

    await db.insert('users', {
      'name': 'Moussa Traoré',
      'phone': '+221 70 123 45 67',
      'role': 'agent',
      'pin': '3333',
      'is_approved': 1,
    });
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE users ADD COLUMN name TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN phone TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN secret_code TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN agent_id INTEGER');
      await db.execute('ALTER TABLE users ADD COLUMN is_approved INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE transactions ADD COLUMN rejection_reason TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN agent_id INTEGER');
    }
    if (oldVersion < 3) {
      // Nettoyage et Re-seeding des agents pour version 3
      await db.delete('users', where: 'role = ?', whereArgs: ['agent']);
      await db.insert('users', {'name': 'Jean Dupont', 'phone': '+221 77 123 45 67', 'role': 'agent', 'pin': '1111', 'is_approved': 1});
      await db.insert('users', {'name': 'Marie Diallo', 'phone': '+221 78 123 45 67', 'role': 'agent', 'pin': '2222', 'is_approved': 1});
      await db.insert('users', {'name': 'Moussa Traoré', 'phone': '+221 70 123 45 67', 'role': 'agent', 'pin': '3333', 'is_approved': 1});
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE users ADD COLUMN current_project_id TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN client_user_id INTEGER');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE transactions ADD COLUMN catchup_year INTEGER');
      await db.execute('ALTER TABLE transactions ADD COLUMN catchup_month INTEGER');
      await db.execute('ALTER TABLE transactions ADD COLUMN catchup_day INTEGER');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS catalogue_items (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          price REAL NOT NULL,
          daily_min REAL NOT NULL,
          is_featured INTEGER DEFAULT 0,
          image_url TEXT NOT NULL,
          description TEXT NOT NULL
        )
      ''');
      await _seedCatalogue(db);
    }
  }

  Future<void> _seedCatalogue(Database db) async {
    final products = [
      {
        'id': 'prod_001', 'name': 'Moto Jakarta 100cc', 'category': 'Mécanique',
        'price': 450000.0, 'daily_min': 1500.0, 'is_featured': 1,
        'image_url': 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
        'description': 'La Moto Jakarta 100cc est le choix idéal pour vos déplacements quotidiens ou professionnels. Conçue pour la robustesse et l\'économie de carburant, elle vous permettra d\'optimiser votre temps et vos revenus.'
      },
      {
        'id': 'prod_002', 'name': 'Machine à Espresso Pro', 'category': 'Coiffure',
        'price': 85000.0, 'daily_min': 250.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1510017803434-a899398421b3?w=800&q=80',
        'description': 'Machine à espresso professionnelle pour les amateurs de café ou les petits commerces. Pression 15 bars, réservoir 1.5L, chauffe rapide en 30 secondes.'
      },
      {
        'id': 'prod_003', 'name': 'Laptop Pro 14"', 'category': 'Électricité bâtiment',
        'price': 550000.0, 'daily_min': 1500.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=800&q=80',
        'description': 'Ordinateur portable haute performance avec processeur Intel Core i7, 16 Go RAM, SSD 512 Go. Idéal pour les professionnels, graphistes et développeurs.'
      },
      {
        'id': 'prod_004', 'name': 'Pack Perceuse-Visseuse', 'category': 'Menuiserie',
        'price': 65000.0, 'daily_min': 200.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&q=80',
        'description': 'Pack perceuse-visseuse sans fil 18V avec 2 batteries, chargeur rapide et 50 embouts. Couple max 60 Nm, vitesse variable.'
      },
      {
        'id': 'prod_005', 'name': 'Smart TV 55"', 'category': 'Électricité bâtiment',
        'price': 320000.0, 'daily_min': 900.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1593359674241-55ec0aca2d47?w=800&q=80',
        'description': 'Téléviseur Smart TV 55 pouces 4K Ultra HD. Android TV intégré, WiFi, Bluetooth, HDR Dolby Vision. Compatible Netflix, YouTube, Prime Video.'
      },
      {
        'id': 'prod_006', 'name': 'Machine à Laver 7kg', 'category': 'Plomberie',
        'price': 210000.0, 'daily_min': 600.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1626806819282-2c1dc01a5e0c?w=800&q=80',
        'description': 'Machine à laver 7 kg chargement frontal. 15 programmes, essorage 1200 tr/min, classe A+++. Technologie inverter silencieuse.'
      },
      {
        'id': 'prod_007', 'name': 'Canapé Scandinave 3 Places', 'category': 'Couture',
        'price': 375000.0, 'daily_min': 1200.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=800&q=80',
        'description': 'Canapé 3 places au design scandinave épuré. Structure bois massif, revêtement tissu anti-tache, pieds métal doré.'
      },
      {
        'id': 'prod_008', 'name': 'Réfrigérateur Side by Side', 'category': 'Froid et climatisation',
        'price': 480000.0, 'daily_min': 1300.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1584568694244-14fbdf83bd30?w=800&q=80',
        'description': 'Réfrigérateur américain Side by Side 600L. No Frost total, distributeur d\'eau et glaçons, écran LCD, classe A+.'
      },
      {
        'id': 'prod_009', 'name': 'Kit Solaire 500W Premium', 'category': 'Électricité bâtiment',
        'price': 650000.0, 'daily_min': 1800.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1509391366360-fe5bb58583bb?w=800&q=80',
        'description': 'Système solaire complet 500W avec 2 panneaux, onduleur pur sinus, batterie gel 200Ah et 10 lampes LED. Idéal pour l\'autonomie totale d\'une maison.'
      },
      {
        'id': 'prod_010', 'name': 'Cuisinière Inox 5 Feux', 'category': 'Soudure',
        'price': 185000.0, 'daily_min': 500.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1556912177-c54030639a6d?w=800&q=80',
        'description': 'Grande cuisinière en acier inoxydable avec 5 feux gaz et four auto-nettoyant. Allumage électrique, sécurité thermocouple.'
      },
      {
        'id': 'prod_011', 'name': 'Moulin à Grains Pro', 'category': 'Maçonnerie',
        'price': 225000.0, 'daily_min': 700.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1589710777414-b86bf09df0fe?w=800&q=80',
        'description': 'Moulin électrique haute performance pour maïs, mil et sorgho. Moteur 2HP, débit 100kg/heure, construction robuste en fonte.'
      },
      {
        'id': 'prod_012', 'name': 'Bétonnière Électrique 160L', 'category': 'Maçonnerie',
        'price': 310000.0, 'daily_min': 950.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=800&q=80',
        'description': 'Bétonnière professionnelle 160 litres. Cuve en acier renforcé, couronne en fonte, moteur silencieux 650W. Idéale pour vos chantiers.'
      },
      {
        'id': 'prod_013', 'name': 'Pompe à Eau Solaire', 'category': 'Plomberie',
        'price': 420000.0, 'daily_min': 1200.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1615811361523-6bd03d7748e7?w=800&q=80',
        'description': 'Système de pompage solaire immergé pour puits et forages. Débit 2m3/heure, profondeur max 40m. Idéal pour l\'irrigation agricole.'
      },
    ];
    for (final p in products) {
      await db.insert('catalogue_items', p, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // --- CRUD Utilisateur ---
  Future<void> saveUser(
    String role,
    String pin, {
    String? name,
    String? phone,
    String? profession,
    String? city,
    String? gender,
  }) async {
    final db = await database;
    await db.insert(
      'users',
      {
        'name': name ?? '',
        'phone': phone ?? '',
        'role': role,
        'pin': pin,
        'profession': [
          if (profession != null && profession.isNotEmpty) profession,
          if (city != null && city.isNotEmpty) city,
          if (gender != null && gender.isNotEmpty) gender,
        ].join(' | '),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setCurrentUserId(int? id) async {
    final db = await database;
    if (id == null) {
      await db.delete('config', where: 'key = ?', whereArgs: ['current_user_id']);
    } else {
      await db.insert('config', {'key': 'current_user_id', 'value': id.toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> upsertLocalUserProjection({
    required int userId,
    String? name,
    String? phone,
    String? role,
    String? pin,
  }) async {
    final db = await database;
    final rows = await db.query('users', columns: ['id'], where: 'id = ?', whereArgs: [userId], limit: 1);
    final normalizedRole = (role == null || role.trim().isEmpty) ? 'client' : role.trim();
    final data = <String, Object?>{
      'name': (name ?? '').trim(),
      'phone': (phone ?? '').trim(),
      'role': normalizedRole,
      'pin': pin ?? '',
      'is_active': 1,
    };
    if (rows.isEmpty) {
      await db.insert('users', {'id': userId, ...data}, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.update('users', data, where: 'id = ?', whereArgs: [userId]);
    }
  }

  Future<int?> getCurrentUserId() async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.query('config', where: 'key = ?', whereArgs: ['current_user_id'], limit: 1);
    if (res.isNotEmpty) {
      return int.parse(res.first['value'] as String);
    }
    return null;
  }

  /// Session « serveur » : id MySQL + téléphone + PIN pour recharger le profil (ne pas utiliser pour les comptes SQLite locaux seuls).
  Future<void> saveRemoteSession({
    required int userId,
    required String phone,
    required String pin,
    required Map<String, dynamic> profile,
  }) async {
    final db = await database;
    final batch = db.batch();
    batch.insert(
      'config',
      {'key': 'current_user_id', 'value': userId.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      'config',
      {'key': _kRemoteSessionPhone, 'value': phone},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      'config',
      {'key': _kRemoteSessionPin, 'value': pin},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      'config',
      {'key': _kRemoteProfileJson, 'value': jsonEncode(profile)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await batch.commit(noResult: true);
  }

  /// Retourne userId, phone, pin, profile si session serveur complète.
  Future<Map<String, dynamic>?> loadRemoteSession() async {
    final db = await database;
    Future<String?> one(String key) async {
      final rows = await db.query('config', where: 'key = ?', whereArgs: [key], limit: 1);
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    }

    final uidStr = await one('current_user_id');
    final phone = await one(_kRemoteSessionPhone);
    final pin = await one(_kRemoteSessionPin);
    final jsonStr = await one(_kRemoteProfileJson);
    if (uidStr == null || phone == null || pin == null || jsonStr == null) return null;
    final userId = int.tryParse(uidStr);
    if (userId == null) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return null;
      return {
        'userId': userId,
        'phone': phone,
        'pin': pin,
        'profile': Map<String, dynamic>.from(decoded),
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> savePushCursor({required int userId, required int notificationId}) async {
    final db = await database;
    await db.insert(
      'config',
      {'key': _kPushCursorNotif(userId), 'value': notificationId.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<({int notificationId})?> loadPushCursor(int userId) async {
    final db = await database;
    final rows = await db.query(
      'config',
      where: 'key = ?',
      whereArgs: [_kPushCursorNotif(userId)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final id = int.tryParse(rows.first['value'] as String? ?? '');
    if (id == null) return null;
    return (notificationId: id);
  }

  Future<void> clearRemoteSession() async {
    final db = await database;
    await db.delete('config', where: 'key IN (?, ?, ?, ?)', whereArgs: [
      'current_user_id',
      _kRemoteSessionPhone,
      _kRemoteSessionPin,
      _kRemoteProfileJson,
    ]);
  }

  /// Session locale après envoi d'une demande d'inscription (en attente validation admin).
  Future<void> savePendingRegistrationSession({
    required String phone,
    required String pin,
    required String fullName,
    required String role,
    int? registrationId,
    int? assignedAgentUserId,
  }) async {
    final db = await database;
    final batch = db.batch();
    void put(String key, String value) {
      batch.insert('config', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    put(_kPendingRegPhone, phone);
    put(_kPendingRegPin, pin);
    put(_kPendingRegName, fullName);
    put(_kPendingRegRole, role);
    if (registrationId != null) put(_kPendingRegId, registrationId.toString());
    if (assignedAgentUserId != null) put(_kPendingRegAgentId, assignedAgentUserId.toString());
    await batch.commit(noResult: true);
    await clearRemoteSession();
    await setCurrentUserId(null);
  }

  Future<Map<String, dynamic>?> loadPendingRegistrationSession() async {
    final db = await database;
    Future<String?> one(String key) async {
      final rows = await db.query('config', where: 'key = ?', whereArgs: [key], limit: 1);
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    }

    final phone = await one(_kPendingRegPhone);
    final pin = await one(_kPendingRegPin);
    final name = await one(_kPendingRegName);
    final role = await one(_kPendingRegRole);
    if (phone == null || pin == null || name == null || role == null) return null;

    return {
      'phone': phone,
      'pin': pin,
      'fullName': name,
      'role': role,
      'registrationId': int.tryParse(await one(_kPendingRegId) ?? ''),
      'assignedAgentUserId': int.tryParse(await one(_kPendingRegAgentId) ?? ''),
    };
  }

  Future<void> clearPendingRegistrationSession() async {
    final db = await database;
    await db.delete('config', where: 'key IN (?, ?, ?, ?, ?, ?)', whereArgs: [
      _kPendingRegPhone,
      _kPendingRegPin,
      _kPendingRegName,
      _kPendingRegRole,
      _kPendingRegId,
      _kPendingRegAgentId,
    ]);
  }

  Future<Map<String, dynamic>?> login(String phone, String pin) async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.query(
      'users',
      where: 'phone = ? AND pin = ? AND is_active = 1',
      whereArgs: [phone, pin],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }
  
  Future<void> clearDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'payflex_elite.db');
    await deleteDatabase(path);
    _database = null;
  }

  // --- CRUD Projets ---
  Future<List<Map<String, dynamic>>> getProjects() async {
    final db = await database;
    return await db.query('projects');
  }

  Future<void> addProject(String id, String title, double targetAmount, double dailySuggested) async {
    final db = await database;
    await db.insert(
      'projects',
      {
        'id': id,
        'title': title,
        'target_amount': targetAmount,
        'saved_amount': 0.0,
        'daily_suggested': dailySuggested,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateProjectSavedAmount(String id, double additionalAmount) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE projects SET saved_amount = saved_amount + ? WHERE id = ?',
      [additionalAmount, id]
    );
  }

  // --- CRUD Transactions (Le Carnet) ---
  Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await database;
    return await db.query('transactions', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getTransactionsForClient(int clientUserId) async {
    final db = await database;
    return await db.query(
      'transactions',
      where: 'client_user_id = ?',
      whereArgs: [clientUserId],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getProjectsForAgentClient(int clientUserId) async {
    final db = await database;
    final aggregateId = 'cfin_$clientUserId';
    final txRows = await db.query(
      'transactions',
      columns: ['project_id'],
      where: 'client_user_id = ?',
      whereArgs: [clientUserId],
      distinct: true,
    );
    final ids = <String>{aggregateId};
    for (final r in txRows) {
      final pid = r['project_id']?.toString();
      if (pid != null && pid.isNotEmpty) ids.add(pid);
    }
    if (ids.isEmpty) return [];
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.rawQuery(
      'SELECT * FROM projects WHERE id IN ($placeholders) ORDER BY title ASC',
      ids.toList(),
    );
  }

  /// Carnet agent : historique serveur d'un client pour le suivi calendrier.
  Future<void> syncAgentClientContributions({
    required int clientUserId,
    required List<Map<String, dynamic>> contributions,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions', where: 'client_user_id = ?', whereArgs: [clientUserId]);
      for (final c in contributions) {
        final rawProjectId = c['product_id'];
        final pid = rawProjectId == null ? 'cfin_$clientUserId' : 'prod_${rawProjectId.toString()}';
        await txn.insert(
          'transactions',
          {
            'id': c['id'].toString(),
            'project_id': pid,
            'amount': (c['amount'] as num?)?.toDouble() ?? 0,
            'date': (c['paid_at'] ?? c['created_at'])?.toString() ?? DateTime.now().toIso8601String(),
            'type': c['payment_mode']?.toString() ?? 'cash',
            'status': c['status']?.toString() ?? 'pending',
            'client_user_id': clientUserId,
            'catchup_year': c['catchup_year'] is num ? (c['catchup_year'] as num).toInt() : null,
            'catchup_month': c['catchup_month'] is num ? (c['catchup_month'] as num).toInt() : null,
            'catchup_day': c['catchup_day'] is num ? (c['catchup_day'] as num).toInt() : null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Recalcule le carnet local depuis l’historique serveur d’un client connecté.
  Future<void> replaceFinanceFromServer({
    required int userId,
    required List<Map<String, dynamic>> contributions,
  }) async {
    if (contributions.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions', where: 'client_user_id = ?', whereArgs: [userId]);
      await txn.delete('projects');

      final byProject = <String, Map<String, dynamic>>{};
      String? newestProjectId;
      DateTime? newestDate;

      for (final c in contributions) {
        final rawProjectId = c['product_id'];
        if (rawProjectId == null) continue;
        final pid = 'prod_${rawProjectId.toString()}';
        final amount = (c['amount'] as num?)?.toDouble() ?? 0;
        final status = (c['status']?.toString() ?? 'pending').trim();
        final createdAt = c['created_at']?.toString() ?? DateTime.now().toIso8601String();

        await txn.insert(
          'transactions',
          {
            'id': c['id'].toString(),
            'project_id': pid,
            'amount': amount,
            'date': createdAt,
            'type': c['payment_mode']?.toString() ?? 'mobile_money',
            'status': status,
            'rejection_reason': c['rejection_reason']?.toString(),
            'client_user_id': userId,
            'catchup_year': c['catchup_year'] is num ? (c['catchup_year'] as num).toInt() : null,
            'catchup_month': c['catchup_month'] is num ? (c['catchup_month'] as num).toInt() : null,
            'catchup_day': c['catchup_day'] is num ? (c['catchup_day'] as num).toInt() : null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final item = byProject.putIfAbsent(pid, () {
          return {
            'id': pid,
            'title': (c['product_name']?.toString().trim().isNotEmpty ?? false)
                ? c['product_name'].toString().trim()
                : 'Projet PayFlex',
            'target_amount': (c['product_price'] as num?)?.toDouble() ?? 0.0,
            'saved_amount': 0.0,
            'daily_suggested': (c['product_daily_min'] as num?)?.toDouble() ?? 0.0,
          };
        });
        if (status == 'validated') {
          item['saved_amount'] = (item['saved_amount'] as double) + amount;
        }

        final dt = DateTime.tryParse(createdAt);
        if (dt != null && (newestDate == null || dt.isAfter(newestDate))) {
          newestDate = dt;
          newestProjectId = pid;
        }
      }

      for (final p in byProject.values) {
        await txn.insert('projects', p, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      if (newestProjectId != null) {
        await txn.update(
          'users',
          {'current_project_id': newestProjectId},
          where: 'id = ?',
          whereArgs: [userId],
        );
      }
    });
  }

  // --- CRUD Catalogue ---
  Future<List<Map<String, dynamic>>> getCatalogueItems({String? category}) async {
    final db = await database;
    
    // Vérification de sécurité : si vide, on injecte les produits
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM catalogue_items'));
    if (count == 0) {
      await _seedCatalogue(db);
    }

    if (category == null || category == 'Tous') {
      return await db.query('catalogue_items');
    }
    return await db.query('catalogue_items', where: 'category = ?', whereArgs: [category]);
  }

  Future<List<Map<String, dynamic>>> searchCatalogueItems(String query) async {
    final db = await database;
    return await db.rawQuery(
      'SELECT * FROM catalogue_items WHERE name LIKE ? OR category LIKE ?',
      ['%$query%', '%$query%'],
    );
  }

  Future<Map<String, dynamic>?> getFeaturedProduct() async {
    final db = await database;
    final results = await db.query('catalogue_items', where: 'is_featured = 1', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> addTransaction(
    String id,
    String projectId,
    double amount,
    String date,
    String type,
    String status, {
    int? agentId,
    int? clientUserId,
    int? catchupYear,
    int? catchupMonth,
    int? catchupDay,
  }) async {
    final db = await database;
    final row = <String, dynamic>{
      'id': id,
      'project_id': projectId,
      'amount': amount,
      'date': date,
      'type': type,
      'status': status,
    };
    if (agentId != null) row['agent_id'] = agentId;
    if (clientUserId != null) row['client_user_id'] = clientUserId;
    if (catchupYear != null) row['catchup_year'] = catchupYear;
    if (catchupMonth != null) row['catchup_month'] = catchupMonth;
    if (catchupDay != null) row['catchup_day'] = catchupDay;

    await db.insert('transactions', row, conflictAlgorithm: ConflictAlgorithm.replace);

    if (status == 'validated') {
      await updateProjectSavedAmount(projectId, amount);
    }
  }

  Future<void> updateTransactionStatus(String transactionId, String status, {String? reason}) async {
    final db = await database;

    final List<Map<String, dynamic>> res = await db.query('transactions', where: 'id = ?', whereArgs: [transactionId]);
    if (res.isEmpty) return;

    final trans = res.first;
    final double amount = trans['amount'] as double;
    final String projectId = trans['project_id'] as String;
    final String oldStatus = trans['status'] as String? ?? '';

    await db.update(
      'transactions',
      {
        'status': status,
        'rejection_reason': reason,
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );

    if (status == 'validated' && oldStatus != 'validated') {
      await updateProjectSavedAmount(projectId, amount);
    }
  }

  Future<String?> getPrimaryProjectId() async {
    final db = await database;
    final rows = await db.query('projects', limit: 1, orderBy: 'rowid ASC');
    if (rows.isEmpty) return null;
    return rows.first['id'] as String;
  }

  Future<String?> resolveProjectIdForContribution({int? clientUserId}) async {
    if (clientUserId != null) {
      final db = await database;
      final rows = await db.query(
        'users',
        columns: ['current_project_id'],
        where: 'id = ?',
        whereArgs: [clientUserId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final pid = rows.first['current_project_id'] as String?;
        if (pid != null && pid.isNotEmpty) return pid;
      }
    }
    return await getPrimaryProjectId();
  }

  Future<void> setUserCurrentProject(int userId, String projectId) async {
    final db = await database;
    await db.update(
      'users',
      {'current_project_id': projectId},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<Map<String, dynamic>?> getProjectById(String id) async {
    final db = await database;
    final rows = await db.query('projects', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getTransactionsForProject(String projectId) async {
    final db = await database;
    return await db.query(
      'transactions',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionsForProjects(List<String> projectIds) async {
    if (projectIds.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(projectIds.length, '?').join(',');
    return await db.rawQuery(
      'SELECT * FROM transactions WHERE project_id IN ($placeholders) ORDER BY date DESC',
      projectIds,
    );
  }

  /// Versement explicite (rattrapage) lié à une date du carnet.
  Future<Map<String, dynamic>?> findCatchupTransactionForDay({
    required List<String> projectIds,
    required int year,
    required int month,
    required int day,
  }) async {
    if (projectIds.isEmpty) return null;
    final db = await database;
    final placeholders = List.filled(projectIds.length, '?').join(',');
    final rows = await db.rawQuery(
      '''
      SELECT t.*, p.title AS product_title
      FROM transactions t
      LEFT JOIN projects p ON p.id = t.project_id
      WHERE t.project_id IN ($placeholders)
        AND t.catchup_year = ?
        AND t.catchup_month = ?
        AND t.catchup_day = ?
      ORDER BY t.date DESC
      LIMIT 1
      ''',
      [...projectIds, year, month, day],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<bool> verifyClientSecretCode({required int clientId, required String submitted}) async {
    final db = await database;
    final rows = await db.query(
      'users',
      columns: ['pin', 'secret_code', 'role'],
      where: 'id = ? AND is_active = 1',
      whereArgs: [clientId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    if ((rows.first['role'] as String?) != 'client') return false;
    final stored = (rows.first['pin'] as String?)?.trim().isNotEmpty == true
        ? rows.first['pin'] as String?
        : rows.first['secret_code'] as String?;
    if (stored == null || stored.isEmpty) return false;
    final trimmed = submitted.trim();
    if (trimmed.length < 4) return false;
    return constantTimeSecretMatch(stored, trimmed);
  }

  /// Téléphone local du client (pour synchroniser la collecte avec le centre via le numéro).
  Future<String?> getUserPhone(int userId) async {
    final db = await database;
    final rows = await db.query(
      'users',
      columns: ['phone'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final p = rows.first['phone'] as String?;
    if (p == null) return null;
    final t = p.trim();
    return t.isEmpty ? null : t;
  }

  Future<double?> getDailySuggestedForClient(int clientUserId) async {
    try {
      final pid = await resolveProjectIdForContribution(clientUserId: clientUserId);
      final db = await database;
      final rows = await db.query(
        'projects',
        columns: ['daily_suggested'],
        where: 'id = ?',
        whereArgs: [pid],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return (rows.first['daily_suggested'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT t.*,
             u.name AS client_name,
             p.title AS project_title,
             p.daily_suggested AS project_daily
      FROM transactions t
      LEFT JOIN users u ON u.id = t.client_user_id
      LEFT JOIN projects p ON p.id = t.project_id
      WHERE t.status = ?
      ORDER BY t.date DESC
      ''',
      ['pending'],
    );
  }

  Future<String?> resolveActiveProjectId(List<Map<String, dynamic>> projectsList) async {
    final uid = await getCurrentUserId();
    if (uid != null && projectsList.isNotEmpty) {
      final db = await database;
      final rows = await db.query(
        'users',
        columns: ['current_project_id'],
        where: 'id = ?',
        whereArgs: [uid],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final pid = rows.first['current_project_id'] as String?;
        if (pid != null && pid.isNotEmpty) {
          final exists = projectsList.any((p) => p['id'].toString() == pid);
          if (exists) return pid;
        }
      }
    }
    if (projectsList.isEmpty) return null;
    return projectsList.first['id'].toString();
  }

  Future<Set<int>> getValidatedCatchupDaysForMonth(String projectId, int year, int month) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      columns: ['catchup_day'],
      where:
          'project_id = ? AND status = ? AND catchup_year = ? AND catchup_month = ? AND catchup_day IS NOT NULL',
      whereArgs: [projectId, 'validated', year, month],
    );
    return rows.map((e) => (e['catchup_day'] as num).toInt()).toSet();
  }

  Future<Set<int>> getPendingCatchupDaysForMonth(String projectId, int year, int month) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      columns: ['catchup_day'],
      where:
          'project_id = ? AND status = ? AND catchup_year = ? AND catchup_month = ? AND catchup_day IS NOT NULL',
      whereArgs: [projectId, 'pending', year, month],
    );
    return rows.map((e) => (e['catchup_day'] as num).toInt()).toSet();
  }

  Future<List<Map<String, dynamic>>> getClientsForAgent(int agentId) async {
    final db = await database;
    return await db.query('users', where: 'role = ? AND agent_id = ?', whereArgs: ['client', agentId]);
  }

  /// Synchronise le carnet local agent pour un client serveur (id = userId PayFlex).
  Future<void> syncClientFinanceForAgent({
    required int serverClientUserId,
    required String clientName,
    required int agentUserId,
    required List<Map<String, dynamic>> products,
    required double totalProject,
    required double dailyContribution,
    required double collected,
    int? primaryProductId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'users',
        where: 'id = ?',
        whereArgs: [serverClientUserId],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert('users', {
          'id': serverClientUserId,
          'name': clientName,
          'phone': '',
          'role': 'client',
          'pin': '0000',
          'secret_code': '0000',
          'agent_id': agentUserId,
          'is_approved': 1,
          'is_active': 1,
        });
      } else {
        await txn.update(
          'users',
          {'name': clientName, 'agent_id': agentUserId},
          where: 'id = ?',
          whereArgs: [serverClientUserId],
        );
      }

      final titles = <String>[];
      String? currentProjectId;

      for (final raw in products) {
        final productId = (raw['product_id'] as num?)?.toInt();
        if (productId == null || productId <= 0) continue;
        final pid = 'prod_$productId';
        final name = raw['name']?.toString() ?? 'Produit';
        final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
        final price = (raw['price'] as num?)?.toDouble() ?? 0;
        final dailyMin = (raw['daily_min'] as num?)?.toDouble() ?? 200;
        final lineTotal = price * qty;

        titles.add(qty > 1 ? '$name x$qty' : name);

        await txn.insert(
          'projects',
          {
            'id': pid,
            'title': name,
            'target_amount': lineTotal,
            'saved_amount': 0.0,
            'daily_suggested': dailyMin,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (primaryProductId != null && primaryProductId == productId) {
          currentProjectId = pid;
        }
      }

      final aggregateId = 'cfin_$serverClientUserId';
      await txn.insert(
        'projects',
        {
          'id': aggregateId,
          'title': titles.isEmpty ? 'Projet PayFlex' : titles.join(' + '),
          'target_amount': totalProject,
          'saved_amount': collected,
          'daily_suggested': dailyContribution,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.update(
        'users',
        {'current_project_id': currentProjectId ?? aggregateId},
        where: 'id = ?',
        whereArgs: [serverClientUserId],
      );
    });
  }

  Future<int> registerClientAndProject({
    required String name,
    required String phone,
    required String pin,
    required String secretCode,
    required String profession,
    required int agentId,
    required String projectTitle,
    required double targetAmount,
    required double dailySuggested,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      final projId = 'proj_${DateTime.now().millisecondsSinceEpoch}';

      await txn.insert('projects', {
        'id': projId,
        'title': projectTitle,
        'target_amount': targetAmount,
        'saved_amount': 0.0,
        'daily_suggested': dailySuggested,
      });

      final userId = await txn.insert('users', {
        'name': name,
        'phone': phone,
        'role': 'client',
        'pin': pin,
        'secret_code': pin,
        'profession': profession,
        'agent_id': agentId,
        'current_project_id': projId,
        'is_approved': 1,
      });

      return userId;
    });
  }

  // --- CRUD Chat & Demandes ---
  Future<List<Map<String, dynamic>>> getChatMessages() async {
    final db = await database;
    return await db.query('chat_messages', orderBy: 'id ASC');
  }

  Future<void> sendChatMessage(String text, String senderRole) async {
    final db = await database;
    await db.insert('chat_messages', {
      'text': text,
      'sender_role': senderRole,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> saveCustomRequest(String productName, String description, String phoneNumber) async {
    final db = await database;
    await db.insert('custom_requests', {
      'product_name': productName,
      'description': description,
      'phone_number': phoneNumber,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // On ajoute aussi un message système dans le chat pour confirmation
    await sendChatMessage(
      "Demande envoyée : $productName. Nous vous recontacterons sous 24h au $phoneNumber.",
      'admin'
    );
  }

  static const String _kCartJson = 'cart_lines_json';

  Future<void> saveCartLines(List<Map<String, dynamic>> lines) async {
    final db = await database;
    await db.insert(
      'config',
      {'key': _kCartJson, 'value': jsonEncode(lines)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> loadCartLines() async {
    final db = await database;
    final rows = await db.query('config', where: 'key = ?', whereArgs: [_kCartJson], limit: 1);
    if (rows.isEmpty) return [];
    final raw = rows.first['value'] as String?;
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }
}
