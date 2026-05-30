import 'package:flutter/material.dart';

import '../../widgets/app_version_details_sheet.dart';

/// Kept for deep links / route table; opens the same details sheet as profile tap.
class AppVersionPage extends StatelessWidget {
  const AppVersionPage({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppVersionDetailsSheet.show(context).then((_) {
        if (context.mounted) Navigator.maybePop(context);
      });
    });

    return const Scaffold(
      body: SizedBox.shrink(),
    );
  }
}
