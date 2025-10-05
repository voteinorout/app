class AuthService {
  // Simulate a login process
  Future<bool> login(String username, String password) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay
    return username == 'user' && password == 'password'; // Simple check
  }

  // Simulate a logout process
  Future<void> logout() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
  }
}