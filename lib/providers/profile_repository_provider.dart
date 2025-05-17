import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/profile_repository.dart';

// Define the missing profileRepositoryProvider
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});