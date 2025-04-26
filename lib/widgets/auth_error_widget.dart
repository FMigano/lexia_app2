import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lexia_app/providers/auth_provider.dart' as app_provider;

class AuthErrorWidget extends StatelessWidget {
  final Widget child;

  const AuthErrorWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<app_provider.AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isAuthenticated) {
          return child;
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Please sign in to continue'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Navigate to login screen
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('Sign In'),
              ),
            ],
          ),
        );
      },
    );
  }
}
