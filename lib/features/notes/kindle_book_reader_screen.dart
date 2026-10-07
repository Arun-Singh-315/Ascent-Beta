import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/color_tokens.dart';
import '../../core/providers/settings_provider.dart';

enum KindleTheme {
  sepia('Warm Sepia', Color(0xFFFBF0D9), Color(0xFF2C2523), Color(0xFFD6C8AC)),
  dark('Dark OLED', Color(0xFF121212), Color(0xFFE2E8F0), Color(0xFF2A2A2A)),
  light('Crisp Day', Color(0xFFFFFFFF), Color(0xFF1A1A1A), Color(0xFFE5E7EB)),
  sage('Forest Sage', Color(0xFF162019), Color(0xFFD1E7DD), Color(0xFF26382C));

  final String label;
  final Color bg;
  final Color text;
  final Color border;

  const KindleTheme(this.label, this.bg, this.text, this.border);
}

class KindleBookReaderScreen extends ConsumerStatefulWidget {
  final String? initialPdfPath;
  final String? initialTitle;

  const KindleBookReaderScreen({
    super.key,
    this.initialPdfPath,
    this.initialTitle,
  });

  @override
  ConsumerState<KindleBookReaderScreen> createState() => _KindleBookReaderScreenState();
}

class _KindleBookReaderScreenState extends ConsumerState<KindleBookReaderScreen> {
  String? _pdfPath;
  String _docTitle = 'Study Document';
  int _currentPage = 1;
  int _totalPages = 1;
  bool _showHud = true;
  KindleTheme _theme = KindleTheme.sepia;
  PDFViewController? _pdfViewController;
  bool _isReady = false;

  // Fallback / Built-in study notes when no PDF is picked yet
  int _builtinPageIndex = 0;
  static const List<Map<String, String>> _sampleStudyChapters = [
    {
      'title': 'Chapter 1: Spring Boot 3 Core & Auto-Configuration',
      'content': '''# Spring Boot 3 Architecture & Microservices

### 1. Spring Boot Core Philosophy
Spring Boot provides opinionated defaults on top of the Spring Framework, eliminating boilerplate XML/Java config while enabling production-ready metrics.

Key Highlights:
• @SpringBootApplication combines @Configuration, @EnableAutoConfiguration, and @ComponentScan.
• Spring Factories Loader scans META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports.
• Condition annotations like @ConditionalOnClass and @ConditionalOnMissingBean resolve beans dynamically at startup.

### 2. Dependency Injection & Inversion of Control (IoC)
• ApplicationContext is the central engine managing bean lifecycles.
• Preferred injection: Constructor injection ensures immutability, easier unit testing with Mockito, and prevents NullPointerExceptions.

```java
@Service
public class JournalEntryService {
    private final JournalEntryRepository repository;

    public JournalEntryService(JournalEntryRepository repository) {
        this.repository = repository;
    }
}
```

### 3. Production Readiness
• Spring Boot Actuator exposes health, metrics, info, and prometheus endpoints.
• Virtual Threads (Java 21+) dramatically scale I/O bound HTTP throughput by decoupling threads from OS kernel threads.
''',
    },
    {
      'title': 'Chapter 2: MongoDB, Spring Data & Relationships',
      'content': '''# MongoDB Integration & Document Design

### 1. MongoDB Document Modeling
Unlike relational SQL tables with strict foreign keys, MongoDB favors embedding for high-speed read access and referencing (@DBRef or manual ObjectId references) for high cardinality data.

Key Annotations:
• @Document(collection = "journal_entries")
• @Id private ObjectId id;
• @Indexed(unique = true) on email/username fields.
• @DBRef creates lazy or eager references to other collections.

```java
@Document(collection = "users")
public class User {
    @Id
    private ObjectId id;
    @Indexed(unique = true)
    private String userName;
    private String password;
    @DBRef
    private List<JournalEntry> journalEntries = new ArrayList<>();
}
```

### 2. Spring Data MongoTemplate vs MongoRepository
• MongoRepository provides high-level CRUD and derived queries:
  findByNameAndAge(String name, int age)
• MongoTemplate provides low-level Criteria and Query objects for atomic updates and complex aggregation pipelines:
  Query query = new Query(Criteria.where("user").is(user));
  Update update = new Update().push("journalEntries", entry);
  mongoTemplate.updateFirst(query, update, User.class);
''',
    },
    {
      'title': 'Chapter 3: Spring Security 6 & JWT Auth Architecture',
      'content': '''# Modern Spring Security 6 & Stateless Auth

### 1. Security Filter Chain Architecture
Spring Security intercepts all inbound requests via the DelegatingFilterProxy and SecurityFilterChain.

Key Components:
• SecurityFilterChain bean configuration with http.csrf().disable() and SessionCreationPolicy.STATELESS.
• JwtAuthenticationFilter parses Authorization header:
  `Bearer eyJhbGciOi...`
• UserDetailsService loads user details from DB and returns UserDetails with GrantedAuthorities.
• SecurityContextHolder holds Authentication in ThreadLocal context.

```java
@Bean
public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    return http
        .csrf(AbstractHttpConfigurer::disable)
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/auth/**", "/public/**").permitAll()
            .anyRequest().authenticated()
        )
        .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
        .build();
}
```

### 2. Best Practices
• Never store raw passwords: Use BCryptPasswordEncoder with cost factor 12.
• Protect against timing attacks using constant-time string comparisons for tokens.
''',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pdfPath = widget.initialPdfPath;
    _docTitle = widget.initialTitle ?? 'Spring Boot Mastery Notes';
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final themeName = prefs.getString('ascent_kindle_theme') ?? 'sepia';
    setState(() {
      _theme = KindleTheme.values.firstWhere(
        (t) => t.name == themeName,
        orElse: () => KindleTheme.sepia,
      );
    });
  }

  Future<void> _setTheme(KindleTheme theme) async {
    HapticFeedback.selectionClick();
    setState(() => _theme = theme);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('ascent_kindle_theme', theme.name);
  }

  Future<void> _pickPdfFile() async {
    try {
      HapticFeedback.lightImpact();
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (picked != null && picked.path != null) {
        setState(() {
          _pdfPath = picked.path;
          _docTitle = picked.name;
          _currentPage = 1;
          _isReady = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  void _toggleHud() {
    HapticFeedback.selectionClick();
    setState(() {
      _showHud = !_showHud;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPdf = _pdfPath != null && File(_pdfPath!).existsSync();

    return Scaffold(
      backgroundColor: _theme.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Main Reader Viewport ──────────────────────────────────────────
            GestureDetector(
              onTap: _toggleHud,
              child: hasPdf
                  ? PDFView(
                      filePath: _pdfPath,
                      enableSwipe: true,
                      swipeHorizontal: true,
                      autoSpacing: true,
                      pageFling: true,
                      pageSnap: true,
                      defaultPage: _currentPage - 1,
                      fitPolicy: FitPolicy.BOTH,
                      nightMode: _theme == KindleTheme.dark,
                      onRender: (pages) {
                        setState(() {
                          _totalPages = pages ?? 1;
                          _isReady = true;
                        });
                      },
                      onViewCreated: (controller) {
                        _pdfViewController = controller;
                      },
                      onPageChanged: (page, total) {
                        setState(() {
                          _currentPage = (page ?? 0) + 1;
                          _totalPages = total ?? 1;
                        });
                      },
                    )
                  : _BuiltinKindleReader(
                      theme: _theme,
                      chapters: _sampleStudyChapters,
                      pageIndex: _builtinPageIndex,
                      onPageChanged: (idx) {
                        setState(() => _builtinPageIndex = idx);
                      },
                      onPickPdf: _pickPdfFile,
                    ),
            ),

            if (hasPdf && !_isReady)
              Center(
                child: CircularProgressIndicator(
                  color: _theme.text.withValues(alpha: 0.6),
                ),
              ),

            // ── Top Kindle Header HUD ──────────────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              top: _showHud ? 0 : -80,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _theme.bg.withValues(alpha: 0.95),
                  border: Border(bottom: BorderSide(color: _theme.border, width: 0.8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: _theme.text, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _docTitle,
                            style: GoogleFonts.plusJakartaSans(
                              color: _theme.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            hasPdf ? 'Local PDF Notes' : 'Bundled Study Notes · Swipe left/right',
                            style: GoogleFonts.jetBrainsMono(
                              color: _theme.text.withValues(alpha: 0.65),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Open PDF file from phone',
                      icon: Icon(Icons.folder_open_rounded, color: _theme.text, size: 22),
                      onPressed: _pickPdfFile,
                    ),
                    IconButton(
                      tooltip: 'Reading Themes',
                      icon: Icon(Icons.palette_outlined, color: _theme.text, size: 22),
                      onPressed: () => _showThemePicker(context),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom Kindle Footer HUD ───────────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              bottom: _showHud ? 0 : -90,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _theme.bg.withValues(alpha: 0.96),
                  border: Border(top: BorderSide(color: _theme.border, width: 0.8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          hasPdf
                              ? 'Page $_currentPage of $_totalPages'
                              : 'Chapter ${_builtinPageIndex + 1} of ${_sampleStudyChapters.length}',
                          style: GoogleFonts.jetBrainsMono(
                            color: _theme.text,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          hasPdf
                              ? '${((_currentPage / (_totalPages > 0 ? _totalPages : 1)) * 100).toInt()}% read'
                              : '${(((_builtinPageIndex + 1) / _sampleStudyChapters.length) * 100).toInt()}% read',
                          style: GoogleFonts.jetBrainsMono(
                            color: _theme.text.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (hasPdf && _totalPages > 1)
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: _theme.text,
                          inactiveTrackColor: _theme.border,
                          thumbColor: _theme.text,
                        ),
                        child: Slider(
                          value: _currentPage.toDouble().clamp(1.0, _totalPages.toDouble()),
                          min: 1.0,
                          max: _totalPages.toDouble(),
                          onChanged: (val) {
                            final pageNum = val.round();
                            _pdfViewController?.setPage(pageNum - 1);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _theme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reading Theme',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _theme.text,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: KindleTheme.values.map((t) {
                  final isSelected = t == _theme;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _setTheme(t);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: t.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? context.accentPrimary : t.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: t.text,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: t.text,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuiltinKindleReader extends StatelessWidget {
  final KindleTheme theme;
  final List<Map<String, String>> chapters;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPickPdf;

  const _BuiltinKindleReader({
    required this.theme,
    required this.chapters,
    required this.pageIndex,
    required this.onPageChanged,
    required this.onPickPdf,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      itemCount: chapters.length,
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) {
        final chapter = chapters[index];

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 68, 26, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Open Local PDF Callout
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.border.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.border, width: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.file_open_rounded, size: 18, color: theme.text),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Want to read your own PDF? Tap here to select any PDF on your phone.',
                        style: TextStyle(fontSize: 11.5, color: theme.text.withValues(alpha: 0.8)),
                      ),
                    ),
                    TextButton(
                      onPressed: onPickPdf,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: theme.text,
                      ),
                      child: const Text('Open PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),

              Text(
                chapter['title'] ?? '',
                style: GoogleFonts.merriweather(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: theme.text,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                chapter['content'] ?? '',
                style: GoogleFonts.sourceSerif4(
                  fontSize: 15,
                  height: 1.6,
                  color: theme.text.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
