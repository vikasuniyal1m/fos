import 'package:flutter/material.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';

/// Scaffold with tablet/iPad max-width constraint on body.
class ResponsiveScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final StandardAppBar? standardAppBar;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool extendBody;
  final bool? resizeToAvoidBottomInset;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.standardAppBar,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.extendBody = false,
    this.resizeToAvoidBottomInset,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: extendBody,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar ?? standardAppBar,
      bottomNavigationBar: bottomNavigationBar,
      body: ResponsiveHelper.constrainedContent(
        context: context,
        child: body,
      ),
    );
  }
}
