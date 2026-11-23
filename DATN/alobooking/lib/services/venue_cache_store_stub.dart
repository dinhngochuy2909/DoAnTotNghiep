/// Nơi lưu chữ lâu dài cho bộ nhớ đệm khi không chạy trên web (và khi chạy kiểm thử): chỉ giữ trong bộ nhớ.
final Map<String, String> _memory = {};

String? readStoredText(String key) => _memory[key];

void writeStoredText(String key, String value) {
  _memory[key] = value;
}

void removeStoredText(String key) {
  _memory.remove(key);
}
