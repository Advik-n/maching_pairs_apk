// memory_game_flutter_main.dart
// Single-file Flutter app implementing the Memory / Concentration game features requested.
// Replace your project's lib/main.dart with this file. Requires shared_preferences.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MemoryGameApp());
}

enum GameTheme { classic, blueNeon, redNeon }

enum CardDesign { packA, packB, packC }

class MemoryGameApp extends StatefulWidget {
  @override
  _MemoryGameAppState createState() => _MemoryGameAppState();
}

class _MemoryGameAppState extends State<MemoryGameApp> {
  GameTheme _theme = GameTheme.classic;
  CardDesign _cardDesign = CardDesign.packA;
  int _packSize = 12; // 12, 32, 48
  bool _useTimer = false;
  int _timeLimitSeconds = 60;
  int _allowedAttempts = 3;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Memory Match',
      theme: _buildThemeData(_theme),
      home: MainTabs(
        themeSelected: _theme,
        cardDesign: _cardDesign,
        packSize: _packSize,
        useTimer: _useTimer,
        timeLimitSeconds: _timeLimitSeconds,
        allowedAttempts: _allowedAttempts,
        onSettingsChanged: (GameTheme theme, CardDesign design, int pack, bool timerOn, int timeLimit, int attempts) {
          setState(() {
            _theme = theme;
            _cardDesign = design;
            _packSize = pack;
            _useTimer = timerOn;
            _timeLimitSeconds = timeLimit;
            _allowedAttempts = attempts;
          });
        },
      ),
    );
  }

  ThemeData _buildThemeData(GameTheme t) {
    switch (t) {
      case GameTheme.blueNeon:
        return ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
        );
      case GameTheme.redNeon:
        return ThemeData(
          primarySwatch: Colors.red,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
        );
      case GameTheme.classic:
      default:
        return ThemeData(
          primarySwatch: Colors.indigo,
          brightness: Brightness.light,
        );
    }
  }
}

class MainTabs extends StatefulWidget {
  final GameTheme themeSelected;
  final CardDesign cardDesign;
  final int packSize;
  final bool useTimer;
  final int timeLimitSeconds;
  final int allowedAttempts;
  final void Function(GameTheme, CardDesign, int, bool, int, int) onSettingsChanged;

  MainTabs({
    required this.themeSelected,
    required this.cardDesign,
    required this.packSize,
    required this.useTimer,
    required this.timeLimitSeconds,
    required this.allowedAttempts,
    required this.onSettingsChanged,
  });

  @override
  _MainTabsState createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      GamePage(
        theme: widget.themeSelected,
        cardDesign: widget.cardDesign,
        packSize: widget.packSize,
        useTimer: widget.useTimer,
        timeLimitSeconds: widget.timeLimitSeconds,
        allowedAttempts: widget.allowedAttempts,
      ),
      PacksPage(selected: widget.packSize, onChange: (p) => widget.onSettingsChanged(widget.themeSelected, widget.cardDesign, p, widget.useTimer, widget.timeLimitSeconds, widget.allowedAttempts)),
      ThemesPage(theme: widget.themeSelected, design: widget.cardDesign, onChange: (th, des) => widget.onSettingsChanged(th, des, widget.packSize, widget.useTimer, widget.timeLimitSeconds, widget.allowedAttempts)),
      LeaderboardPage(),
      SettingsPage(
        useTimer: widget.useTimer,
        timeLimitSeconds: widget.timeLimitSeconds,
        allowedAttempts: widget.allowedAttempts,
        onChange: (timerOn, seconds, attempts) => widget.onSettingsChanged(widget.themeSelected, widget.cardDesign, widget.packSize, timerOn, seconds, attempts),
      ),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.play_arrow), label: 'Play'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_on), label: 'Packs'),
          BottomNavigationBarItem(icon: Icon(Icons.palette), label: 'Themes'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Top 10'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ------------------ Game Logic Page ------------------
class GamePage extends StatefulWidget {
  final GameTheme theme;
  final CardDesign cardDesign;
  final int packSize;
  final bool useTimer;
  final int timeLimitSeconds;
  final int allowedAttempts;

  GamePage({required this.theme, required this.cardDesign, required this.packSize, required this.useTimer, required this.timeLimitSeconds, required this.allowedAttempts});

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  late List<_CardModel> cards;
  _CardModel? firstSelected;
  _CardModel? secondSelected;
  bool busy = false;
  int score = 0;
  int attemptsRemaining = 3;
  Timer? gameTimer;
  int timeLeft = 0;
  bool showAllInitially = true;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  @override
  void didUpdateWidget(covariant GamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If settings changed, start a new game
    if (oldWidget.packSize != widget.packSize || oldWidget.cardDesign != widget.cardDesign || oldWidget.theme != widget.theme || oldWidget.timeLimitSeconds != widget.timeLimitSeconds || oldWidget.allowedAttempts != widget.allowedAttempts || oldWidget.useTimer != widget.useTimer) {
      _newGame();
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  void _newGame() {
    // initialize
    attemptsRemaining = widget.allowedAttempts;
    score = 0;
    firstSelected = null;
    secondSelected = null;
    busy = false;
    timeLeft = widget.useTimer ? widget.timeLimitSeconds : 0;
    gameTimer?.cancel();
    cards = _generateCards(widget.packSize);
    // Show all briefly
    setState(() {
      showAllInitially = true;
    });
    Future.delayed(Duration(milliseconds: 300), () {
      setState(() {
        showAllInitially = false;
      });
      if (widget.useTimer) _startTimer();
    });
  }

  List<_CardModel> _generateCards(int totalCards) {
    assert(totalCards % 2 == 0);
    final pairCount = totalCards ~/ 2;
    final rand = Random();
    final icons = _availableIcons();
    // pick pairCount distinct icons
    icons.shuffle(rand);
    final selected = icons.take(pairCount).toList();
    List<_CardModel> list = [];
    int id = 0;
    for (var icon in selected) {
      list.add(_CardModel(id: id++, content: icon));
      list.add(_CardModel(id: id++, content: icon));
    }
    list.shuffle(rand);
    return list;
  }

  List<IconData> _availableIcons() {
    // a simple big pool
    return [
      Icons.ac_unit,
      Icons.access_alarm,
      Icons.accessibility,
      Icons.account_balance,
      Icons.ad_units,
      Icons.airplanemode_active,
      Icons.anchor,
      Icons.android,
      Icons.api,
      Icons.beach_access,
      Icons.bedtime,
      Icons.cake,
      Icons.camera_alt,
      Icons.cloud,
      Icons.coffee,
      Icons.directions_bike,
      Icons.drag_handle,
      Icons.eco,
      Icons.face,
      Icons.fastfood,
      Icons.golf_course,
      Icons.hail,
      Icons.headphones,
      Icons.icecream,
      Icons.keyboard,
      Icons.light_mode,
      Icons.lock,
      Icons.mail,
      Icons.motorcycle,
      Icons.nature,
      Icons.opacity,
      Icons.palette,
      Icons.pool,
      Icons.rocket,
      Icons.sailing,
      Icons.sanitizer,
      Icons.school,
      Icons.star,
      Icons.terrain,
      Icons.videogame_asset,
      Icons.wb_sunny,
      Icons.watch,
    ];
  }

  void _startTimer() {
    timeLeft = widget.timeLimitSeconds;
    gameTimer?.cancel();
    gameTimer = Timer.periodic(Duration(seconds: 1), (t) {
      if (timeLeft <= 0) {
        t.cancel();
        _onLose('Time\'s up');
      } else {
        setState(() => timeLeft -= 1);
      }
    });
  }

  void _onCardTap(_CardModel card) async {
    if (busy) return;
    if (card.matched || card.revealed) return;
    setState(() => card.revealed = true);

    if (firstSelected == null) {
      firstSelected = card;
      return;
    }

    secondSelected = card;
    busy = true;

    if (firstSelected!.content == secondSelected!.content) {
      // match
      await Future.delayed(Duration(milliseconds: 300));
      setState(() {
        firstSelected!.matched = true;
        secondSelected!.matched = true;
        score += 10;
        firstSelected = null;
        secondSelected = null;
        busy = false;
      });
      // check win
      if (cards.every((c) => c.matched)) {
        gameTimer?.cancel();
        _onWin();
      }
    } else {
      // mismatch
      attemptsRemaining -= 1;
      await Future.delayed(Duration(milliseconds: 600));
      setState(() {
        firstSelected!.revealed = false;
        secondSelected!.revealed = false;
        firstSelected = null;
        secondSelected = null;
        busy = false;
      });
      if (attemptsRemaining <= 0) {
        gameTimer?.cancel();
        _onLose('No attempts left');
      }
    }
  }

  Future<void> _onWin() async {
    final timeTaken = widget.useTimer ? (widget.timeLimitSeconds - timeLeft) : 0;
    final record = GameRecord(date: DateTime.now(), score: score, packSize: widget.packSize, timeTaken: timeTaken);
    await Leaderboard.addRecord(record);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('You Win!'),
        content: Text('Score: $score\nPack: ${widget.packSize}\nTime: ${timeTaken}s'),
        actions: [
          TextButton(onPressed: () { Navigator.of(context).pop(); _newGame(); }, child: Text('Play Again')),
        ],
      ),
    );
  }

  Future<void> _onLose(String reason) async {
    final record = GameRecord(date: DateTime.now(), score: score, packSize: widget.packSize, timeTaken: 0);
    await Leaderboard.addRecord(record);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('You Lose'),
        content: Text('Reason: $reason\nScore: $score'),
        actions: [
          TextButton(onPressed: () { Navigator.of(context).pop(); _newGame(); }, child: Text('Try Again')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.packSize == 12 ? 4 : 8;
    final theme = widget.theme;
    return SafeArea(
      child: Column(
        children: [
          SizedBox(height: 8),
          _buildTopBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 120, childAspectRatio: 0.62, crossAxisSpacing: 6, mainAxisSpacing: 6),
                itemBuilder: (context, index) {
                  final c = cards[index];
                  return MemoryCardWidget(
                    model: c,
                    theme: theme,
                    design: widget.cardDesign,
                    showAll: showAllInitially,
                    onTap: () => _onCardTap(c),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Row(
        children: [
          Text('Score: $score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(width: 12),
          Text('Attempts: $attemptsRemaining', style: TextStyle(fontSize: 16)),
          SizedBox(width: 12),
          if (widget.useTimer) Text('Time: $timeLeft', style: TextStyle(fontSize: 16)),
          Spacer(),
          ElevatedButton.icon(onPressed: _newGame, icon: Icon(Icons.refresh), label: Text('Restart')),
        ],
      ),
    );
  }
}

class _CardModel {
  final int id;
  final IconData content;
  bool revealed = false;
  bool matched = false;

  _CardModel({required this.id, required this.content});
}

// ------------------ Memory Card Widget with flip animation ------------------
class MemoryCardWidget extends StatefulWidget {
  final _CardModel model;
  final GameTheme theme;
  final CardDesign design;
  final bool showAll;
  final VoidCallback onTap;

  MemoryCardWidget({required this.model, required this.theme, required this.design, required this.showAll, required this.onTap});

  @override
  _MemoryCardWidgetState createState() => _MemoryCardWidgetState();
}

class _MemoryCardWidgetState extends State<MemoryCardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 180));
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant MemoryCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // control flip based on model.revealed or showAll
    if (widget.showAll || widget.model.revealed || widget.model.matched) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowBox = _boxDecorationForTheme(widget.theme, widget.design);
    return GestureDetector(
      onTap: () {
        if (!widget.model.revealed && !widget.model.matched && !widget.showAll) widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _flipAnim,
        builder: (context, child) {
          final isFront = _flipAnim.value > 0.5;
          final angle = _flipAnim.value * pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(angle),
            child: Container(
              decoration: glowBox,
              child: isFront ? _buildFace(widget.model.content) : _buildBack(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFace(IconData icon) {
    return Center(child: Icon(icon, size: 36));
  }

  Widget _buildBack() {
    // design variations
    switch (widget.design) {
      case CardDesign.packA:
        return Center(child: Icon(Icons.casino, size: 32));
      case CardDesign.packB:
        return Center(child: Icon(Icons.bubble_chart, size: 32));
      case CardDesign.packC:
        return Center(child: Icon(Icons.layers, size: 32));
    }
  }
}

BoxDecoration _boxDecorationForTheme(GameTheme theme, CardDesign design) {
  switch (theme) {
    case GameTheme.blueNeon:
      return BoxDecoration(
        color: Colors.blue.shade900,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.9), blurRadius: 12, spreadRadius: 1)],
      );
    case GameTheme.redNeon:
      return BoxDecoration(
        color: Colors.red.shade900,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.9), blurRadius: 12, spreadRadius: 1)],
      );
    case GameTheme.classic:
    default:
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      );
  }
}

// ------------------ Packs Page ------------------
class PacksPage extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChange;

  PacksPage({required this.selected, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Choose Card Pack')),
      body: ListView(
        children: [
          ListTile(title: Text('12 Cards (6 pairs)'), trailing: selected == 12 ? Icon(Icons.check) : null, onTap: () => onChange(12)),
          ListTile(title: Text('32 Cards (16 pairs)'), trailing: selected == 32 ? Icon(Icons.check) : null, onTap: () => onChange(32))
        ],
      ),
    );
  }
}

// ------------------ Themes Page ------------------
class ThemesPage extends StatelessWidget {
  final GameTheme theme;
  final CardDesign design;
  final void Function(GameTheme, CardDesign) onChange;

  ThemesPage({required this.theme, required this.design, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Themes & Card Design')),
      body: Column(
        children: [
          ListTile(title: Text('Classic'), trailing: theme == GameTheme.classic ? Icon(Icons.check) : null, onTap: () => onChange(GameTheme.classic, design)),
          ListTile(title: Text('Blue Neon'), trailing: theme == GameTheme.blueNeon ? Icon(Icons.check) : null, onTap: () => onChange(GameTheme.blueNeon, design)),
          ListTile(title: Text('Red Neon'), trailing: theme == GameTheme.redNeon ? Icon(Icons.check) : null, onTap: () => onChange(GameTheme.redNeon, design)),
          Divider(),
          ListTile(title: Text('Card Pack A (casino)'), trailing: design == CardDesign.packA ? Icon(Icons.check) : null, onTap: () => onChange(theme, CardDesign.packA)),
          ListTile(title: Text('Card Pack B (bubbles)'), trailing: design == CardDesign.packB ? Icon(Icons.check) : null, onTap: () => onChange(theme, CardDesign.packB)),
          ListTile(title: Text('Card Pack C (layers)'), trailing: design == CardDesign.packC ? Icon(Icons.check) : null, onTap: () => onChange(theme, CardDesign.packC)),
        ],
      ),
    );
  }
}

// ------------------ Leaderboard ------------------
class LeaderboardPage extends StatefulWidget {
  @override
  _LeaderboardPageState createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<GameRecord> records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    records = await Leaderboard.getTop(10);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Top 10 Scores')),
      body: ListView.builder(
        itemCount: records.length,
        itemBuilder: (c, i) {
          final r = records[i];
          return ListTile(
            leading: CircleAvatar(child: Text('${i+1}')),
            title: Text('Score: ${r.score}'),
            subtitle: Text('Pack: ${r.packSize} • Date: ${r.date.toLocal().toString().split(".").first}'),
            trailing: r.timeTaken > 0 ? Text('${r.timeTaken}s') : null,
          );
        },
      ),
    );
  }
}

class GameRecord {
  final DateTime date;
  final int score;
  final int packSize;
  final int timeTaken;

  GameRecord({required this.date, required this.score, required this.packSize, required this.timeTaken});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'score': score,
        'packSize': packSize,
        'timeTaken': timeTaken,
      };

  static GameRecord fromJson(Map<String, dynamic> j) => GameRecord(date: DateTime.parse(j['date'] as String), score: j['score'] as int, packSize: j['packSize'] as int, timeTaken: j['timeTaken'] as int);
}

class Leaderboard {
  static const _key = 'memory_leaderboard_v1';

  static Future<void> addRecord(GameRecord r) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(r.toJson()));
    // sort top by score desc and keep top 50
    final parsed = raw.map((s) => GameRecord.fromJson(jsonDecode(s))).toList();
    parsed.sort((a, b) => b.score.compareTo(a.score));
    final limited = parsed.take(50).map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, limited);
  }

  static Future<List<GameRecord>> getTop(int n) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final parsed = raw.map((s) => GameRecord.fromJson(jsonDecode(s))).toList();
    parsed.sort((a, b) => b.score.compareTo(a.score));
    return parsed.take(n).toList();
  }
}

// ------------------ Settings Page ------------------
class SettingsPage extends StatefulWidget {
  final bool useTimer;
  final int timeLimitSeconds;
  final int allowedAttempts;
  final void Function(bool, int, int) onChange;

  SettingsPage({required this.useTimer, required this.timeLimitSeconds, required this.allowedAttempts, required this.onChange});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _useTimer;
  late int _timeLimit;
  late int _attempts;

  @override
  void initState() {
    super.initState();
    _useTimer = widget.useTimer;
    _timeLimit = widget.timeLimitSeconds;
    _attempts = widget.allowedAttempts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(12),
        children: [
          SwitchListTile(value: _useTimer, onChanged: (v) => setState(() => _useTimer = v), title: Text('Enable Timer')),
          if (_useTimer)
            ListTile(
              title: Text('Time limit (seconds)'),
              subtitle: Slider(value: _timeLimit.toDouble(), min: 10, max: 600, divisions: 59, label: '$_timeLimit', onChanged: (v) => setState(() => _timeLimit = v.round())),
            ),
          ListTile(
            title: Text('Allowed attempts (mismatches before losing)'),
            subtitle: Slider(value: _attempts.toDouble(), min: 1, max: 10, divisions: 9, label: '$_attempts', onChanged: (v) => setState(() => _attempts = v.round())),
          ),
          SizedBox(height: 12),
          ElevatedButton(onPressed: () { widget.onChange(_useTimer, _timeLimit, _attempts); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Settings saved — go to Play to start'))); }, child: Text('Save Settings')),
        ],
      ),
    );
  }
}


