import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../users/repo/users_repository.dart';
import '../../users/models/user_profile.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(usersRepoProvider).ensureCurrentUserProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (xfile == null) return;
    await ref.read(usersRepoProvider).uploadAvatar(File(xfile.path));
  }

  Future<void> _saveDisplayName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await ref.read(usersRepoProvider).updateDisplayName(name);
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _linkEmailPassword() async {
    final result = await showDialog<_EmailPassResult>(
      context: context,
      builder: (context) => const _EmailPassDialog(),
    );
    if (result == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final cred = EmailAuthProvider.credential(email: result.email, password: result.password);
    if (user.isAnonymous) {
      await user.linkWithCredential(cred);
    } else {
      await FirebaseAuth.instance.signInWithCredential(cred);
    }
    await ref.read(usersRepoProvider).ensureCurrentUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    final profileAsync = ref.watch(currentUserProfileStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: profileAsync.when(
        data: (profile) {
          _nameController.text = profile?.displayName ?? (authUser?.displayName ?? '');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: (profile?.photoUrl ?? authUser?.photoURL) != null
                      ? NetworkImage(profile?.photoUrl ?? authUser!.photoURL!)
                      : null,
                  child: (profile?.photoUrl ?? authUser?.photoURL) == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _pickAndUploadAvatar,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Avatar ändern'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Anzeigename'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _saveDisplayName, child: const Text('Speichern')),
              const Divider(height: 32),
              if (authUser != null) ...[
                ListTile(
                  title: const Text('User ID'),
                  subtitle: Text(authUser.uid),
                ),
                ListTile(
                  title: const Text('Authentifiziert als'),
                  subtitle: Text(authUser.isAnonymous
                      ? 'Anonym'
                      : (authUser.email ?? authUser.providerData.first.providerId)),
                ),
              ],
              const SizedBox(height: 8),
              if (authUser == null || authUser.isAnonymous)
                ElevatedButton.icon(
                  onPressed: _linkEmailPassword,
                  icon: const Icon(Icons.login),
                  label: const Text('Mit E-Mail anmelden/verbinden'),
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Abmelden'),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Fehler: $e')),
      ),
    );
  }
}

class _EmailPassDialog extends StatefulWidget {
  const _EmailPassDialog();

  @override
  State<_EmailPassDialog> createState() => _EmailPassDialogState();
}

class _EmailPassDialogState extends State<_EmailPassDialog> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  bool isLogin = true;
  String? error;

  Future<void> _submit() async {
    try {
      final email = emailCtrl.text.trim();
      final pass = passCtrl.text;
      if (email.isEmpty || pass.length < 6) {
        setState(() => error = 'Bitte gültige E-Mail und Passwort (min. 6 Zeichen) eingeben.');
        return;
      }
      if (isLogin) {
        Navigator.of(context).pop(_EmailPassResult(email: email, password: pass));
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
        Navigator.of(context).pop(_EmailPassResult(email: email, password: pass));
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isLogin ? 'Anmelden' : 'Registrieren'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'E-Mail')),
          TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Passwort'), obscureText: true),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.red))),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => isLogin = !isLogin),
          child: Text(isLogin ? 'Stattdessen registrieren' : 'Stattdessen anmelden'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Weiter')),
      ],
    );
  }
}

class _EmailPassResult {
  final String email;
  final String password;
  _EmailPassResult({required this.email, required this.password});
}