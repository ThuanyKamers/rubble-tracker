String limparCpf(String cpf) => cpf.replaceAll(RegExp(r'\D'), '');

bool cpfValido(String cpf) {
  final c = limparCpf(cpf);
  if (c.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(c)) return false;

  int digito(String base) {
    var soma = 0;
    for (var i = 0; i < base.length; i++) {
      soma += int.parse(base[i]) * (base.length + 1 - i);
    }
    final resto = (soma * 10) % 11;
    return resto == 10 ? 0 : resto;
  }

  return digito(c.substring(0, 9)) == int.parse(c[9]) &&
      digito(c.substring(0, 10)) == int.parse(c[10]);
}
