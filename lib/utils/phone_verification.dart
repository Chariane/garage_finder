String? normalizePhoneForVerification(String input) {
  final phone = input.trim().replaceAll(RegExp(r'[\s().-]'), '');
  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) return null;
  return phone;
}
