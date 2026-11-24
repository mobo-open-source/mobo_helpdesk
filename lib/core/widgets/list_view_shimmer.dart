import 'package:flutter/material.dart';

import 'full_card_shimmer.dart';

/// Loading placeholder for the list screens (tickets, teams, SLA policies,
/// ratings), shown while a list loads, including the reload after a ticket or
/// team has been created.
///
/// The same stack of [FullCardShimmer] blocks the Mobo Events app shows while
/// its event list loads: six full-width cards on 20px side padding. Not
/// scrollable: it is only a stand-in.
class ListViewShimmer extends StatelessWidget {
  const ListViewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        itemBuilder: (_, _) => const FullCardShimmer(),
      ),
    );
  }
}
