import 'package:equatable/equatable.dart';

/// A pure Dart object: no JSON, no Flutter, no Dio.
class User extends Equatable {
  const User({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  @override
  List<Object?> get props => [id, name, email];
}
