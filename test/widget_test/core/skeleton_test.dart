import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/core/widgets/form_view_shimmer.dart';
import 'package:mobo_helpdesk/core/widgets/full_card_shimmer.dart';
import 'package:mobo_helpdesk/core/widgets/list_view_shimmer.dart';
import 'package:mobo_helpdesk/core/widgets/skeleton.dart';
import 'package:mobo_helpdesk/features/account/presentation/widgets/profile_shimmer.dart';
import 'package:mobo_helpdesk/features/dashboard/presentation/widgets/dashboard_shimmer_page.dart';

/// The loading skeletons sit in the space a screen leaves under its header, so
/// they have to survive a short area (small phone, keyboard up) without
/// overflowing, in both themes.
Widget _host(Widget child, {required double height, required Brightness mode}) {
  return MaterialApp(
    theme: ThemeData(brightness: mode),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 360, height: height, child: child),
      ),
    ),
  );
}

void main() {
  final skeletons = <String, Widget Function(Brightness)>{
    'ListViewShimmer': (_) => const ListViewShimmer(),
    'KanbanViewShimmer': (_) => const KanbanViewShimmer(),
    'FormViewShimmer': (_) => const FormViewShimmer(),
    'ProfileShimmer': (_) => const ProfileShimmer(),
    'DashboardShimmerPage': (mode) =>
        DashboardShimmerPage(isDark: mode == Brightness.dark),
  };

  // ProfileShimmer is a whole screen with a fixed 100px avatar on top, so a
  // 90px area is not a size it is ever given; the others fill whatever space a
  // screen leaves under its header, however little.
  const fullScreenOnly = {'ProfileShimmer'};

  for (final mode in Brightness.values) {
    for (final height in [640.0, 220.0, 90.0]) {
      skeletons.forEach((name, build) {
        if (height < 220 && fullScreenOnly.contains(name)) return;

        testWidgets('$name fits $height tall in $mode', (tester) async {
          await tester.pumpWidget(
            _host(build(mode), height: height, mode: mode),
          );
          // Past one full sweep, so the animation has actually run.
          await tester.pump(const Duration(milliseconds: 800));
          await tester.pump(const Duration(milliseconds: 800));

          expect(tester.takeException(), isNull);
        });
      });
    }
  }

  testWidgets('the list is made of full-width shimmering cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ListViewShimmer(), height: 900, mode: Brightness.light),
    );

    expect(find.byType(FullCardShimmer), findsWidgets);
  });

  testWidgets('the kanban board is made of full cards with avatars on them', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const KanbanViewShimmer(), height: 900, mode: Brightness.light),
    );

    expect(find.byType(SkeletonCard), findsWidgets);
    expect(find.byType(SkeletonCircle), findsWidgets);
  });

  testWidgets('a card takes its margin and padding like the real one', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        // Loose constraints, as in a list: the host's box is tight and would
        // stretch the card to fill it.
        const Align(
          alignment: Alignment.topLeft,
          child: SkeletonCard(
            margin: EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(16),
            child: SkeletonBar(height: 20),
          ),
        ),
        height: 300,
        mode: Brightness.light,
      ),
    );

    // The card's own block (inside its margin), not another ClipRRect higher up.
    final card = tester.getRect(
      find
          .descendant(
            of: find.byType(SkeletonCard),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(card.height, 20 + 16 * 2);
    expect(card.width, 360);
    expect(
      tester.getRect(find.byType(SkeletonCard)).height,
      20 + 16 * 2 + 10,
      reason: 'the bottom margin is part of the space it takes',
    );
  });
}
