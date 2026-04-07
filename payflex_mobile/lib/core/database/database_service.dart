import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'payflex_elite.db');

    final db = await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Ajout systématique des nouveaux produits (ignore si déjà présents)
    await _seedCatalogue(db);

    return db;
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
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        project_id TEXT,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL, -- 'mobile_money', 'cash'
        status TEXT NOT NULL, -- 'pending', 'validated', 'rejected'
        rejection_reason TEXT,
        agent_id INTEGER, -- Agent qui a collecté ou doit valider
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
  }

  Future<void> _seedCatalogue(Database db) async {
    final products = [
      {
        'id': 'prod_001', 'name': 'Moto Jakarta 100cc', 'category': 'Mobilité',
        'price': 450000.0, 'daily_min': 1500.0, 'is_featured': 1,
        'image_url': 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
        'description': 'La Moto Jakarta 100cc est le choix idéal pour vos déplacements quotidiens ou professionnels. Conçue pour la robustesse et l\'économie de carburant, elle vous permettra d\'optimiser votre temps et vos revenus.'
      },
      {
        'id': 'prod_002', 'name': 'Machine à Espresso Pro', 'category': 'Électroménager',
        'price': 85000.0, 'daily_min': 250.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1510017803434-a899398421b3?w=800&q=80',
        'description': 'Machine à espresso professionnelle pour les amateurs de café ou les petits commerces. Pression 15 bars, réservoir 1.5L, chauffe rapide en 30 secondes.'
      },
      {
        'id': 'prod_003', 'name': 'Laptop Pro 14"', 'category': 'Informatique',
        'price': 550000.0, 'daily_min': 1500.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=800&q=80',
        'description': 'Ordinateur portable haute performance avec processeur Intel Core i7, 16 Go RAM, SSD 512 Go. Idéal pour les professionnels, graphistes et développeurs.'
      },
      {
        'id': 'prod_004', 'name': 'Pack Perceuse-Visseuse', 'category': 'Outillage',
        'price': 65000.0, 'daily_min': 200.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&q=80',
        'description': 'Pack perceuse-visseuse sans fil 18V avec 2 batteries, chargeur rapide et 50 embouts. Couple max 60 Nm, vitesse variable.'
      },
      {
        'id': 'prod_005', 'name': 'Smart TV 55"', 'category': 'Électronique',
        'price': 320000.0, 'daily_min': 900.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1593359674241-55ec0aca2d47?w=800&q=80',
        'description': 'Téléviseur Smart TV 55 pouces 4K Ultra HD. Android TV intégré, WiFi, Bluetooth, HDR Dolby Vision. Compatible Netflix, YouTube, Prime Video.'
      },
      {
        'id': 'prod_006', 'name': 'Machine à Laver 7kg', 'category': 'Électroménager',
        'price': 210000.0, 'daily_min': 600.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1626806819282-2c1dc01a5e0c?w=800&q=80',
        'description': 'Machine à laver 7 kg chargement frontal. 15 programmes, essorage 1200 tr/min, classe A+++. Technologie inverter silencieuse.'
      },
      {
        'id': 'prod_007', 'name': 'Canapé Scandinave 3 Places', 'category': 'Mobilier',
        'price': 375000.0, 'daily_min': 1200.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=800&q=80',
        'description': 'Canapé 3 places au design scandinave épuré. Structure bois massif, revêtement tissu anti-tache, pieds métal doré.'
      },
      {
        'id': 'prod_008', 'name': 'Réfrigérateur Side by Side', 'category': 'Électroménager',
        'price': 480000.0, 'daily_min': 1300.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1584568694244-14fbdf83bd30?w=800&q=80',
        'description': 'Réfrigérateur américain Side by Side 600L. No Frost total, distributeur d\'eau et glaçons, écran LCD, classe A+.'
      },
      {
        'id': 'prod_009', 'name': 'Kit Solaire 500W Premium', 'category': 'Énergie',
        'price': 650000.0, 'daily_min': 1800.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1509391366360-fe5bb58583bb?w=800&q=80',
        'description': 'Système solaire complet 500W avec 2 panneaux, onduleur pur sinus, batterie gel 200Ah et 10 lampes LED. Idéal pour l\'autonomie totale d\'une maison.'
      },
      {
        'id': 'prod_010', 'name': 'Cuisinière Inox 5 Feux', 'category': 'Cuisine',
        'price': 185000.0, 'daily_min': 500.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1556912177-c54030639a6d?w=800&q=80',
        'description': 'Grande cuisinière en acier inoxydable avec 5 feux gaz et four auto-nettoyant. Allumage électrique, sécurité thermocouple.'
      },
      {
        'id': 'prod_011', 'name': 'Moulin à Grains Pro', 'category': 'Agro-industrie',
        'price': 225000.0, 'daily_min': 700.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1589710777414-b86bf09df0fe?w=800&q=80',
        'description': 'Moulin électrique haute performance pour maïs, mil et sorgho. Moteur 2HP, débit 100kg/heure, construction robuste en fonte.'
      },
      {
        'id': 'prod_012', 'name': 'Bétonnière Électrique 160L', 'category': 'BTP',
        'price': 310000.0, 'daily_min': 950.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=800&q=80',
        'description': 'Bétonnière professionnelle 160 litres. Cuve en acier renforcé, couronne en fonte, moteur silencieux 650W. Idéale pour vos chantiers.'
      },
      {
        'id': 'prod_013', 'name': 'Pompe à Eau Solaire', 'category': 'Énergie',
        'price': 420000.0, 'daily_min': 1200.0, 'is_featured': 0,
        'image_url': 'https://images.unsplash.com/photo-1615811361523-6bd03d7748e7?w=800&q=80',
        'description': 'Système de pompage solaire immergé pour puits et forages. Débit 2m3/heure, profondeur max 40m. Idéal pour l\'irrigation agricole.'
      },
    ];
    for (final p in products) {
      await db.insert('catalogue_items', p, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // --- CRUD Utilisateur ---
  Future<void> saveUser(String role, String pin, {String? profession}) async {
    final db = await database;
    await db.insert(
      'users',
      {
        'role': role,
        'pin': pin,
        'profession': profession ?? '',
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

  Future<int?> getCurrentUserId() async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.query('config', where: 'key = ?', whereArgs: ['current_user_id'], limit: 1);
    if (res.isNotEmpty) {
      return int.parse(res.first['value'] as String);
    }
    return null;
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

  Future<void> addTransaction(String id, String projectId, double amount, String date, String type, String status) async {
    final db = await database;
    await db.insert(
      'transactions',
      {
        'id': id,
        'project_id': projectId,
        'amount': amount,
        'date': date,
        'type': type,
        'status': status,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // Si la transaction est validée immédiatement (Cas 1), on met à jour le projet
    if (status == 'validated') {
      await updateProjectSavedAmount(projectId, amount);
    }
  }

  Future<void> updateTransactionStatus(String transactionId, String status, {String? reason}) async {
    final db = await database;
    
    // 1. On récupère la transaction pour avoir le montant et le projet
    final List<Map<String, dynamic>> res = await db.query('transactions', where: 'id = ?', whereArgs: [transactionId]);
    if (res.isEmpty) return;
    
    final trans = res.first;
    final double amount = trans['amount'] as double;
    final String projectId = trans['project_id'] as String;

    // 2. Mise à jour du statut
    await db.update(
      'transactions',
      {
        'status': status,
        'rejection_reason': reason,
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );

    // 3. Si validé, on impacte le projet
    if (status == 'validated') {
      await updateProjectSavedAmount(projectId, amount);
    }
  }

  Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    final db = await database;
    // On pourrait joindre avec users pour avoir le nom du client
    return await db.query('transactions', where: 'status = ?', whereArgs: ['pending'], orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getClientsForAgent(int agentId) async {
    final db = await database;
    return await db.query('users', where: 'role = ? AND agent_id = ?', whereArgs: ['client', agentId]);
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
      // 1. Créer le compte client
      final userId = await txn.insert('users', {
        'name': name,
        'phone': phone,
        'role': 'client',
        'pin': pin,
        'secret_code': secretCode,
        'profession': profession,
        'agent_id': agentId,
        'is_approved': 1, // Auto-approuvé par l'agent en démo/lite
      });

      // 2. Créer le projet
      await txn.insert('projects', {
        'id': 'proj_${DateTime.now().millisecondsSinceEpoch}',
        'title': projectTitle,
        'target_amount': targetAmount,
        'saved_amount': 0.0,
        'daily_suggested': dailySuggested,
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
}
