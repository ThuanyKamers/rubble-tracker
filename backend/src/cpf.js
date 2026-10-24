export function limparCpf(cpf) {
  return String(cpf || '').replace(/\D/g, '');
}

export function cpfValido(cpf) {
  const c = limparCpf(cpf);
  if (c.length !== 11 || /^(\d)\1{10}$/.test(c)) return false;

  const digito = (base) => {
    let soma = 0;
    for (let i = 0; i < base.length; i++) {
      soma += Number(base[i]) * (base.length + 1 - i);
    }
    const resto = (soma * 10) % 11;
    return resto === 10 ? 0 : resto;
  };

  const d1 = digito(c.slice(0, 9));
  const d2 = digito(c.slice(0, 10));
  return d1 === Number(c[9]) && d2 === Number(c[10]);
}
