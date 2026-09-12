import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// تسجيل الدخول برقم الهاتف
  static Future<void> verifyPhone({
    required String phone,
    required Function(PhoneAuthCredential) onSuccess,
    required Function(String) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (credential) {
        onSuccess(credential);
      },
      verificationFailed: (e) {
        onError(e.message ?? 'Verification failed');
      },
      codeSent: (verificationId, resendToken) {
        // احفظ verificationId لاستخدامه لاحقاً
      },
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  /// تأكيد رمز التحقق
  static Future<User?> signInWithPhone({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  /// تسجيل الخروج
  static Future<void> signOut() async {
    await _auth.signOut();
  }
}