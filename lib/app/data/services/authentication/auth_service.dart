import 'package:dukkantek/app/core/utils/action_center/action_center.dart';
import 'package:dukkantek/app/data/managers/api_manager/authentication/authentication_manager.dart';
import 'package:dukkantek/app/data/managers/cache/cache_manager.dart';
import 'package:dukkantek/app/data/model/login_response.dart';
import 'package:dukkantek/app/data/model/user.dart';
import 'package:dukkantek/app/data/services/logger/logger.dart';
import 'package:dukkantek/app/routes/app_pages.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebaseAuth;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends GetxService implements AbsAuthService {
  final _cacheService = Get.find<AbsCacheManager>();
  final _authAPIManger = Get.put<AbsAuthApiManager>(AuthAPIManager());
  final _actionCenter = ActionCenter();

  User? user;
  String? token;
  bool signedWithGoogle = false;

  @override
  void onInit() async {
    await Firebase.initializeApp();
    firebaseAuth.FirebaseAuth auth = firebaseAuth.FirebaseAuth.instance;
    listenToFirebaseAuth();
    super.onInit();
  }

  listenToFirebaseAuth() {
    firebaseAuth.FirebaseAuth.instance
        .authStateChanges()
        .listen((firebaseAuth.User? firebaseUser) {
      if (firebaseUser == null) {
        Get.find<AbsLoggerService>()
            .info(message: 'User is currently signed out!');
        checkLoggedUser();
      } else {
        user = User(email: firebaseUser.email);
        signedWithGoogle = true;
        Get.find<AbsLoggerService>().info(message: 'User is signed in!!');
        redirectUser(user);
      }
    });
  }

  Future<firebaseAuth.UserCredential?> signInWithGoogle() async {
    firebaseAuth.OAuthCredential? credential;
    var result = await _actionCenter.execute(
      () async {
        // Trigger the authentication flow
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

        // Obtain the auth details from the request
        final GoogleSignInAuthentication? googleAuth =
            await googleUser?.authentication;

        // Create a new credential
        credential = firebaseAuth.GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken,
          idToken: googleAuth?.idToken,
        );
      },
      checkConnection: true,
    );
    if (result && credential != null) {
      // Once signed in, return the UserCredential
      return await firebaseAuth.FirebaseAuth.instance
          .signInWithCredential(credential!);
    }
    return null;
  }

  @override
  Future<void> checkLoggedUser() async {
    await _cacheService.init();
    token = _cacheService.retrieveString("token");
    if (token != null) {
      user = await getRemoteUserModel(token!);
    }

    redirectUser(user);
  }

  @override
  Future<User?> getRemoteUserModel(String token) async {
    User? user;
    var result = (await _actionCenter.execute(
      () async {
        user = await _authAPIManger.getUserModel(token);
      },
      checkConnection: true,
    ));
    if (result && user != null) {
      Get.find<AbsLoggerService>().info(
          message:
              "AutoLogged user successfully with email: ${user?.email ?? ""}");
      return user;
    }
    return null;
  }

  @override
  void redirectUser(User? user) {
    if (user != null) {
      Get.offNamed(Routes.HOME);
    } else {
      Get.offNamed(Routes.LOGIN);
    }
  }

  @override
  Future<void> signOut() async {
    bool result = false;
    if (signedWithGoogle) {
      firebaseAuth.FirebaseAuth.instance.signOut();
      result = true;
    } else {
      result = (await _actionCenter.execute(
        () async {
          await _authAPIManger.logout(token ?? "");
        },
        checkConnection: true,
      ));
    }
    if (result) {
      Get.find<AbsLoggerService>()
          .info(message: "User successfully Signed out !!");
      user = null;
      token = null;
      _cacheService.clearAll();
      redirectUser(user);
    }
  }

  @override
  Future<User?> login(String username, String password) async {
    LoginResponse? loginResponse;
    var result = (await _actionCenter.execute(
      () async {
        loginResponse = await _authAPIManger.login(username, password);
      },
      checkConnection: true,
    ));
    if (result && loginResponse != null) {
      Get.find<AbsCacheManager>()
          .storeString("token", loginResponse!.token ?? "");
      user = loginResponse!.user;
      token = loginResponse!.token;
      Get.find<AbsLoggerService>().info(
          message: "Logged user successfully with email: ${user?.email ?? ""}");
      redirectUser(user);
    }
    return loginResponse?.user;
  }

  @override
  Future<User?> register(String username, String email, String password) async {
    LoginResponse? loginResponse;
    var result = (await _actionCenter.execute(
      () async {
        loginResponse =
            await _authAPIManger.register(username, email, password);
      },
      checkConnection: true,
    ));
    if (result && loginResponse != null) {
      Get.find<AbsCacheManager>()
          .storeString("token", loginResponse!.token ?? "");
      user = loginResponse!.user;
      token = loginResponse!.token;
      Get.find<AbsLoggerService>().info(
          message:
              "User Registered successfully with email: ${user?.email ?? ""}");
      redirectUser(user);
    }
    return loginResponse?.user;
  }
}

abstract class AbsAuthService {
  Future<void> checkLoggedUser();
  Future<User?> getRemoteUserModel(String token);
  void signOut();
  Future<User?> login(String username, String password);
  Future<User?> register(String username, String email, String password);
  void redirectUser(User? user);
}
