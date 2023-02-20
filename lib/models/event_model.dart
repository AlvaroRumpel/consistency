import 'dart:convert';

class EventModel {
  List<DateTime> dates;

  EventModel({
    required this.dates,
  });

  Map<String, dynamic> toMap() {
    return {
      'dates': dates.map((x) => x.millisecondsSinceEpoch).toList(),
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      dates: List<DateTime>.from(
        map['dates']?.map(
          (x) => DateTime.fromMillisecondsSinceEpoch(x),
        ),
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory EventModel.fromJson(String source) =>
      EventModel.fromMap(json.decode(source));
}
