String normalizeWhatsAppNumber(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('229')) return digits;
  if (digits.length == 8 || digits.length == 10) return '229$digits';
  if (digits.startsWith('0') && digits.length == 9) {
    return '229${digits.substring(1)}';
  }
  return digits;
}

Uri? whatsappUri(String phone, {String? message}) {
  final number = normalizeWhatsAppNumber(phone);
  if (number.length < 8 || number.length > 15) return null;
  return Uri.https('wa.me', '/$number', {
    if (message != null && message.isNotEmpty) 'text': message,
  });
}
