import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:four_in_a_row/util/constants.dart' as constants;

import 'package:four_in_a_row/util/extensions.dart';

class UserInfo with ChangeNotifier {
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  http.Client _client = http.Client();

  // bool _ok = false;
  bool refreshing = false;
  bool offline = false;
  // bool loadedInfo = false;

  String? username;
  String? _password;

  User? user;

  bool get loggedIn => username != null && _password != null && user != null;

  UserInfo() {
    _prefs.then((_) {
      loadCredentials();
    });
  }

  Map<String, String> _body(String username, String password) {
    return {
      "username": username,
      "password": password,
    };
  }

  void logOut() async {
    // this._ok = false;
    this.username = null;
    this._password = null;
    this.user = null;

    var prefs = await _prefs;
    if (prefs.containsKey('username') && prefs.containsKey('password')) {
      prefs.remove('username');
      prefs.remove('password');
    }
  }

  void loadCredentials() async {
    var prefs = await _prefs;
    if (prefs.containsKey('username') && prefs.containsKey('password')) {
      this.setCredentials(
          prefs.getString('username'), prefs.getString('password'));
    }
  }

  void setCredentials(String username, String password) async {
    var prefs = await _prefs;
    prefs.setString('username', username);
    prefs.setString('password', password);

    this.username = username;
    this._password = password;
    _loadInfo();
  }

  Future<bool> addFriend(String id, [VoidCallback? callback]) async {
    var response = await _client
        .post("${constants.URL}/api/users/me/friends?id=$id", body: _body);
    if (response.statusCode == 200) {
      if (callback != null) {
        callback();
      }
      await _loadInfo();
      // _friends.firstWhere((u) => u.id == id)?.isFriend = true;
      return true;
    } else {
      _loadInfo();
      return false;
    }
  }

  Future<UserInfo?> _loadInfo({
    delay = false,
    shouldSetState = false,
  }) async {
    if (shouldSetState == true) {
      refreshing = true;
    }

    if (username == null) return null;
    if (_password == null) return null;
    // rebuild();

    var req = http.Request("GET", Uri.parse('${constants.URL}/api/users/me'))
      ..headers['Authorization'] = "Basic " +
          base64.encode(Utf8Codec().encode(username! + ":" + _password!));
    // ..bodyFields = _body;

    try {
      var response = await _client.send(req);
      if (response.statusCode == 200) {
        User? user =
            User.fromMap(jsonDecode(await response.stream.bytesToString()));

        this.user = user;
      }
      offline = false;
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 7) {
        offline = true;
      }
    } on http.ClientException {
      offline = true;
    }

    refreshing = false;
    if (this.loggedIn && delay) {
      await Future.delayed(Duration(milliseconds: 300));
    }
    print("set state in userinfo refresh");
    // print("reloaded user info");
    return Future.value(this);

    // .catchError(() {});
  }

  Future<UserInfo?> refresh({shouldSetState: true}) {
    return _loadInfo(delay: true, shouldSetState: shouldSetState);
  }

  Future<PublicUser?> getUserInfo({required String userId}) async {
    var resp = await _client.get("${constants.URL}/api/users/$userId");
    if (resp.statusCode == 200) {
      return PublicUser.fromMap(jsonDecode(resp.body));
    } else {
      throw HttpException("Not found");
    }
  }
}

class GameInfo extends Equatable {
  final int skillRating;
  final int playerRank;

  GameInfo(this.skillRating, this.playerRank);

  static GameInfo? fromMap(Map<String, dynamic> map) {
    for (String key in ['skill_rating']) {
      if (!map.containsKey(key)) return null;
    }

    return GameInfo(
      map['skill_rating'] as int,
      255,
    );
  }

  @override
  List<Object> get props => [skillRating, playerRank];
}

class PublicUser {
  final String id;
  final String name;
  final GameInfo gameInfo;
  bool isFriend;
  bool isPlaying;

  PublicUser(
    this.id,
    this.name,
    this.gameInfo, {
    this.isFriend = false,
    this.isPlaying = false,
  });

  static PublicUser? fromMap(Map<String, dynamic> map) {
    for (String key in ['username', 'game_info', 'id']) {
      if (!map.containsKey(key)) return null;
    }
    GameInfo? gameInfo = GameInfo.fromMap(map['game_info']);
    if (gameInfo == null) return null;

    return PublicUser(
      map['id'],
      map['username'],
      gameInfo,
      isPlaying: map['playing'] ?? false,
    );
  }
}

class User extends Equatable {
  User({
    required this.id,
    required this.username,
    // this.password,
    required this.email,
    required this.friends,
    required this.gameInfo,
  });

  final String id;
  final String username;
  // final String password;
  final String email;
  final List<PublicUser> friends;
  final GameInfo gameInfo;

  static User? fromMap(Map<String, dynamic> map) {
    for (String key in ['id', 'username', 'game_info', 'friends', 'email']) {
      if (!map.containsKey(key)) return null;
    }
    List<PublicUser> friends = (map['friends'] as List<dynamic>)
        .map((dynamic friendMap) =>
            PublicUser.fromMap(friendMap as Map<String, dynamic>))
        .toList()
        .filterNotNull();

    GameInfo? gameInfo = GameInfo.fromMap(map['game_info']);
    if (gameInfo == null) return null;

    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      friends: friends,
      gameInfo: gameInfo,
    );
  }

  @override
  List<Object> get props => [id, username, email, friends, gameInfo];
  // String get id => _id;
  // String get username => _username;
  // String get password => _password;
  // String get email => _email;
  // List<PublicUser> get friends => _friends;
  // GameInfo get gameInfo => _gameInfo;
}
