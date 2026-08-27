import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parsea el programa y sus métricas dinámicas', () {
    final program = ReferralProgram.fromMap({
      'enabled': true,
      'campaign_id': 'campaign-1',
      'campaign_name': 'Invita y gana',
      'qualification_mode': 'first_payment',
      'reward_days': 15,
      'code': 'ABC-123',
      'link': 'https://www.vrixora.com/tuktuk/app/?ref=ABC-123',
      'referred_count': 4,
      'qualified_count': 2,
      'earned_rewards': 2,
      'applied_rewards': 1,
      'earned_days': 30,
      'applied_days': 15,
    });

    expect(program.enabled, isTrue);
    expect(program.qualificationMode, ReferralQualificationMode.firstPayment);
    expect(program.rewardDays, 15);
    expect(program.referredCount, 4);
    expect(program.earnedDays, 30);
    expect(program.link, contains('ABC-123'));
  });

  test('muestra condiciones registration y first_payment sin hardcodearlas', () {
    expect(
      referralQualificationLabel(ReferralQualificationMode.registration),
      'Cuando tu invitado se registre',
    );
    expect(
      referralQualificationLabel(ReferralQualificationMode.firstPayment),
      'Cuando tu invitado realice su primer pago',
    );
  });

  test('traduce los estados remotos de referidos al español', () {
    expect(
      referralEntryStatusLabel(
        referralEntryStatusFromValue('registered'),
      ),
      'Registrado',
    );
    expect(
      referralEntryStatusLabel(referralEntryStatusFromValue('qualified')),
      'Cumplió la condición',
    );
    expect(
      referralEntryStatusLabel(referralEntryStatusFromValue('rewarded')),
      'Recompensa aplicada',
    );
  });

  test('captura el código web y lo limpia después de claim exitoso', () async {
    final store = _MemoryPendingReferralStore();
    final controller = PendingReferralClaimController(store);
    var claims = 0;

    expect(
      await controller.capture(
        Uri.parse('https://www.vrixora.com/tuktuk/app/?ref=ABC-123'),
      ),
      isTrue,
    );
    final result = await controller.claimForUser(
      userId: 'user-1',
      claim: (code) async {
        claims++;
        expect(code, 'ABC-123');
      },
    );

    expect(result, PendingReferralClaimResult.success);
    expect(
      await controller.claimForUser(
        userId: 'user-1',
        claim: (_) async => claims++,
      ),
      PendingReferralClaimResult.none,
    );
    expect(claims, 1);
    expect(store.code, isNull);
  });

  test('no intenta claim sin usuario autenticado', () async {
    final store = _MemoryPendingReferralStore()..code = 'ABC-123';
    final controller = PendingReferralClaimController(store);
    var claims = 0;

    final result = await controller.claimForUser(
      userId: '',
      claim: (_) async => claims++,
    );

    expect(result, PendingReferralClaimResult.none);
    expect(claims, 0);
    expect(store.code, 'ABC-123');
  });

  test('un claim fallido no se repite y queda aislado por cuenta', () async {
    final store = _MemoryPendingReferralStore()..code = 'ABC-123';
    final controller = PendingReferralClaimController(store);
    var claims = 0;

    Future<void> fail(String _) async {
      claims++;
      throw StateError('rechazado');
    }

    expect(
      await controller.claimForUser(userId: 'user-1', claim: fail),
      PendingReferralClaimResult.failed,
    );
    expect(
      await controller.claimForUser(userId: 'user-1', claim: fail),
      PendingReferralClaimResult.alreadyAttempted,
    );
    expect(
      await controller.claimForUser(userId: 'user-2', claim: fail),
      PendingReferralClaimResult.accountMismatch,
    );
    expect(claims, 1);
  });
}

class _MemoryPendingReferralStore implements PendingReferralCodeStore {
  @override
  String? code;
  @override
  String? assignedUserId;
  @override
  String? attemptedUserId;

  @override
  Future<void> saveCode(String value) async {
    code = value;
    assignedUserId = null;
    attemptedUserId = null;
  }

  @override
  Future<void> assignToUser(String userId) async => assignedUserId = userId;

  @override
  Future<void> markAttempted(String userId) async => attemptedUserId = userId;

  @override
  Future<void> resetAttempt() async => attemptedUserId = null;

  @override
  Future<void> clear() async {
    code = null;
    assignedUserId = null;
    attemptedUserId = null;
  }
}
