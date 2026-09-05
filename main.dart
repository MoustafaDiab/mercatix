import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

/// Represents a Captain (User) in the Mercatix auction system.
class Captain {
  final String uid;
  final String name;
  final String email;
  final double budget; // Remaining budget (starts at 68.0M and is reduced by pre-assigned card & purchases)
  final int stars;     // Remaining stars (starts at 27 and is reduced by pre-assigned card & purchases)
  final int playerCount; // Current count of players in the team (starts at 1 due to pre-assigned captain card)
  final String captainClass; // Chosen fantasy role of the captain (Warrior, Wizard, Rogue, Paladin)
  final double captainCost;  // Cost of the pre-assigned captain player card
  final int captainStars;    // Stars of the pre-assigned captain player card

  Captain({
    required this.uid,
    required this.name,
    required this.email,
    required this.budget,
    required this.stars,
    required this.playerCount,
    required this.captainClass,
    required this.captainCost,
    required this.captainStars,
  });

  /// Factory method to construct a Captain from a Firebase Realtime Database map.
  factory Captain.fromMap(String uid, Map<dynamic, dynamic> map) {
    return Captain(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      budget: (map['budget'] as num?)?.toDouble() ?? 68.0,
      stars: (map['stars'] as num?)?.toInt() ?? 27,
      playerCount: (map['playerCount'] as num?)?.toInt() ?? 0,
      captainClass: map['captainClass'] ?? 'Default',
      captainCost: (map['captainCost'] as num?)?.toDouble() ?? 10.0,
      captainStars: (map['captainStars'] as num?)?.toInt() ?? 4,
    );
  }

  /// Converts the Captain instance to a map for Firebase RTDB updates.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'budget': budget,
      'stars': stars,
      'playerCount': playerCount,
      'captainClass': captainClass,
      'captainCost': captainCost,
      'captainStars': captainStars,
    };
  }
}

/// Represents a purchasable Player in the Mercatix auction system.
class Player {
  final String id;
  final String name;
  final double price; // Cost of the player in Millions (e.g. 14.5M)
  final int stars;    // Rating of the player (1-9 stars)
  final String? ownerId; // UID of the captain who bought this player (null if available)
  final String? ownerName; // Display name of the owner captain (null if available)

  Player({
    required this.id,
    required this.name,
    required this.price,
    required this.stars,
    this.ownerId,
    this.ownerName,
  });

  /// Factory method to construct a Player from a Firebase Realtime Database map.
  factory Player.fromMap(String id, Map<dynamic, dynamic> map) {
    return Player(
      id: id,
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      stars: (map['stars'] as num?)?.toInt() ?? 0,
      ownerId: map['ownerId'],
      ownerName: map['ownerName'],
    );
  }

  /// Converts the Player instance to a map for Firebase RTDB updates.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'stars': stars,
      'ownerId': ownerId,
      'ownerName': ownerName,
    };
  }
}

// ============================================================================
// RIVERPOD PROVIDERS (STATE MANAGEMENT)
// ============================================================================

/// Provider for accessing the Firebase Realtime Database instance.
final dbProvider = Provider<FirebaseDatabase>((ref) => FirebaseDatabase.instance);

/// Provider tracking the currently logged-in Captain email.
final currentCaptainEmailProvider = StateProvider<String?>((ref) => null);

/// Provider tracking the currently logged-in Captain's unique ID.
final currentCaptainIdProvider = StateProvider<String?>((ref) => null);

/// Real-time stream of the current captain's record.
final currentCaptainStreamProvider = StreamProvider<Captain?>((ref) {
  final db = ref.watch(dbProvider);
  final captainId = ref.watch(currentCaptainIdProvider);
  if (captainId == null) return Stream.value(null);
  
  return db.ref().child('captains/$captainId').onValue.map((event) {
    final snapshot = event.snapshot;
    if (snapshot.value == null) return null;
    return Captain.fromMap(captainId, snapshot.value as Map);
  });
});

/// Real-time stream listing all players from the database.
final playersStreamProvider = StreamProvider<List<Player>>((ref) {
  final db = ref.watch(dbProvider);
  return db.ref().child('players').onValue.map((event) {
    final snapshot = event.snapshot;
    if (snapshot.value == null) return [];
    final map = snapshot.value as Map<dynamic, dynamic>;
    return map.entries.map((e) => Player.fromMap(e.key.toString(), e.value as Map)).toList();
  });
});

/// Real-time stream listing all registered captains from the database.
final captainsStreamProvider = StreamProvider<List<Captain>>((ref) {
  final db = ref.watch(dbProvider);
  return db.ref().child('captains').onValue.map((event) {
    final snapshot = event.snapshot;
    if (snapshot.value == null) return [];
    final map = snapshot.value as Map<dynamic, dynamic>;
    return map.entries.map((e) => Captain.fromMap(e.key.toString(), e.value as Map)).toList();
  });
});

// ============================================================================
// DATABASE ACTIONS & SERVICES
// ============================================================================

/// Seeds the Firebase Realtime Database with a standard pool of unbought players if empty.
Future<void> seedDatabaseIfEmpty(FirebaseDatabase db) async {
  final playersRef = db.ref().child('players');
  final snapshot = await playersRef.get();
  
  if (!snapshot.exists || snapshot.value == null) {
    final initialPlayers = {
      'p1': {'name': 'Thorin Oakshield', 'price': 18.0, 'stars': 7, 'ownerId': null, 'ownerName': null},
      'p2': {'name': 'Legolas Greenleaf', 'price': 14.0, 'stars': 6, 'ownerId': null, 'ownerName': null},
      'p3': {'name': 'Gimli Gloinson', 'price': 11.0, 'stars': 5, 'ownerId': null, 'ownerName': null},
      'p4': {'name': 'Gandalf the Grey', 'price': 24.0, 'stars': 8, 'ownerId': null, 'ownerName': null},
      'p5': {'name': 'Aragorn Elessar', 'price': 22.0, 'stars': 8, 'ownerId': null, 'ownerName': null},
      'p6': {'name': 'Frodo Baggins', 'price': 5.0, 'stars': 3, 'ownerId': null, 'ownerName': null},
      'p7': {'name': 'Samwise Gamgee', 'price': 7.0, 'stars': 4, 'ownerId': null, 'ownerName': null},
      'p8': {'name': 'Arwen Undomiel', 'price': 10.0, 'stars': 5, 'ownerId': null, 'ownerName': null},
      'p9': {'name': 'Galadriel of Lorien', 'price': 26.0, 'stars': 9, 'ownerId': null, 'ownerName': null},
      'p10': {'name': 'Boromir of Gondor', 'price': 13.0, 'stars': 6, 'ownerId': null, 'ownerName': null},
      'p11': {'name': 'Gollum Slinker', 'price': 3.0, 'stars': 2, 'ownerId': null, 'ownerName': null},
      'p12': {'name': 'Bilbo Baggins', 'price': 8.0, 'stars': 4, 'ownerId': null, 'ownerName': null},
      'p13': {'name': 'Faramir Ithilien', 'price': 9.0, 'stars': 5, 'ownerId': null, 'ownerName': null},
      'p14': {'name': 'Elrond of Rivendell', 'price': 16.0, 'stars': 7, 'ownerId': null, 'ownerName': null},
      'p15': {'name': 'Gimli son of Gloin', 'price': 12.0, 'stars': 5, 'ownerId': null, 'ownerName': null},
    };
    await playersRef.set(initialPlayers);
  }
}

/// Looks up an existing captain node using the user's email address.
Future<Captain?> lookupCaptainByEmail(FirebaseDatabase db, String email) async {
  final ref = db.ref().child('captains');
  final query = ref.orderByChild('email').equalTo(email.trim().toLowerCase());
  final snapshot = await query.get();
  
  if (snapshot.exists && snapshot.value != null) {
    final map = snapshot.value as Map<dynamic, dynamic>;
    final entry = map.entries.first;
    return Captain.fromMap(entry.key.toString(), entry.value as Map);
  }
  return null;
}

/// Registers a new Captain, pre-assigns their personal Captain Player card to their team,
/// and writes their records atomically into the database.
Future<Captain> registerCaptain({
  required FirebaseDatabase db,
  required String name,
  required String email,
  required String captainClass,
  required double classCost,
  required int classStars,
}) async {
  final cleanEmail = email.trim().toLowerCase();
  final captainsRef = db.ref().child('captains');
  final playersRef = db.ref().child('players');

  // 1. Generate unique Captain UID
  final captainUid = captainsRef.push().key ?? DateTime.now().millisecondsSinceEpoch.toString();

  // 2. Compute deducted starting limits
  // Max Budget: 68M, Max Stars: 27, Player Count: 1 (Captain counts as the first player)
  final double startingBudget = 68.0 - classCost;
  final int startingStars = 27 - classStars;

  final captain = Captain(
    uid: captainUid,
    name: name,
    email: cleanEmail,
    budget: startingBudget,
    stars: startingStars,
    playerCount: 1, // Pre-assigned slot deducted
    captainClass: captainClass,
    captainCost: classCost,
    captainStars: classStars,
  );

  // 3. Create pre-assigned captain player card in the database
  final captainPlayerId = 'captain_player_$captainUid';
  final captainPlayerCard = {
    'name': '$name (C)',
    'price': classCost,
    'stars': classStars,
    'ownerId': captainUid,
    'ownerName': name,
  };

  // Set the captain player card first
  await playersRef.child(captainPlayerId).set(captainPlayerCard);

  // Set the captain's account info
  await captainsRef.child(captainUid).set(captain.toMap());

  return captain;
}

/// Performs a transaction-safe player purchase.
/// Uses `runTransaction` on the DB root to prevent race conditions (e.g. two captains buying at the same time).
Future<String?> purchasePlayerTransaction(FirebaseDatabase db, String captainId, String playerId) async {
  final rootRef = db.ref();

  try {
    final transactionResult = await rootRef.runTransaction((Object? rootValue) {
      if (rootValue == null) {
        return Transaction.success(rootValue);
      }

      final rootMap = Map<dynamic, dynamic>.from(rootValue as Map);

      // Extract existing players and captains lists safely
      final playersMap = rootMap['players'] != null
          ? Map<dynamic, dynamic>.from(rootMap['players'] as Map)
          : {};
      final captainsMap = rootMap['captains'] != null
          ? Map<dynamic, dynamic>.from(rootMap['captains'] as Map)
          : {};

      if (!playersMap.containsKey(playerId)) {
        return Transaction.abort(); // Player not found
      }
      if (!captainsMap.containsKey(captainId)) {
        return Transaction.abort(); // Captain not found
      }

      final playerMap = Map<dynamic, dynamic>.from(playersMap[playerId] as Map);
      final captainMap = Map<dynamic, dynamic>.from(captainsMap[captainId] as Map);

      // TRANSACTION SAFETY CHECK 1: Ensure player isn't already owned
      if (playerMap['ownerId'] != null) {
        return Transaction.abort(); // Already purchased by someone else!
      }

      final double price = (playerMap['price'] as num).toDouble();
      final int stars = (playerMap['stars'] as num).toInt();

      final double currentBudget = (captainMap['budget'] as num).toDouble();
      final int currentStars = (captainMap['stars'] as num).toInt();
      final int currentCount = (captainMap['playerCount'] as num).toInt();

      // TRANSACTION SAFETY CHECK 2: Validate all budget, star, and team constraints
      if (currentCount >= 8) {
        return Transaction.abort(); // Squad size limit exceeded (max 8)
      }
      if (currentBudget < price) {
        return Transaction.abort(); // Captain budget exceeded (max 68M)
      }
      if (currentStars < stars) {
        return Transaction.abort(); // Captain stars limit exceeded (max 27)
      }

      // Apply safe, race-free transactional modifications
      playerMap['ownerId'] = captainId;
      playerMap['ownerName'] = captainMap['name'];

      captainMap['budget'] = currentBudget - price;
      captainMap['stars'] = currentStars - stars;
      captainMap['playerCount'] = currentCount + 1;

      // Map references updated back to root
      playersMap[playerId] = playerMap;
      captainsMap[captainId] = captainMap;
      rootMap['players'] = playersMap;
      rootMap['captains'] = captainsMap;

      return Transaction.success(rootMap);
    });

    if (transactionResult.committed) {
      return null; // Purchase completed successfully
    } else {
      return 'Bidding transaction failed. Player may have just been bought, or limits exceeded.';
    }
  } catch (e) {
    return 'Database error: ${e.toString()}';
  }
}

// ============================================================================
// APP ENTRY POINT
// ============================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // NOTE: On your local workspace, make sure to add your google-services.json (Android) or GoogleService-Info.plist (iOS).
  // The app will attempt to initialize default Firebase options. If not configured, configure manually.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization warning: $e. Ensure google-services.json is correctly placed.');
  }

  runApp(
    const ProviderScope(
      child: MercatixApp(),
    ),
  );
}

class MercatixApp extends StatelessWidget {
  const MercatixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mercatix Fantasy Auction',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121020), // Immersive dark fantasy background
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD700), // Regal Gold primary seed
          brightness: Brightness.dark,
          primary: const Color(0xFFFFD700), // Gold accents
          secondary: const Color(0xFF9C27B0), // Mystic Purple secondary accents
          background: const Color(0xFF121020),
          surface: const Color(0xFF25214D), // Soft dark purple card surfaces
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF25214D),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0x33FFD700), width: 1), // Subtle gold border
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1A3C),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// ============================================================================
// AUTHENTICATION & INITIALIZATION WRAPPER
// ============================================================================

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Seeds the database with default unbought fantasy players if it's currently empty
    final db = ref.read(dbProvider);
    seedDatabaseIfEmpty(db);
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentCaptainEmailProvider);
    if (email == null) {
      return const LoginRegisterScreen();
    }
    return const MainNavigationLayout();
  }
}

// ============================================================================
// LOGIN / REGISTRATION SCREEN
// ============================================================================

class LoginRegisterScreen extends ConsumerStatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  ConsumerState<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends ConsumerState<LoginRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isRegistering = false;
  bool _isLoading = false;

  // Pre-assigned Captain classes available during registration
  String _selectedClass = 'Warrior';
  double _classCost = 10.0;
  int _classStars = 4;

  void _setClassStats(String? className) {
    if (className == null) return;
    setState(() {
      _selectedClass = className;
      switch (className) {
        case 'Warrior':
          _classCost = 10.0;
          _classStars = 4;
          break;
        case 'Wizard':
          _classCost = 12.0;
          _classStars = 5;
          break;
        case 'Ranger':
          _classCost = 8.0;
          _classStars = 3;
          break;
        case 'Paladin':
          _classCost = 14.0;
          _classStars = 6;
          break;
      }
    });
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final db = ref.read(dbProvider);
    final email = _emailController.text.trim().toLowerCase();

    try {
      final existingCaptain = await lookupCaptainByEmail(db, email);

      if (_isRegistering) {
        if (existingCaptain != null) {
          _showSnackbar('Email is already registered. Please login.');
          setState(() {
            _isRegistering = false;
            _isLoading = false;
          });
          return;
        }

        // Register new captain with pre-assigned class card
        final newCaptain = await registerCaptain(
          db: db,
          name: _nameController.text.trim(),
          email: email,
          captainClass: _selectedClass,
          classCost: _classCost,
          classStars: _classStars,
        );

        ref.read(currentCaptainEmailProvider.notifier).state = newCaptain.email;
        ref.read(currentCaptainIdProvider.notifier).state = newCaptain.uid;
        _showSnackbar('Captain ${newCaptain.name} registered successfully!');
      } else {
        if (existingCaptain == null) {
          _showSnackbar('No registered Captain found with this email. Please register!');
          setState(() {
            _isRegistering = true;
            _isLoading = false;
          });
          return;
        }

        // Existing captain found, log them in
        ref.read(currentCaptainEmailProvider.notifier).state = existingCaptain.email;
        ref.read(currentCaptainIdProvider.notifier).state = existingCaptain.uid;
        _showSnackbar('Welcome back, Captain ${existingCaptain.name}!');
      }
    } catch (e) {
      _showSnackbar('Authentication Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF9C27B0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Beautiful app title / fantasy design
              const Icon(Icons.gavel, size: 80, color: Color(0xFFFFD700)),
              const SizedBox(height: 16),
              const Text(
                'MERCATIX',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 36,
                  fontWeight: FontWeight.black,
                  color: Color(0xFFFFD700),
                  letterSpacing: 4.0,
                ),
              ),
              const Text(
                'Fantasy Auction Arena',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 40),
              Card(
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isRegistering ? 'REGISTER CAPTAIN' : 'CAPTAIN LOGIN',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_isRegistering) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Captain Name',
                              prefixIcon: Icon(Icons.person, color: Color(0xFFFFD700)),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Enter name' : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Captain Email',
                            prefixIcon: Icon(Icons.email, color: Color(0xFFFFD700)),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Enter email';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(val.trim())) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        if (_isRegistering) ...[
                          const SizedBox(height: 24),
                          const Divider(color: Color(0x33FFD700)),
                          const SizedBox(height: 8),
                          const Text(
                            'Choose Captain Player Card (Pre-assigned):',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFFD700)),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedClass,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Warrior', child: Text('Warrior (⭐4, Cost: 10.0M)')),
                              DropdownMenuItem(value: 'Wizard', child: Text('Wizard (⭐5, Cost: 12.0M)')),
                              DropdownMenuItem(value: 'Ranger', child: Text('Ranger (⭐3, Cost: 8.0M)')),
                              DropdownMenuItem(value: 'Paladin', child: Text('Paladin (⭐6, Cost: 14.0M)')),
                            ],
                            onChanged: _setClassStats,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Starting Budget: ${68.0 - _classCost}M | Starting Stars: ${27 - _classStars}/27 (Captain counts as 1st Squad player)',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
                          ),
                        ],
                        const SizedBox(height: 28),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _handleAuth,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFD700),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  _isRegistering ? 'CREATE CAPTAIN TEAM' : 'ENTER AUCTION',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isRegistering = !_isRegistering;
                            });
                          },
                          child: Text(
                            _isRegistering ? 'Already registered? Login here' : 'New Captain? Register here',
                            style: const TextStyle(color: Color(0xFFFFD700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MAIN NAVIGATION LAYOUT
// ============================================================================

class MainNavigationLayout extends ConsumerStatefulWidget {
  const MainNavigationLayout({super.key});

  @override
  ConsumerState<MainNavigationLayout> createState() => _MainNavigationLayoutState();
}

class _MainNavigationLayoutState extends ConsumerState<MainNavigationLayout> {
  int _currentIndex = 0;

  final List<Widget> _views = const [
    MarketView(),
    MyTeamView(),
    StatisticsView(),
  ];

  @override
  Widget build(BuildContext context) {
    final captainAsync = ref.watch(currentCaptainProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MERCATIX'),
        actions: [
          // Elegant current captain info indicator
          captainAsync.when(
            data: (captain) {
              if (captain == null) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: Text(
                    '${captain.budget.toStringAsFixed(1)}M | ⭐${captain.stars}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: () {
              ref.read(currentCaptainEmailProvider.notifier).state = null;
              ref.read(currentCaptainIdProvider.notifier).state = null;
            },
          ),
        ],
      ),
      body: _views[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF1E1A3C),
        selectedItemColor: const Color(0xFFFFD700),
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'Marketplace',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield),
            label: 'My Squad',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Leaderboard',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 1. MARKET VIEW (MARKETPLACE)
// ============================================================================

class MarketView extends ConsumerWidget {
  const MarketView({super.key});

  /// Client-side business rule validation logic.
  /// Prevents any actions that violate the 8-player squad limit, 68M budget limit, or 27-star limit.
  bool _canPurchase(Captain captain, Player player) {
    if (player.ownerId != null) return false; // Already owned
    if (captain.playerCount >= 8) return false; // Limit: Max 8 players
    if (captain.budget < player.price) return false; // Limit: Max 68M budget
    if (captain.stars < player.stars) return false; // Limit: Max 27 stars
    return true;
  }

  /// Helper to return validation error message if buying a specific player is forbidden.
  String? _getPurchaseValidationReason(Captain captain, Player player) {
    if (player.ownerId != null) return 'Already Owned';
    if (captain.playerCount >= 8) return 'Squad full (8/8)';
    if (captain.budget < player.price) return 'Insufficient budget';
    if (captain.stars < player.stars) return 'Insufficient stars';
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captainAsync = ref.watch(currentCaptainProvider);
    final playersAsync = ref.watch(playersStreamProvider);

    return captainAsync.when(
      data: (captain) {
        if (captain == null) return const Center(child: Text('Captain record missing.'));

        return playersAsync.when(
          data: (players) {
            // Only show unbought players in the active market
            final unboughtPlayers = players.where((p) => p.ownerId == null).toList();

            if (unboughtPlayers.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text(
                        'Market is Sold Out!',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'All available fantasy draft players have been purchased by Captains.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: unboughtPlayers.length,
              itemBuilder: (context, index) {
                final player = unboughtPlayers[index];
                final allowed = _canPurchase(captain, player);
                final blockReason = _getPurchaseValidationReason(captain, player);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16.0),
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber[700]?.withOpacity(0.2),
                      radius: 28,
                      child: Text(
                        player.name.substring(0, 2).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFD700)),
                      ),
                    ),
                    title: Text(
                      player.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '${player.price.toStringAsFixed(1)}M',
                              style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 16),
                            Row(
                              children: List.generate(
                                player.stars,
                                (i) => const Icon(Icons.star, size: 16, color: Color(0xFFFFD700)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: SizedBox(
                      width: 110,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: allowed
                                ? () async {
                                    // Trigger transaction purchase
                                    final db = ref.read(dbProvider);
                                    final error = await purchasePlayerTransaction(db, captain.uid, player.id);
                                    if (context.mounted) {
                                      if (error != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(error),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Successfully signed ${player.name}!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD700),
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.white10,
                              disabledForegroundColor: Colors.white24,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('BUY', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          if (blockReason != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              blockReason,
                              style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading players: $err')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading captain info: $err')),
    );
  }
}

// ============================================================================
// 2. MY TEAM VIEW (MY SQUAD)
// ============================================================================

class MyTeamView extends ConsumerWidget {
  const MyTeamView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captainAsync = ref.watch(currentCaptainProvider);
    final playersAsync = ref.watch(playersStreamProvider);

    return captainAsync.when(
      data: (captain) {
        if (captain == null) return const Center(child: Text('Captain record missing.'));

        return playersAsync.when(
          data: (players) {
            // Filter players belonging to current captain
            final mySquad = players.where((p) => p.ownerId == captain.uid).toList();

            return Column(
              children: [
                // Captain's Team Summary Status Board
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: const Color(0xFF1E1A3C),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStatCard(
                        icon: Icons.monetization_on,
                        title: 'Remaining Budget',
                        value: '${captain.budget.toStringAsFixed(1)}M',
                        subtitle: 'Limit: 68.0M',
                      ),
                      _buildSummaryStatCard(
                        icon: Icons.star,
                        title: 'Remaining Stars',
                        value: '${captain.stars}',
                        subtitle: 'Limit: 27',
                      ),
                      _buildSummaryStatCard(
                        icon: Icons.groups,
                        title: 'Squad Size',
                        value: '${captain.playerCount}/8',
                        subtitle: 'Limit: 8',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: mySquad.isEmpty
                      ? const Center(child: Text('You do not have any players in your squad yet.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12.0),
                          itemCount: mySquad.length,
                          itemBuilder: (context, index) {
                            final player = mySquad[index];
                            final isCaptainCard = player.id == 'captain_player_${captain.uid}';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isCaptainCard ? const Color(0xFFFFD700) : Colors.purple[700],
                                  foregroundColor: isCaptainCard ? Colors.black : Colors.white,
                                  radius: 24,
                                  child: Icon(
                                    isCaptainCard ? Icons.verified_user : Icons.person,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  player.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isCaptainCard ? const Color(0xFFFFD700) : Colors.white,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Text('${player.price.toStringAsFixed(1)}M'),
                                    const SizedBox(width: 16),
                                    Row(
                                      children: List.generate(
                                        player.stars,
                                        (i) => const Icon(Icons.star, size: 14, color: Color(0xFFFFD700)),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: isCaptainCard
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFFFD700)),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'PRE-ASSIGNED',
                                          style: TextStyle(fontSize: 10, color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading squad players: $err')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading captain info: $err')),
    );
  }

  Widget _buildSummaryStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFFD700), size: 24),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.white70)),
            Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. STATISTICS VIEW (LEADERBOARD)
// ============================================================================

class StatisticsView extends ConsumerWidget {
  const StatisticsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captainsAsync = ref.watch(captainsStreamProvider);

    return captainsAsync.when(
      data: (captains) {
        if (captains.isEmpty) {
          return const Center(child: Text('No active Captain teams registered yet.'));
        }

        // Rank captains by the completeness of their squad, followed by remaining budget
        final rankedCaptains = List<Captain>.from(captains)
          ..sort((a, b) {
            final countComp = b.playerCount.compareTo(a.playerCount);
            if (countComp != 0) return countComp;
            return b.budget.compareTo(a.budget);
          });

        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Text(
                'CAPTAIN LEADERBOARD',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFFD700), letterSpacing: 1.5),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                itemCount: rankedCaptains.length,
                itemBuilder: (context, index) {
                  final captain = rankedCaptains[index];
                  final rank = index + 1;

                  // Decorative award colors for first three places
                  Color rankColor = Colors.white54;
                  if (rank == 1) rankColor = const Color(0xFFFFD700); // Gold
                  if (rank == 2) rankColor = const Color(0xFFC0C0C0); // Silver
                  if (rank == 3) rankColor = const Color(0xFFCD7F32); // Bronze

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // Rank Circle
                          CircleAvatar(
                            backgroundColor: rankColor,
                            radius: 18,
                            child: Text(
                              '$rank',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  captain.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Class: ${captain.captainClass} Captain',
                                  style: const TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                          // Stats Display Grid
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${captain.playerCount}/8 Players',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Budget: ${captain.budget.toStringAsFixed(1)}M',
                                style: const TextStyle(fontSize: 12, color: Color(0xFFFFD700)),
                              ),
                              Text(
                                'Stars Remaining: ${captain.stars}',
                                style: const TextStyle(fontSize: 11, color: Colors.white54),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading leaderboard: $err')),
    );
  }
}
