import 'dart:convert';

import 'package:consistency/models/event_model.dart';

class RecoveryModel {
  String? nickname;
  EventModel? userData;

  RecoveryModel({
    this.nickname,
    this.userData,
  });

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'userData': userData?.toMap(),
    };
  }

  factory RecoveryModel.fromMap(Map<String, dynamic> map) {
    return RecoveryModel(
      nickname: map['nickname'],
      userData:
          map['userData'] != null ? EventModel.fromMap(map['userData']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory RecoveryModel.fromJson(String source) =>
      RecoveryModel.fromMap(json.decode(source));
}
