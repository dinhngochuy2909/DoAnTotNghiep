import '../lib/services/auth_service.dart';

void main() async {
  print('=== TEST 1: LOGIN AS CUSTOMER ===');
  final customerResult = await AuthService.login(
    email: 'user@alobooking.com',
    password: '123456',
  );
  print('Customer login result: ${customerResult.success}, message: ${customerResult.message}');
  print('Current user: ${AuthService.currentUser?.fullName}');
  print('Role: ${AuthService.currentUser?.role}');
  print('Is Admin: ${AuthService.isAdmin}');
  assert(!AuthService.isAdmin, 'Customer must NOT be admin!');

  AuthService.logout();
  print('Logged out. Is logged in: ${AuthService.isLoggedIn}');

  print('\n=== TEST 2: LOGIN AS ADMIN ===');
  final adminResult = await AuthService.login(
    email: 'admin@alobooking.com',
    password: 'admin123',
  );
  print('Admin login result: ${adminResult.success}, message: ${adminResult.message}');
  print('Current user: ${AuthService.currentUser?.fullName}');
  print('Role: ${AuthService.currentUser?.role}');
  print('Is Admin: ${AuthService.isAdmin}');
  assert(AuthService.isAdmin, 'Admin must be admin!');

  print('\n>>> ALL ROLE TESTS PASSED PERFECTLY! <<<');
}
