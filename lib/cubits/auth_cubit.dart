import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/models/user.dart';
import 'package:kitchenowl/services/api/api_service.dart';
import 'package:kitchenowl/services/storage.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(Loading()) {
    ApiService.getInstance().addListener(this.updateState);
    setup();
  }

  void setup() async {
    final url = await PreferenceStorage.getInstance().read(key: 'URL');
    if (url != null && url.isNotEmpty) {
      final token = await SecureStorage.getInstance().read(key: 'TOKEN');
      _newConnection(url, token: token, storeData: false);
    } else {
      refresh();
    }
  }

  void updateState() async {
    switch (ApiService.getInstance().connectionStatus) {
      case Connection.authenticated:
        final user = await ApiService.getInstance().getUser();
        emit(Authenticated(user));
        break;
      case Connection.disconnected:
        if (ApiService.getInstance().baseUrl.isNotEmpty)
          emit(Unreachable());
        else
          emit(Setup());
        break;
      case Connection.connected:
        if (await ApiService.getInstance().isOnboarding())
          emit(Onboarding());
        else
          emit(Unauthenticated());
        break;
      case Connection.unsupported:
        emit(Unsupported());
        break;
      case Connection.undefined:
        emit(Loading());
        break;
    }
  }

  void setupServer(String url) async {
    emit(Loading());
    _newConnection(url);
  }

  Future<void> refresh() => ApiService.getInstance().refresh();

  Future<void> refreshUser() async {
    if (state is Authenticated)
      emit(Authenticated(await ApiService.getInstance().getUser()));
  }

  void createUser(String username, String name, String password) async {
    emit(Loading());
    if (await ApiService.getInstance().isOnboarding()) {
      final token =
          await ApiService.getInstance().onboarding(username, name, password);
      if (token != null && ApiService.getInstance().isAuthenticated()) {
        await SecureStorage.getInstance().write(key: 'TOKEN', value: token);
      }
    }
  }

  void login(String username, String password) async {
    emit(Loading());
    final token = await ApiService.getInstance().login(username, password);
    if (token != null && ApiService.getInstance().isAuthenticated()) {
      await SecureStorage.getInstance().write(key: 'TOKEN', value: token);
    } else
      refresh();
  }

  void logout() async {
    emit(Loading());
    await SecureStorage.getInstance().delete(key: 'TOKEN');
    ApiService.getInstance().refreshToken = '';
    refresh();
  }

  void removeServer() async {
    emit(Loading());
    await PreferenceStorage.getInstance().delete(key: 'URL');
    await SecureStorage.getInstance().delete(key: 'TOKEN');
    ApiService.getInstance().dispose();
    refresh();
  }

  Future<void> _newConnection(
    String url, {
    String token,
    bool storeData = true,
  }) async {
    if (url == null || url.isEmpty) return;
    await ApiService.connectTo(url, refreshToken: token);
    if (storeData && ApiService.getInstance().isConnected()) {
      await PreferenceStorage.getInstance().write(key: 'URL', value: url);
      if (token != null && token.isNotEmpty)
        await SecureStorage.getInstance().write(key: 'TOKEN', value: token);
    }
  }
}

abstract class AuthState extends Equatable {}

class Authenticated extends AuthState {
  final User user;

  Authenticated(this.user);

  @override
  List<Object> get props => [user];
}

class Onboarding extends AuthState {
  @override
  List<Object> get props => ["Onboarding"];
}

class Unauthenticated extends AuthState {
  @override
  List<Object> get props => ["Setup"];
}

class Setup extends AuthState {
  @override
  List<Object> get props => ["Unauthenticated"];
}

class Loading extends AuthState {
  @override
  List<Object> get props => ["Initial"];
}

class Unreachable extends AuthState {
  @override
  List<Object> get props => ["Unreachable"];
}

class Unsupported extends AuthState {
  @override
  List<Object> get props => ["Unsupported"];
}