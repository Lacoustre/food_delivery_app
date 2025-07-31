import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:african_cuisine/home/main_home_page.dart';
import 'package:african_cuisine/logins/login_choice_page.dart';
import 'package:african_cuisine/logins/verify_email_page.dart';

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
            return const LoginChoicePage(); // Shows both login options
          }

          // Only check email verification for email/password users
          final isEmailUser = user.providerData.any(
            (info) => info.providerId == 'password',
          );

          if (isEmailUser && !user.emailVerified) {
            return const VerifyEmailPage();
          }

          return const MainFoodPage();
        }

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
