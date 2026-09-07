DateTime habitDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

String habitDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime _readDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid habit date');
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null || habitDateKey(parsed) != value) {
    throw const FormatException('Invalid habit date');
  }
  return parsed;
}

final class HabitDefinition {
  final String id, name;
  final DateTime createdDate;
  final bool archived;
  HabitDefinition({
    required this.id,
    required String name,
    required DateTime createdDate,
    this.archived = false,
  }) : name = name.trim(),
       createdDate = habitDate(createdDate) {
    if (id.trim().isEmpty || this.name.isEmpty || this.name.runes.length > 80) {
      throw const FormatException('Invalid habit identity or name');
    }
  }
  HabitDefinition withArchived(bool value) => HabitDefinition(
    id: id,
    name: name,
    createdDate: createdDate,
    archived: value,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'createdDate': habitDateKey(createdDate),
    'archived': archived,
  };
  factory HabitDefinition.fromJson(Map<String, dynamic> json) =>
      HabitDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        createdDate: _readDate(json['createdDate']),
        archived: json['archived'] as bool,
      );
}

/// 날짜별 체크는 습관 보관 여부와 별개로 유지한다.
final class HabitState {
  final List<HabitDefinition> habits;
  final Map<String, Set<String>> completedByDate;
  HabitState({
    List<HabitDefinition> habits = const [],
    Map<String, Set<String>> completedByDate = const {},
  }) : habits = List.unmodifiable(habits),
       completedByDate = Map.unmodifiable(
         completedByDate.map(
           (date, ids) => MapEntry(date, Set.unmodifiable(ids)),
         ),
       ) {
    final byId = {for (final habit in habits) habit.id: habit};
    if (byId.length != habits.length) {
      throw const FormatException('Duplicate habit identity');
    }
    for (final entry in completedByDate.entries) {
      final date = _readDate(entry.key);
      for (final id in entry.value) {
        final habit = byId[id];
        if (habit == null || date.isBefore(habit.createdDate)) {
          throw const FormatException('Invalid habit completion reference');
        }
      }
    }
  }
  bool isCompleted(String habitId, DateTime date) =>
      completedByDate[habitDateKey(date)]?.contains(habitId) ?? false;
  int completedCount(DateTime date) =>
      completedByDate[habitDateKey(date)]?.length ?? 0;
  HabitState add(HabitDefinition habit) {
    if (habits.any(
      (existing) => existing.name.toLowerCase() == habit.name.toLowerCase(),
    )) {
      throw const FormatException('Duplicate habit name');
    }
    return HabitState(
      habits: [...habits, habit],
      completedByDate: completedByDate,
    );
  }

  HabitState setArchived(String habitId, bool archived) {
    _habit(habitId);
    return HabitState(
      habits: [
        for (final habit in habits)
          habit.id == habitId ? habit.withArchived(archived) : habit,
      ],
      completedByDate: completedByDate,
    );
  }

  HabitState setCompleted(
    String habitId,
    DateTime date,
    bool completed, {
    required DateTime asOf,
  }) {
    final habit = _habit(habitId);
    final day = habitDate(date);
    if (day.isAfter(habitDate(asOf)) || day.isBefore(habit.createdDate)) {
      throw const FormatException('Habit date is outside the recording range');
    }
    final key = habitDateKey(day);
    final ids = {...?completedByDate[key]};
    completed ? ids.add(habitId) : ids.remove(habitId);
    final records = {...completedByDate};
    ids.isEmpty ? records.remove(key) : records[key] = ids;
    return HabitState(habits: habits, completedByDate: records);
  }

  HabitDefinition _habit(String id) => habits.firstWhere(
    (habit) => habit.id == id,
    orElse: () => throw const FormatException('Unknown habit identity'),
  );
  Map<String, Object?> toJson() => {
    'habits': habits.map((habit) => habit.toJson()).toList(),
    'completedByDate': completedByDate.map(
      (date, ids) => MapEntry(date, ids.toList()..sort()),
    ),
  };
  factory HabitState.fromJson(Map<String, dynamic> json) {
    final records = <String, Set<String>>{};
    for (final entry in (json['completedByDate'] as Map).entries) {
      final ids = (entry.value as List).cast<String>();
      if (ids.toSet().length != ids.length) {
        throw const FormatException('Duplicate habit completion');
      }
      records[entry.key as String] = ids.toSet();
    }
    return HabitState(
      habits: (json['habits'] as List)
          .map(
            (value) => HabitDefinition.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
      completedByDate: records,
    );
  }
}
