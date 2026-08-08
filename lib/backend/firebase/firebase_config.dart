import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyDfCPkJzBPar0tGg6ODNWdfGTWeEoMYrZU",
            authDomain: "sehatsatli-b0aa8.firebaseapp.com",
            projectId: "sehatsatli-b0aa8",
            storageBucket: "sehatsatli-b0aa8.firebasestorage.app",
            messagingSenderId: "1094819312551",
            appId: "1:1094819312551:web:ceb6d3f3f6a5990d22fc82",
            measurementId: "G-R8HSDXBP47"));
  } else {
    await Firebase.initializeApp();
  }
}
