// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'date_goal_model.dart';

class RecoveryModel {
  String? nickname;
  List<DateGoalModel>? userData;

  RecoveryModel({
    this.nickname,
    this.userData,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'nickname': nickname,
      'userData': userData?.map((x) => x.toMap()).toList(),
    };
  }

  factory RecoveryModel.fromMap(Map<String, dynamic> map) {
    return RecoveryModel(
      nickname: map['nickname'] != null ? map['nickname'] as String : null,
      userData: map['userData'] != null
          ? List<DateGoalModel>.from(
              (map['userData'] as List).map<DateGoalModel?>(
                (x) => DateGoalModel.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory RecoveryModel.fromJson(String source) =>
      RecoveryModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
