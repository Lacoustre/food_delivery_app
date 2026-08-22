import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:african_cuisine/home/main_home_page.dart';
import 'package:african_cuisine/logins/login_choice_page.dart';

/// Routes on the Supabase session — auth is Supabase-only now. The profile
/// row is created at signup, so no post-login verification gate is needed.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginChoicePage();
        }
        return const MainFoodPage();
      },
    );
  }
}
