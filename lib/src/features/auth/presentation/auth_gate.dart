import 'package:flutter/material.dart';

import '../../../core/widgets/watercolor_scaffold.dart';

class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: WatercolorScaffold(
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
