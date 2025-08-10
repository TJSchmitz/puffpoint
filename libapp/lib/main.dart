import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const skipInit = bool.fromEnvironment(
    'SKIP_FIREBASE_INIT',
    defaultValue: false,
  );
  const useEmulators = bool.fromEnvironment(
    'USE_EMULATORS',
    defaultValue: false,
  );
  const functionsPort = int.fromEnvironment('FUNCTIONS_PORT', defaultValue: 5001);

  if (!skipInit) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (useEmulators) {
      final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseStorage.instance.useStorageEmulator(host, 9199);
      FirebaseFunctions.instance.useFunctionsEmulator(host, functionsPort);
    }

    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    // Anonymous sign-in
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  runApp(const ProviderScope(child: PuffPointApp()));
}
