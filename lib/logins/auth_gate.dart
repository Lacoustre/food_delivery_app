import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:african_cuisine/home/main_home_page.dart';
import 'package:african_cuisine/logins/login_choice_page.dart';
import 'package:african_cuisine/logins/verify_account_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;

          if (user == null) {
            return const LoginChoicePage();
          }

          // Check phone verification status from Firestore
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // Handle Firestore permission errors - allow existing users through
              if (userSnapshot.hasError) {
                print('Firestore error in AuthGate: ${userSnapshot.error}');
                return const MainFoodPage();
              }

              // If user document doesn't exist, they need to verify
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return const VerifyAccountPage();
              }

              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>?;
              if (userData == null) {
                return const VerifyAccountPage();
              }

              // Allow all authenticated users with valid user documents to proceed
              return const MainFoodPage();
            },
          );
        }

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
