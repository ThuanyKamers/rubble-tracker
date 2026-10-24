enum Perfil { cidadao, trabalhador }

class Usuario {
  final int id;
  final String nome;
  final Perfil perfil;

  const Usuario({required this.id, required this.nome, required this.perfil});

  bool get ehTrabalhador => perfil == Perfil.trabalhador;

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as int,
        nome: json['nome'] as String,
        perfil: json['perfil'] == 'trabalhador' ? Perfil.trabalhador : Perfil.cidadao,
      );

  Map<String, dynamic> toJson() => {'id': id, 'nome': nome, 'perfil': perfil.name};
}
