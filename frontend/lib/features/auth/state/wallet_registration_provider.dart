import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_service.dart';
import '../data/wallet_registration_model.dart';
import '../data/wallet_registration_repository.dart';
import '../utils/wallet_validators.dart';

/// حالة معالج تسجيل المحفظة — State Management عبر Riverpod Notifier.
///
/// الخطوات: 0 = البيانات الشخصية والنسب، 1 = الهوية والتواصل، 2 = الأمان ورقم المحفظة.
class WalletRegistrationState {
  const WalletRegistrationState({
    this.step = 0,
    this.model = const WalletRegistrationModel(),
    this.confirmPin = '',
    this.loading = false,
    this.error,
    this.successAccountId,
  });

  final int step;
  final WalletRegistrationModel model;
  final String confirmPin;
  final bool loading;
  final String? error;
  final String? successAccountId;

  WalletRegistrationState copyWith({
    int? step,
    WalletRegistrationModel? model,
    String? confirmPin,
    bool? loading,
    String? Function()? error,
    String? Function()? successAccountId,
  }) {
    return WalletRegistrationState(
      step: step ?? this.step,
      model: model ?? this.model,
      confirmPin: confirmPin ?? this.confirmPin,
      loading: loading ?? this.loading,
      error: error != null ? error() : this.error,
      successAccountId:
          successAccountId != null ? successAccountId() : this.successAccountId,
    );
  }
}

class WalletRegistrationController extends Notifier<WalletRegistrationState> {
  @override
  WalletRegistrationState build() {
    return WalletRegistrationState(
      model: WalletRegistrationModel(accountId: WalletRegistrationModel.generateAccountId()),
    );
  }

  WalletRegistrationRepository get _repo =>
      WalletRegistrationRepository(ref.read(apiClientProvider));

  void update(WalletRegistrationModel Function(WalletRegistrationModel m) fn) {
    state = state.copyWith(model: fn(state.model), error: () => null);
  }

  void setConfirmPin(String v) =>
      state = state.copyWith(confirmPin: v, error: () => null);

  void regenerateAccountId() {
    update((m) => m.copyWith(accountId: WalletRegistrationModel.generateAccountId()));
  }

  /// تحقق الخطوة الحالية — يرجع رسالة الخطأ العربية أو null.
  String? validateStep(int step) {
    final m = state.model;
    if (step == 0) {
      return WalletValidators.name(m.firstName, 'الاسم الأول') ??
          WalletValidators.name(m.fatherName, 'اسم الأب') ??
          WalletValidators.name(m.lastName, 'الكنية') ??
          WalletValidators.name(m.motherName, 'اسم الأم') ??
          WalletValidators.name(m.motherFatherName, 'اسم والد الأم') ??
          WalletValidators.name(m.motherMaidenName, 'كنية الأم');
    }
    if (step == 1) {
      return WalletValidators.nationalIdValidator(m.nationalId) ??
          WalletValidators.phoneValidator(m.modelPhoneForValidation) ??
          WalletValidators.emailValidator(m.email) ??
          WalletValidators.passwordValidator(m.password) ??
          WalletValidators.birthDateValidator(m.birthDate);
    }
    return WalletValidators.accountIdValidator(m.accountId) ??
        WalletValidators.pinValidator(m.walletPin) ??
        (m.walletPin != state.confirmPin ? 'تأكيد رمز الحماية غير متطابق' : null) ??
        (m.consentAccepted ? null : 'يجب الموافقة على الشروط وسياسة الخصوصية');
  }

  bool next() {
    final err = validateStep(state.step);
    if (err != null) {
      state = state.copyWith(error: () => err);
      return false;
    }
    if (state.step < 2) {
      state = state.copyWith(step: state.step + 1, error: () => null);
    }
    return true;
  }

  void back() {
    if (state.step > 0) {
      state = state.copyWith(step: state.step - 1, error: () => null);
    }
  }

  void goTo(int step) {
    state = state.copyWith(step: step.clamp(0, 2), error: () => null);
  }

  /// الإرسال النهائي — مؤشر تحميل + معالجة أخطاء سطحية واضحة.
  Future<bool> submit() async {
    final err = validateStep(2);
    if (err != null) {
      state = state.copyWith(error: () => err);
      return false;
    }
    state = state.copyWith(loading: true, error: () => null);
    try {
      final res = await _repo.submit(state.model);
      final data = (res['data'] as Map?) ?? res;
      final access = '${data['accessToken'] ?? ''}';
      if (access.isNotEmpty) {
        ref.read(sessionTokenProvider.notifier).state = access;
        await SessionService.saveToken(access);
        final refresh = '${data['refreshToken'] ?? ''}';
        if (refresh.isNotEmpty) await SessionService.saveRefreshToken(refresh);
      }
      final accId = '${(data['profile'] as Map?)?['walletAccountId'] ?? state.model.formattedAccountId}';
      state = state.copyWith(loading: false, successAccountId: () => accId);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: () => _friendly(e.message));
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, error: () => 'تعذر الاتصال، أعد المحاولة');
      return false;
    }
  }

  String _friendly(String m) {
    if (m.contains('16')) return 'رقم حساب المحفظة يجب أن يكون 16 رقماً';
    if (m.contains('4 أو 6')) return m;
    if (m.contains('الوطني')) return 'هذا الرقم الوطني مسجل مسبقاً';
    if (m.contains('already') || m.contains('مسجل مسبقاً')) {
      return 'هذا البريد مسجل مسبقاً — سجّل الدخول';
    }
    if (m.contains('at least 8')) return 'كلمة المرور 8 أحرف على الأقل';
    if (m.contains('valid email')) return 'صيغة البريد الإلكتروني غير صحيحة';
    return m;
  }
}

/// extension صغير: الرقم كما يُتحقق (كامل بالمفتاح) دون كشف منطق داخل الـ UI.
extension on WalletRegistrationModel {
  String get modelPhoneForValidation => fullPhone;
}

final walletRegistrationProvider =
    NotifierProvider<WalletRegistrationController, WalletRegistrationState>(
  WalletRegistrationController.new,
);
