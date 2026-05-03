import 'package:app_quitar/models/wall_post.dart';
import 'package:app_quitar/widgets/admin_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  WallPost post({
    WallContentStatus status = WallContentStatus.pending,
    String? abuseHash = 'hash-123',
    int commentCount = 0,
    String? rejectionReason,
  }) {
    return WallPost(
      id: 'post-1',
      alias: 'Guerrero #9638',
      giantId: 'digital',
      body: 'Hola! Dios es bueno!',
      status: status,
      rejectionReason: rejectionReason,
      createdAt: DateTime(2026, 5, 3, 12, 30),
      commentCount: commentCount,
      reportCount: 1,
      abuseHash: abuseHash,
    );
  }

  testWidgets('pending post can approve, reject, and ban', (tester) async {
    var approveCount = 0;
    var rejectCount = 0;
    var banCount = 0;

    await tester.pumpWidget(
      wrap(
        AdminPostCard(
          post: post(),
          onApprove: () => approveCount++,
          onReject: () => rejectCount++,
          onBan: () => banCount++,
        ),
      ),
    );

    expect(find.text('PENDIENTE'), findsOneWidget);
    expect(find.text('Aprobar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
    expect(find.text('Ban'), findsOneWidget);

    await tester.tap(find.text('Aprobar'));
    await tester.tap(find.text('Rechazar'));
    await tester.tap(find.text('Ban'));

    expect(approveCount, 1);
    expect(rejectCount, 1);
    expect(banCount, 1);
  });

  testWidgets('pending post without abuse hash does not show ban action', (tester) async {
    await tester.pumpWidget(
      wrap(
        AdminPostCard(post: post(abuseHash: null), onApprove: () {}, onReject: () {}, onBan: () {}),
      ),
    );

    expect(find.text('Aprobar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
    expect(find.text('Ban'), findsNothing);
  });

  testWidgets('approved post can be rejected but not approved again', (tester) async {
    var rejectCount = 0;

    await tester.pumpWidget(
      wrap(
        AdminPostCard(
          post: post(status: WallContentStatus.approved),
          onApprove: () {},
          onReject: () => rejectCount++,
          onBan: () {},
        ),
      ),
    );

    expect(find.text('APROBADO'), findsOneWidget);
    expect(find.text('Aprobar'), findsNothing);
    expect(find.text('Rechazar'), findsOneWidget);

    await tester.tap(find.text('Rechazar'));

    expect(rejectCount, 1);
  });

  testWidgets('rejected post shows reason and no moderation action buttons', (tester) async {
    await tester.pumpWidget(
      wrap(
        AdminPostCard(
          post: post(status: WallContentStatus.rejected, rejectionReason: 'Lenguaje inapropiado'),
          onApprove: () {},
          onReject: () {},
          onBan: () {},
        ),
      ),
    );

    expect(find.text('RECHAZADO'), findsOneWidget);
    expect(find.text('Lenguaje inapropiado'), findsOneWidget);
    expect(find.text('Aprobar'), findsNothing);
    expect(find.text('Rechazar'), findsNothing);
    expect(find.text('Ban'), findsOneWidget);
  });
}
