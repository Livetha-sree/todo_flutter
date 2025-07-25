import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo List App',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _handleSignIn(BuildContext context) async {
    GoogleSignIn googleSignIn = GoogleSignIn();
    try {
      GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TodoHomePage(
              userName: account.displayName ?? 'No Name',
              userEmail: account.email,
            ),
          ),
        );
      }
    } catch (error) {
      print('Login Error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-in failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade100,
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () => _handleSignIn(context),
          icon: const Icon(Icons.login),
          label: const Text("Sign in with Google"),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ),
    );
  }
}

class TodoHomePage extends StatefulWidget {
  final String userName;
  final String userEmail;

  const TodoHomePage({super.key, required this.userName, required this.userEmail});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> tasks = [];
  String searchQuery = '';
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    loadTasks();
  }

  void loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('tasks');
    if (saved != null) {
      setState(() {
        tasks = List<Map<String, dynamic>>.from(jsonDecode(saved));
      });
    }
  }

  void saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('tasks', jsonEncode(tasks));
  }

  void addOrUpdateTask({Map<String, dynamic>? task, int? index}) async {
    final titleController = TextEditingController(text: task?['title'] ?? '');
    final descriptionController = TextEditingController(text: task?['description'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index == null ? 'Add Task' : 'Edit Task'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTask = {
                'title': titleController.text,
                'description': descriptionController.text,
                'completed': task?['completed'] ?? false
              };
              setState(() {
                if (index == null) {
                  tasks.add(newTask);
                } else {
                  tasks[index] = newTask;
                }
                saveTasks();
              });
              Navigator.pop(context);
            },
            child: Text(index == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  void signOut() async {
    await GoogleSignIn().signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = tasks.where((task) {
      final title = task['title']?.toLowerCase() ?? '';
      final description = task['description']?.toLowerCase() ?? '';
      return title.contains(searchQuery.toLowerCase()) ||
          description.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome ${widget.userName}'),
        actions: [
          IconButton(onPressed: signOut, icon: const Icon(Icons.logout))
        ],
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'All Tasks'),
            Tab(icon: Icon(Icons.done), text: 'Completed'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => searchQuery = val),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                buildTaskList(filteredTasks),
                buildTaskList(filteredTasks.where((t) => t['completed']).toList()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => addOrUpdateTask(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget buildTaskList(List<Map<String, dynamic>> taskList) {
    if (taskList.isEmpty) {
      return const Center(child: Text('No tasks available.'));
    }
    return ListView.builder(
      itemCount: taskList.length,
      itemBuilder: (context, index) {
        final task = taskList[index];
        final actualIndex = tasks.indexOf(task);
        return Dismissible(
          key: Key(task['title'] + index.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) {
            setState(() {
              tasks.removeAt(actualIndex);
              saveTasks();
            });
          },
          child: ListTile(
            title: Text(task['title'] ?? ''),
            subtitle: Text(task['description'] ?? ''),
            leading: Checkbox(
              value: task['completed'] ?? false,
              onChanged: (val) {
                setState(() {
                  task['completed'] = val;
                  saveTasks();
                });
              },
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => addOrUpdateTask(task: task, index: actualIndex),
            ),
          ),
        );
      },
    );
  }
}
