import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'models/document.dart';
import 'services/config_service.dart';
import 'services/database_service.dart';
import 'widgets/markdown_editor.dart';

// Mock user model
class User {
  final String id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});
}

// Authentication state
class AuthState extends ChangeNotifier {
  User? _currentUser;
  bool get isAuthenticated => _currentUser != null;
  User? get currentUser => _currentUser;

  void login(String email, String password) {
    // Mock login
    _currentUser = User(
      id: const Uuid().v4(),
      name: 'Test User',
      email: email,
    );
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}

// Document state management
class DocumentState extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final List<Document> _documents = [];
  Document? _currentDocument;
  bool _loading = false;

  List<Document> get documents => List.unmodifiable(_documents);
  Document? get currentDocument => _currentDocument;
  bool get isLoading => _loading;

  Future<void> loadDocuments(String userId) async {
    _loading = true;
    notifyListeners();

    try {
      final docs = await _db.getDocuments(userId);
      _documents.clear();
      _documents.addAll(docs);
    } catch (e) {
      print('Error loading documents: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addDocument(Document document) async {
    try {
      await _db.insertDocument(document);
      _documents.add(document);
      notifyListeners();
    } catch (e) {
      print('Error adding document: $e');
    }
  }

  Future<void> updateDocument(Document document) async {
    try {
      await _db.updateDocument(document);
      final index = _documents.indexWhere((d) => d.uuid == document.uuid);
      if (index != -1) {
        _documents[index] = document;
        if (_currentDocument?.uuid == document.uuid) {
          _currentDocument = document;
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error updating document: $e');
    }
  }

  void setCurrentDocument(Document? document) {
    _currentDocument = document;
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final configService = ConfigService();
  await configService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => DocumentState()),
      ],
      child: const LegalIDEApp(),
    ),
  );
}

class LegalIDEApp extends StatelessWidget {
  const LegalIDEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LegalIDE',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        if (authState.isAuthenticated) {
          return const MainLayout();
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  context.read<AuthState>().login(
                        _emailController.text,
                        _passwordController.text,
                      );
                },
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LegalIDE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthState>().logout(),
          ),
        ],
      ),
      body: const ResponsiveLayout(),
    );
  }
}

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return const WideLayout();
        }
        return const NarrowLayout();
      },
    );
  }
}

class WideLayout extends StatelessWidget {
  const WideLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 300,
          child: DocumentList(),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: Consumer<DocumentState>(
            builder: (context, docState, _) {
              return docState.currentDocument != null
                  ? const DocumentEditor()
                  : const Center(child: Text('Select a document'));
            },
          ),
        ),
        const VerticalDivider(width: 1),
        const SizedBox(
          width: 250,
          child: DocumentOutline(),
        ),
      ],
    );
  }
}

class NarrowLayout extends StatelessWidget {
  const NarrowLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentState>(
      builder: (context, docState, _) {
        if (docState.currentDocument == null) {
          return const DocumentList();
        }
        return const DocumentEditor();
      },
    );
  }
}

class DocumentList extends StatelessWidget {
  const DocumentList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<DocumentState>(
        builder: (context, docState, _) {
          if (docState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return ListView.builder(
            itemCount: docState.documents.length,
            itemBuilder: (context, index) {
              final doc = docState.documents[index];
              return ListTile(
                title: Text(doc.title),
                subtitle: Text(doc.type),
                selected: doc == docState.currentDocument,
                onTap: () => docState.setCurrentDocument(doc),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final userId = context.read<AuthState>().currentUser!.id;
          context.read<DocumentState>().addDocument(
                Document(
                  title: 'New Document',
                  type: 'Policy',
                  content: '# New Document\n\nStart writing here...',
                  userId: userId,
                ),
              );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class DocumentEditor extends StatefulWidget {
  const DocumentEditor({super.key});

  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> {
  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentState>(
      builder: (context, docState, _) {
        final doc = docState.currentDocument;
        if (doc == null) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: MarkdownEditor(
                  initialValue: doc.content,
                  onChanged: (value) {
                    docState.updateDocument(
                      doc.copyWith(content: value),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DocumentOutline extends StatelessWidget {
  const DocumentOutline({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentState>(
      builder: (context, docState, _) {
        final doc = docState.currentDocument;
        if (doc == null) return const SizedBox();

        // Extract headers from markdown content
        final headers = RegExp(r'^#{1,6}\s(.+)$', multiLine: true)
            .allMatches(doc.content)
            .map((match) {
          final headerText = match.group(1) ?? '';
          final level = match.group(0)?.indexOf(' ') ?? 1;
          return _OutlineItem(text: headerText, level: level);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: headers.length,
          itemBuilder: (context, index) {
            final header = headers[index];
            return Padding(
              padding: EdgeInsets.only(left: (header.level - 1) * 16.0),
              child: Text(
                header.text,
                style: TextStyle(
                  fontSize: 16.0 - header.level,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OutlineItem {
  final String text;
  final int level;

  _OutlineItem({required this.text, required this.level});
}
