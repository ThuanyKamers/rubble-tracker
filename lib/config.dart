// Endereço da API. No emulador Android, 10.0.2.2 aponta para o computador.
// Em um celular de verdade use o IP do computador na rede, por exemplo:
//   flutter run --dart-define=API_URL=http://192.168.0.10:3000
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

// Precisão mínima do GPS para registrar um entulho (igual à do servidor).
const double precisaoMaximaGpsM = 20;

// Centro de Palhoça, usado enquanto o GPS ainda não respondeu.
const double latitudeInicial = -27.6481;
const double longitudeInicial = -48.6675;
