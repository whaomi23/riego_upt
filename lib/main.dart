import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riego UPT (Control de Bombas)',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[900],
        cardColor: Colors.grey[800],
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      _mostrarInformacionInicial();
    });
  }

  Future<void> _abrirManualPDF() async {
    const url = 'https://ejemplo.com/manual-riego.pdf'; // Reemplazar con la URL real del PDF
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el manual'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarInformacionInicial() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Bienvenido al Sistema de Riego',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Funcionamiento:',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '• El sistema permite controlar múltiples bombas de riego\n'
                  '• Cada bomba puede ser controlada individualmente\n'
                  '• Se puede configurar el tiempo de riego\n'
                  '• Las bombas pueden ser pausadas y reanudadas\n'
                  '• El sistema muestra el estado en tiempo real',
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 20),
                Text(
                  'Configuración:',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '• Configure la IP del ESP32 en la sección de conexión\n'
                  '• Verifique el estado de conexión antes de operar\n'
                  '• Ingrese el tiempo de riego en segundos\n'
                  '• Utilice los controles para encender/apagar las bombas',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: _abrirManualPDF,
              icon: const Icon(Icons.menu_book, color: Colors.blue),
              label: const Text(
                'Ver Manual Completo',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MainPage()),
                );
              },
              child: const Text(
                'Entendido',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.water_drop,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sistema de Riego',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Cargando...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late HttpServer _server;
  final Map<String, BombaEstado> _estadoBombas = {
    'bomba1': BombaEstado(),
    'bomba2': BombaEstado(),
    'bomba3': BombaEstado(),
    'bomba4': BombaEstado(),
    'bomba5': BombaEstado(),
    'bomba6': BombaEstado(),
  };
  bool _isServerRunning = false;
  String _esp32Ip = '192.168.4.4';
  int _serverPort = 5000;
  final http.Client _httpClient = http.Client();
  bool _bomba1Encendida = false;
  bool _bomba2Encendida = false;
  bool _bomba3Encendida = false;
  bool _bomba4Encendida = false;
  bool _bomba5Encendida = false;
  bool _bomba6Encendida = false;
  int _tiempoRestanteBomba1 = 0;
  int _tiempoRestanteBomba2 = 0;
  int _tiempoRestanteBomba3 = 0;
  int _tiempoRestanteBomba4 = 0;
  int _tiempoRestanteBomba5 = 0;
  int _tiempoRestanteBomba6 = 0;
  bool _bomba1Pausada = false;
  bool _bomba2Pausada = false;
  bool _bomba3Pausada = false;
  bool _bomba4Pausada = false;
  bool _bomba5Pausada = false;
  bool _bomba6Pausada = false;
  bool _servidorConectado = false;
  int _latencia = 0;
  int _bytesTransmitidos = 0;
  Timer? _estadoTimer;
  Timer? _pingTimer;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _tiempoBomba1Controller = TextEditingController();
  final TextEditingController _tiempoBomba2Controller = TextEditingController();
  final TextEditingController _tiempoBomba3Controller = TextEditingController();
  final TextEditingController _tiempoBomba4Controller = TextEditingController();
  final TextEditingController _tiempoBomba5Controller = TextEditingController();
  final TextEditingController _tiempoBomba6Controller = TextEditingController();
  Timer? _timerBomba1;
  Timer? _timerBomba2;
  Timer? _timerBomba3;
  Timer? _timerBomba4;
  Timer? _timerBomba5;
  Timer? _timerBomba6;

  @override
  void initState() {
    super.initState();
    _ipController.text = _esp32Ip;
    _iniciarServidor().then((_) {
    _iniciarTimers();
    });
  }

  @override
  void dispose() {
    _liberarRecursos();
    _ipController.dispose();
    _tiempoBomba1Controller.dispose();
    _tiempoBomba2Controller.dispose();
    _tiempoBomba3Controller.dispose();
    _tiempoBomba4Controller.dispose();
    _tiempoBomba5Controller.dispose();
    _tiempoBomba6Controller.dispose();
    super.dispose();
  }

  void _iniciarTimers() {
    _estadoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _verificarConexion();
      if (_servidorConectado) {
        _actualizarEstado();
      }
    });
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> _verificarConexion() async {
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(_esp32Ip, 80, timeout: const Duration(seconds: 2));
      socket.destroy();
      stopwatch.stop();

      setState(() {
        _servidorConectado = true;
        _latencia = stopwatch.elapsedMilliseconds;
      });
    } catch (e) {
      setState(() {
        _servidorConectado = false;
        _latencia = 0;
      });
      
      // Si la conexión se pierde, intentar reconectar automáticamente
      if (_isServerRunning) {
        debugPrint('Conexión perdida, intentando reconectar...');
        _reconectarAutomaticamente();
      }
    }
  }

  Future<void> _configurarIPESP32(String ip) async {
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 1));
      socket.destroy();
      stopwatch.stop();

      setState(() {
        _esp32Ip = ip;
        _servidorConectado = true;
        _latencia = stopwatch.elapsedMilliseconds;
      });
      _mostrarAlerta('Éxito', 'ESP32 encontrado en IP: $ip');
    } catch (e) {
      setState(() {
        _servidorConectado = false;
        _latencia = 0;
      });
      _mostrarAlerta('Error', 'No se pudo conectar al ESP32 en la IP especificada');
    }
  }

  Future<void> _actualizarEstado() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('http://$_esp32Ip/estado'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        debugPrint('JSON recibido: $json');

        final estado = EstadoBombas.fromJson(json);

        // Solo actualizamos el estado si no hay un temporizador activo
        if (_timerBomba1 == null || !_timerBomba1!.isActive) {
          setState(() {
            _bomba1Encendida = estado.bomba1.encendida;
            _tiempoRestanteBomba1 = estado.bomba1.tiempo;
            _bomba1Pausada = estado.bomba1.pausada;
          });
        }
        
        if (_timerBomba2 == null || !_timerBomba2!.isActive) {
          setState(() {
            _bomba2Encendida = estado.bomba2.encendida;
            _tiempoRestanteBomba2 = estado.bomba2.tiempo;
            _bomba2Pausada = estado.bomba2.pausada;
          });
        }
        
        if (_timerBomba3 == null || !_timerBomba3!.isActive) {
          setState(() {
            _bomba3Encendida = estado.bomba3.encendida;
            _tiempoRestanteBomba3 = estado.bomba3.tiempo;
            _bomba3Pausada = estado.bomba3.pausada;
          });
        }
        
        if (_timerBomba4 == null || !_timerBomba4!.isActive) {
          setState(() {
            _bomba4Encendida = estado.bomba4.encendida;
            _tiempoRestanteBomba4 = estado.bomba4.tiempo;
            _bomba4Pausada = estado.bomba4.pausada;
          });
        }
        
        if (_timerBomba5 == null || !_timerBomba5!.isActive) {
          setState(() {
            _bomba5Encendida = estado.bomba5.encendida;
            _tiempoRestanteBomba5 = estado.bomba5.tiempo;
            _bomba5Pausada = estado.bomba5.pausada;
          });
        }
        
        if (_timerBomba6 == null || !_timerBomba6!.isActive) {
          setState(() {
            _bomba6Encendida = estado.bomba6.encendida;
            _tiempoRestanteBomba6 = estado.bomba6.tiempo;
            _bomba6Pausada = estado.bomba6.pausada;
          });
        }
      } else {
        _mostrarAlerta('Error', 'Respuesta inesperada del ESP32');
      }
    } catch (e) {
      debugPrint('Error al actualizar estado: $e');
    }
  }

  Future<void> _limpiarRecursosAplicacion() async {
    try {
      debugPrint('Limpiando recursos específicos de la aplicación...');
      
      // Limpiar estados de las bombas
      setState(() {
        _bomba1Encendida = false;
        _bomba2Encendida = false;
        _bomba3Encendida = false;
        _bomba4Encendida = false;
        _bomba5Encendida = false;
        _bomba6Encendida = false;
        _tiempoRestanteBomba1 = 0;
        _tiempoRestanteBomba2 = 0;
        _tiempoRestanteBomba3 = 0;
        _tiempoRestanteBomba4 = 0;
        _tiempoRestanteBomba5 = 0;
        _tiempoRestanteBomba6 = 0;
        _bomba1Pausada = false;
        _bomba2Pausada = false;
        _bomba3Pausada = false;
        _bomba4Pausada = false;
        _bomba5Pausada = false;
        _bomba6Pausada = false;
        _servidorConectado = false;
        _latencia = 0;
        _bytesTransmitidos = 0;
      });
      
      // Limpiar controllers
      _tiempoBomba1Controller.clear();
      _tiempoBomba2Controller.clear();
      _tiempoBomba3Controller.clear();
      _tiempoBomba4Controller.clear();
      _tiempoBomba5Controller.clear();
      _tiempoBomba6Controller.clear();
      
      debugPrint('Recursos de la aplicación limpiados');
    } catch (e) {
      debugPrint('Error limpiando recursos de la aplicación: $e');
    }
  }

  Future<void> _enviarComando(String bomba, String accion, int tiempo) async {
    try {
      final comando = {
        'bomba': bomba,
        'accion': accion,
        'tiempo': tiempo,
      };

      final response = await _httpClient
          .post(
            Uri.parse('http://$_esp32Ip/control'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(comando),
          )
          .timeout(const Duration(seconds: 10)); // Aumentado el timeout

      _bytesTransmitidos += jsonEncode(comando).length;

      if (response.statusCode == 200) {
        await _actualizarEstado();
      } else {
        debugPrint('Error HTTP ${response.statusCode}: ${response.body}');
        _mostrarAlerta('Error', 'Error al enviar comando: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error de comunicación: $e');
      _mostrarAlerta('Error', 'Error de comunicación: ${e.toString()}\n\nVerifique la conexión con el ESP32.');
      
      // Si hay error de conexión, intentar reconectar
      if (e.toString().contains('SocketException') || e.toString().contains('Connection refused')) {
        _reconectarAutomaticamente();
      }
    }
  }

  Future<bool> _verificarYLiberarPuerto(int puerto) async {
    try {
      // Primero intentamos conectar para verificar si el puerto está en uso
      final socket = await Socket.connect('localhost', puerto, timeout: const Duration(seconds: 1));
      socket.destroy();
      
      debugPrint('Puerto $puerto está en uso. Intentando liberar...');
      
      // Detectar la plataforma para usar el comando correcto
      if (Platform.isWindows) {
        return await _liberarPuertoWindows(puerto);
      } else if (Platform.isAndroid) {
        return await _liberarPuertoAndroid(puerto);
      } else {
        // Para otras plataformas (Linux, macOS, etc.)
        return await _liberarPuertoUnix(puerto);
      }
    } catch (e) {
      debugPrint('Puerto $puerto está libre: $e');
      return true;
    }
  }

  Future<bool> _liberarPuertoWindows(int puerto) async {
    try {
      // Usar netstat para encontrar procesos usando el puerto
      final result = await Process.run('netstat', ['-ano', '-p', 'TCP']);
      final output = result.stdout.toString();
      
      final lines = output.split('\n');
      for (var line in lines) {
        if (line.contains(':$puerto') && line.contains('LISTENING')) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 5) {
            final pid = parts[parts.length - 1];
            debugPrint('Encontrado proceso con PID $pid usando puerto $puerto');
            
            // Intentar terminar el proceso
            try {
              final killResult = await Process.run('taskkill', ['/F', '/PID', pid]);
              if (killResult.exitCode == 0) {
                debugPrint('Proceso con PID $pid terminado exitosamente');
                // Esperar un momento para que el puerto se libere
                await Future.delayed(const Duration(milliseconds: 500));
                return true;
              } else {
                debugPrint('Error al terminar proceso $pid: ${killResult.stderr}');
              }
            } catch (e) {
              debugPrint('Error ejecutando taskkill: $e');
            }
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error en _liberarPuertoWindows: $e');
      return false;
    }
  }

  Future<bool> _liberarPuertoAndroid(int puerto) async {
    try {
      // En Android, usar ps y kill para encontrar y terminar procesos
      final psResult = await Process.run('ps', []);
      final psOutput = psResult.stdout.toString();
      
      // Buscar procesos que puedan estar usando el puerto
      final lines = psOutput.split('\n');
      for (var line in lines) {
        if (line.contains(':$puerto') || line.contains(':$puerto ')) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.isNotEmpty) {
            final pid = parts[0];
            debugPrint('Encontrado proceso con PID $pid usando puerto $puerto');
            
            try {
              final killResult = await Process.run('kill', ['-9', pid]);
              if (killResult.exitCode == 0) {
                debugPrint('Proceso con PID $pid terminado exitosamente');
                await Future.delayed(const Duration(milliseconds: 500));
                return true;
              }
            } catch (e) {
              debugPrint('Error ejecutando kill: $e');
            }
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error en _liberarPuertoAndroid: $e');
      return false;
    }
  }

  Future<bool> _liberarPuertoUnix(int puerto) async {
    try {
      // Para sistemas Unix-like (Linux, macOS)
      final lsofResult = await Process.run('lsof', ['-ti', ':$puerto']);
      if (lsofResult.exitCode == 0 && lsofResult.stdout.toString().isNotEmpty) {
        final pids = lsofResult.stdout.toString().trim().split('\n');
        for (var pid in pids) {
          if (pid.isNotEmpty) {
            debugPrint('Encontrado proceso con PID $pid usando puerto $puerto');
            try {
              final killResult = await Process.run('kill', ['-9', pid]);
              if (killResult.exitCode == 0) {
                debugPrint('Proceso con PID $pid terminado exitosamente');
              }
            } catch (e) {
              debugPrint('Error ejecutando kill: $e');
            }
          }
        }
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error en _liberarPuertoUnix: $e');
      return false;
    }
  }

  Future<void> _liberarRecursos() async {
    try {
      debugPrint('Liberando recursos del sistema...');
      
      // Cancelar todos los timers
      _estadoTimer?.cancel();
      _pingTimer?.cancel();
      _timerBomba1?.cancel();
      _timerBomba2?.cancel();
      _timerBomba3?.cancel();
      _timerBomba4?.cancel();
      _timerBomba5?.cancel();
      _timerBomba6?.cancel();
      
      // Cerrar el servidor HTTP
      if (_isServerRunning) {
        await _server.close(force: true);
        setState(() {
          _isServerRunning = false;
        });
      }
      
      // Cerrar el cliente HTTP
      _httpClient.close();
      
      // Liberar puertos específicos si están en uso
      await _verificarYLiberarPuerto(_serverPort);
      
      // Limpiar recursos de la aplicación
      await _limpiarRecursosAplicacion();
      
      debugPrint('Recursos liberados exitosamente');
    } catch (e) {
      debugPrint('Error liberando recursos: $e');
    }
  }

  Future<void> _liberarPuertosComunes() async {
    try {
      debugPrint('Verificando y liberando puertos comunes...');
      
      // Lista de puertos comunes que podrían estar en uso
      final puertosComunes = [5000, 5001, 8080, 3000, 8000, 9000];
      
      for (var puerto in puertosComunes) {
        await _verificarYLiberarPuerto(puerto);
      }
      
      debugPrint('Verificación de puertos comunes completada');
    } catch (e) {
      debugPrint('Error verificando puertos comunes: $e');
    }
  }

  Future<void> _iniciarServidor() async {
    try {
      // Primero liberar puertos comunes que podrían estar en uso
      await _liberarPuertosComunes();
      
      // Luego verificar específicamente el puerto del servidor
      await _verificarYLiberarPuerto(_serverPort);
      
      // Esperar un momento para asegurar que los puertos estén libres
      await Future.delayed(const Duration(milliseconds: 1000));
      
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _serverPort);
      setState(() {
        _isServerRunning = true;
      });

      _mostrarAlerta('Servidor Iniciado',
          'Servidor escuchando en:\nPuerto: $_serverPort\n\nPara el ESP32, use esta URL:\nhttp://${_server.address.host}:$_serverPort/estado');

      await for (HttpRequest request in _server) {
        _procesarPeticion(request);
      }
    } catch (e) {
      debugPrint('Error al iniciar el servidor: $e');
      _mostrarAlerta('Error', 'Error al iniciar el servidor: ${e.toString()}\n\nVerifique que el puerto $_serverPort esté disponible.');
    }
  }

  Future<void> _detenerServidor() async {
    if (_isServerRunning) {
      await _liberarRecursos();
    }
  }

  Future<void> _procesarPeticion(HttpRequest request) async {
    try {
      HttpResponse response = request.response;
      String responseString = '';

      switch (request.uri.path) {
        case '/estado':
          responseString = jsonEncode({
            'bomba1': _estadoBombas['bomba1']?.toJson(),
            'bomba2': _estadoBombas['bomba2']?.toJson(),
            'bomba3': _estadoBombas['bomba3']?.toJson(),
            'bomba4': _estadoBombas['bomba4']?.toJson(),
            'bomba5': _estadoBombas['bomba5']?.toJson(),
            'bomba6': _estadoBombas['bomba6']?.toJson(),
          });
          response.headers.contentType = ContentType.json;
          _bytesTransmitidos += responseString.length;
          break;

        case '/control':
          if (request.method == 'POST') {
            final content = await utf8.decoder.bind(request).join();
            _bytesTransmitidos += content.length;
            final controlRequest = ControlRequest.fromJson(jsonDecode(content));

            if (_estadoBombas.containsKey(controlRequest.bomba)) {
              final bomba = _estadoBombas[controlRequest.bomba]!;
              bomba.encendida = controlRequest.accion == 'encender';
              bomba.tiempo = controlRequest.tiempo;
              response.statusCode = HttpStatus.ok;
            } else {
              response.statusCode = HttpStatus.notFound;
            }
          }
          break;

        default:
          response.statusCode = HttpStatus.notFound;
          break;
      }

      if (responseString.isNotEmpty) {
        response.write(responseString);
      }
      await response.close();
    } catch (e) {
      _mostrarAlerta('Error', 'Error procesando petición: ${e.toString()}');
    }
  }

  void _mostrarAlerta(String titulo, String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _iniciarTemporizadorBomba1(int tiempo) {
    _timerBomba1?.cancel();
    setState(() {
      _tiempoRestanteBomba1 = tiempo;
      _bomba1Encendida = true;
      _bomba1Pausada = false;
    });
    _timerBomba1 = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_tiempoRestanteBomba1 > 0) {
          _tiempoRestanteBomba1--;
        } else {
          _timerBomba1?.cancel();
          setState(() {
            _bomba1Encendida = false;
          });
          _enviarComando('bomba1', 'apagar', 0);
        }
      });
    });
  }

  void _iniciarTemporizadorBomba2(int tiempo) {
    _timerBomba2?.cancel();
    setState(() {
      _tiempoRestanteBomba2 = tiempo;
      _bomba2Encendida = true;
      _bomba2Pausada = false;
    });
    _timerBomba2 = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_tiempoRestanteBomba2 > 0) {
          _tiempoRestanteBomba2--;
        } else {
          _timerBomba2?.cancel();
          setState(() {
            _bomba2Encendida = false;
          });
          _enviarComando('bomba2', 'apagar', 0);
        }
      });
    });
  }

  void _pausarTemporizadorBomba1() {
    _timerBomba1?.cancel();
    setState(() {
      _bomba1Pausada = true;
    });
  }

  void _reanudarTemporizadorBomba1() {
    if (_tiempoRestanteBomba1 > 0) {
      _iniciarTemporizadorBomba1(_tiempoRestanteBomba1);
      setState(() {
        _bomba1Pausada = false;
      });
    }
  }

  void _pausarTemporizadorBomba2() {
    _timerBomba2?.cancel();
    setState(() {
      _bomba2Pausada = true;
    });
  }

  void _reanudarTemporizadorBomba2() {
    if (_tiempoRestanteBomba2 > 0) {
      _iniciarTemporizadorBomba2(_tiempoRestanteBomba2);
      setState(() {
        _bomba2Pausada = false;
      });
    }
  }

  void _iniciarTemporizadorBomba3(int tiempo) {
    _timerBomba3?.cancel();
    setState(() {
      _tiempoRestanteBomba3 = tiempo;
      _bomba3Encendida = true;
      _bomba3Pausada = false;
    });
    _timerBomba3 = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_tiempoRestanteBomba3 > 0) {
          _tiempoRestanteBomba3--;
        } else {
          _timerBomba3?.cancel();
          setState(() {
            _bomba3Encendida = false;
          });
          _enviarComando('bomba3', 'apagar', 0);
        }
      });
    });
  }

  void _iniciarTemporizadorBomba4(int tiempo) {
    _timerBomba4?.cancel();
    setState(() {
      _tiempoRestanteBomba4 = tiempo;
      _bomba4Encendida = true;
      _bomba4Pausada = false;
    });
    _timerBomba4 = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_tiempoRestanteBomba4 > 0) {
          _tiempoRestanteBomba4--;
        } else {
          _timerBomba4?.cancel();
          setState(() {
            _bomba4Encendida = false;
          });
          _enviarComando('bomba4', 'apagar', 0);
        }
      });
    });
  }

  void _iniciarTemporizadorBomba5(int tiempo) {
    _timerBomba5?.cancel();
    setState(() {
      _tiempoRestanteBomba5 = tiempo;
      _bomba5Encendida = true;
      _bomba5Pausada = false;
    });
    _timerBomba5 = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_tiempoRestanteBomba5 > 0) {
          _tiempoRestanteBomba5--;
        } else {
          _timerBomba5?.cancel();
          setState(() {
            _bomba5Encendida = false;
          });
          _enviarComando('bomba5', 'apagar', 0);
        }
      });
    });
  }

  void _iniciarTemporizadorBomba6(int tiempo) {
    _timerBomba6?.cancel();
    setState(() {
      _tiempoRestanteBomba6 = tiempo;
      _bomba6Encendida = true;
      _bomba6Pausada = false;
    });
    _timerBomba6 = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_tiempoRestanteBomba6 > 0) {
          _tiempoRestanteBomba6--;
        } else {
          _timerBomba6?.cancel();
          setState(() {
            _bomba6Encendida = false;
          });
          _enviarComando('bomba6', 'apagar', 0);
        }
      });
    });
  }

  void _pausarTemporizadorBomba3() {
    _timerBomba3?.cancel();
    setState(() {
      _bomba3Pausada = true;
    });
  }

  void _reanudarTemporizadorBomba3() {
    if (_tiempoRestanteBomba3 > 0) {
      _iniciarTemporizadorBomba3(_tiempoRestanteBomba3);
      setState(() {
        _bomba3Pausada = false;
      });
    }
  }

  void _pausarTemporizadorBomba4() {
    _timerBomba4?.cancel();
    setState(() {
      _bomba4Pausada = true;
    });
  }

  void _reanudarTemporizadorBomba4() {
    if (_tiempoRestanteBomba4 > 0) {
      _iniciarTemporizadorBomba4(_tiempoRestanteBomba4);
      setState(() {
        _bomba4Pausada = false;
      });
    }
  }

  void _pausarTemporizadorBomba5() {
    _timerBomba5?.cancel();
    setState(() {
      _bomba5Pausada = true;
    });
  }

  void _reanudarTemporizadorBomba5() {
    if (_tiempoRestanteBomba5 > 0) {
      _iniciarTemporizadorBomba5(_tiempoRestanteBomba5);
      setState(() {
        _bomba5Pausada = false;
      });
    }
  }

  void _pausarTemporizadorBomba6() {
    _timerBomba6?.cancel();
    setState(() {
      _bomba6Pausada = true;
    });
  }

  void _reanudarTemporizadorBomba6() {
    if (_tiempoRestanteBomba6 > 0) {
      _iniciarTemporizadorBomba6(_tiempoRestanteBomba6);
      setState(() {
        _bomba6Pausada = false;
      });
    }
  }

  Future<void> _reconectarAutomaticamente() async {
    try {
      debugPrint('Intentando reconexión automática...');
      
      // Liberar recursos actuales
      await _liberarRecursos();
      
      // Esperar un momento antes de reintentar
      await Future.delayed(const Duration(seconds: 2));
      
      // Reintentar la conexión
      await _iniciarServidor();
      
      debugPrint('Reconexión automática completada');
    } catch (e) {
      debugPrint('Error en reconexión automática: $e');
      _mostrarAlerta('Error de Conexión', 'No se pudo reconectar automáticamente. Verifique la configuración de red.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riego UPT (Control de Bombas)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección de conexión
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuración de Conexión',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        TextField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            labelText: 'IP del ESP32',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () => _configurarIPESP32(_ipController.text),
                          child: const Text('Configurar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          _servidorConectado ? Icons.check_circle : Icons.error,
                          color: _servidorConectado ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Estado: ${_servidorConectado ? 'Conectado (Latencia: ${_latencia}ms)' : 'Desconectado'}',
                          style: TextStyle(
                            color: _servidorConectado
                                ? (_latencia < 100
                                    ? Colors.green
                                    : (_latencia < 300
                                        ? Colors.yellow
                                        : Colors.red))
                                : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Sección Bomba 1
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1 (Bomba de Riego) O Valvula Solenoide',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estado: ${_bomba1Encendida ? 'Encendida' : 'Apagada'}',
                          style: TextStyle(
                            color: _bomba1Encendida ? Colors.green : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: _bomba1Encendida,
                          activeColor: Colors.orange,
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.shade300,
                          onChanged: (value) {
                            if (value) {
                              _enviarComando('bomba1', 'encender', 0);
                            } else {
                              _enviarComando('bomba1', 'apagar', 0);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Tiempo restante: $_tiempoRestanteBomba1 segundos'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tiempoBomba1Controller,
                            decoration: const InputDecoration(
                              labelText: 'Tiempo en segundos',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _tiempoBomba1Controller.clear();
                          },
                          icon: const Icon(Icons.clear),
                          color: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            final tiempo = int.tryParse(_tiempoBomba1Controller.text);
                            if (tiempo != null && tiempo > 0) {
                              _enviarComando('bomba1', 'encender', 0);
                              setState(() {
                                _bomba1Encendida = true;
                                _bomba1Pausada = false;
                              });
                              _iniciarTemporizadorBomba1(tiempo);
                            } else {
                              _mostrarAlerta('Error', 'Por favor ingrese un tiempo válido en segundos');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Iniciar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (_bomba1Pausada) {
                              _reanudarTemporizadorBomba1();
                              _enviarComando('bomba1', 'reanudar', _tiempoRestanteBomba1);
                            } else {
                              _pausarTemporizadorBomba1();
                              _enviarComando('bomba1', 'pausar', 0);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _bomba1Pausada ? Colors.orange : Colors.grey,
                          ),
                          child: Text(_bomba1Pausada ? 'Reanudar' : 'Pausar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Sección Bomba 2
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '2 (Bomba de Riego) O Valvula Solenoide',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estado: ${_bomba2Encendida ? 'Encendida' : 'Apagada'}',
                          style: TextStyle(
                            color: _bomba2Encendida ? Colors.green : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: _bomba2Encendida,
                          activeColor: Colors.orange,
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.shade300,
                          onChanged: (value) {
                            if (value) {
                              _enviarComando('bomba2', 'encender', 0);
                            } else {
                              _enviarComando('bomba2', 'apagar', 0);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Tiempo restante: $_tiempoRestanteBomba2 segundos'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tiempoBomba2Controller,
                            decoration: const InputDecoration(
                              labelText: 'Tiempo en segundos',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _tiempoBomba2Controller.clear();
                          },
                          icon: const Icon(Icons.clear),
                          color: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            final tiempo = int.tryParse(_tiempoBomba2Controller.text);
                            if (tiempo != null && tiempo > 0) {
                              _enviarComando('bomba2', 'encender', 0);
                              setState(() {
                                _bomba2Encendida = true;
                                _bomba2Pausada = false;
                              });
                              _iniciarTemporizadorBomba2(tiempo);
                            } else {
                              _mostrarAlerta('Error', 'Por favor ingrese un tiempo válido en segundos');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Iniciar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (_bomba2Pausada) {
                              _reanudarTemporizadorBomba2();
                              _enviarComando('bomba2', 'reanudar', _tiempoRestanteBomba2);
                            } else {
                              _pausarTemporizadorBomba2();
                              _enviarComando('bomba2', 'pausar', 0);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _bomba2Pausada ? Colors.orange : Colors.grey,
                          ),
                          child: Text(_bomba2Pausada ? 'Reanudar' : 'Pausar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Sección Bomba 3
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '3 (Bomba de Riego) O Valvula Solenoide',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estado: ${_bomba3Encendida ? 'Encendida' : 'Apagada'}',
                          style: TextStyle(
                            color: _bomba3Encendida ? Colors.green : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: _bomba3Encendida,
                          activeColor: Colors.orange,
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.shade300,
                          onChanged: (value) {
                            if (value) {
                              _enviarComando('bomba3', 'encender', 0);
                            } else {
                              _enviarComando('bomba3', 'apagar', 0);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Tiempo restante: $_tiempoRestanteBomba3 segundos'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tiempoBomba3Controller,
                            decoration: const InputDecoration(
                              labelText: 'Tiempo en segundos',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _tiempoBomba3Controller.clear();
                          },
                          icon: const Icon(Icons.clear),
                          color: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            final tiempo = int.tryParse(_tiempoBomba3Controller.text);
                            if (tiempo != null && tiempo > 0) {
                              _enviarComando('bomba3', 'encender', 0);
                              setState(() {
                                _bomba3Encendida = true;
                                _bomba3Pausada = false;
                              });
                              _iniciarTemporizadorBomba3(tiempo);
                            } else {
                              _mostrarAlerta('Error', 'Por favor ingrese un tiempo válido en segundos');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Iniciar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (_bomba3Pausada) {
                              _reanudarTemporizadorBomba3();
                              _enviarComando('bomba3', 'reanudar', _tiempoRestanteBomba3);
                            } else {
                              _pausarTemporizadorBomba3();
                              _enviarComando('bomba3', 'pausar', 0);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _bomba3Pausada ? Colors.orange : Colors.grey,
                          ),
                          child: Text(_bomba3Pausada ? 'Reanudar' : 'Pausar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Sección Bomba 4
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '4 (Bomba de Riego) O Valvula Solenoide',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estado: ${_bomba4Encendida ? 'Encendida' : 'Apagada'}',
                          style: TextStyle(
                            color: _bomba4Encendida ? Colors.green : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: _bomba4Encendida,
                          activeColor: Colors.orange,
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.shade300,
                          onChanged: (value) {
                            if (value) {
                              _enviarComando('bomba4', 'encender', 0);
                            } else {
                              _enviarComando('bomba4', 'apagar', 0);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Tiempo restante: $_tiempoRestanteBomba4 segundos'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tiempoBomba4Controller,
                            decoration: const InputDecoration(
                              labelText: 'Tiempo en segundos',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _tiempoBomba4Controller.clear();
                          },
                          icon: const Icon(Icons.clear),
                          color: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            final tiempo = int.tryParse(_tiempoBomba4Controller.text);
                            if (tiempo != null && tiempo > 0) {
                              _enviarComando('bomba4', 'encender', 0);
                              setState(() {
                                _bomba4Encendida = true;
                                _bomba4Pausada = false;
                              });
                              _iniciarTemporizadorBomba4(tiempo);
                            } else {
                              _mostrarAlerta('Error', 'Por favor ingrese un tiempo válido en segundos');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Iniciar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (_bomba4Pausada) {
                              _reanudarTemporizadorBomba4();
                              _enviarComando('bomba4', 'reanudar', _tiempoRestanteBomba4);
                            } else {
                              _pausarTemporizadorBomba4();
                              _enviarComando('bomba4', 'pausar', 0);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _bomba4Pausada ? Colors.orange : Colors.grey,
                          ),
                          child: Text(_bomba4Pausada ? 'Reanudar' : 'Pausar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Sección Bomba 5
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '5 (Bomba de Riego) O Valvula Solenoide',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estado: ${_bomba5Encendida ? 'Encendida' : 'Apagada'}',
                          style: TextStyle(
                            color: _bomba5Encendida ? Colors.green : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: _bomba5Encendida,
                          activeColor: Colors.orange,
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.shade300,
                          onChanged: (value) {
                            if (value) {
                              _enviarComando('bomba5', 'encender', 0);
                            } else {
                              _enviarComando('bomba5', 'apagar', 0);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Tiempo restante: $_tiempoRestanteBomba5 segundos'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tiempoBomba5Controller,
                            decoration: const InputDecoration(
                              labelText: 'Tiempo en segundos',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _tiempoBomba5Controller.clear();
                          },
                          icon: const Icon(Icons.clear),
                          color: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            final tiempo = int.tryParse(_tiempoBomba5Controller.text);
                            if (tiempo != null && tiempo > 0) {
                              _enviarComando('bomba5', 'encender', 0);
                              setState(() {
                                _bomba5Encendida = true;
                                _bomba5Pausada = false;
                              });
                              _iniciarTemporizadorBomba5(tiempo);
                            } else {
                              _mostrarAlerta('Error', 'Por favor ingrese un tiempo válido en segundos');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Iniciar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (_bomba5Pausada) {
                              _reanudarTemporizadorBomba5();
                              _enviarComando('bomba5', 'reanudar', _tiempoRestanteBomba5);
                            } else {
                              _pausarTemporizadorBomba5();
                              _enviarComando('bomba5', 'pausar', 0);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _bomba5Pausada ? Colors.orange : Colors.grey,
                          ),
                          child: Text(_bomba5Pausada ? 'Reanudar' : 'Pausar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Sección Bomba 6
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '6 (Bomba de Riego) O Valvula Solenoide',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estado: ${_bomba6Encendida ? 'Encendida' : 'Apagada'}',
                          style: TextStyle(
                            color: _bomba6Encendida ? Colors.green : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: _bomba6Encendida,
                          activeColor: Colors.orange,
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.shade300,
                          onChanged: (value) {
                            if (value) {
                              _enviarComando('bomba6', 'encender', 0);
                            } else {
                              _enviarComando('bomba6', 'apagar', 0);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Tiempo restante: $_tiempoRestanteBomba6 segundos'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tiempoBomba6Controller,
                            decoration: const InputDecoration(
                              labelText: 'Tiempo en segundos',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _tiempoBomba6Controller.clear();
                          },
                          icon: const Icon(Icons.clear),
                          color: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            final tiempo = int.tryParse(_tiempoBomba6Controller.text);
                            if (tiempo != null && tiempo > 0) {
                              _enviarComando('bomba6', 'encender', 0);
                              setState(() {
                                _bomba6Encendida = true;
                                _bomba6Pausada = false;
                              });
                              _iniciarTemporizadorBomba6(tiempo);
                            } else {
                              _mostrarAlerta('Error', 'Por favor ingrese un tiempo válido en segundos');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Iniciar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (_bomba6Pausada) {
                              _reanudarTemporizadorBomba6();
                              _enviarComando('bomba6', 'reanudar', _tiempoRestanteBomba6);
                            } else {
                              _pausarTemporizadorBomba6();
                              _enviarComando('bomba6', 'pausar', 0);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _bomba6Pausada ? Colors.orange : Colors.grey,
                          ),
                          child: Text(_bomba6Pausada ? 'Reanudar' : 'Pausar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Control para todas las bombas
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Control de Todas las Bombas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => _enviarComando('todas', 'encender', 0),
                          child: const Text('Encender Todas'),
                        ),
                        ElevatedButton(
                          onPressed: () => _enviarComando('todas', 'apagar', 0),
                          child: const Text('Apagar Todas'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BombaEstado {
  bool encendida = false;
  int tiempo = 0;

  Map<String, dynamic> toJson() => {
        'encendida': encendida,
        'tiempo': tiempo,
      };
}

class ControlRequest {
  final String bomba;
  final String accion;
  final int tiempo;

  ControlRequest({
    required this.bomba,
    required this.accion,
    required this.tiempo,
  });

  factory ControlRequest.fromJson(Map<String, dynamic> json) => ControlRequest(
        bomba: json['bomba'],
        accion: json['accion'],
        tiempo: json['tiempo'],
      );
}

class EstadoBombas {
  final EstadoBomba bomba1;
  final EstadoBomba bomba2;
  final EstadoBomba bomba3;
  final EstadoBomba bomba4;
  final EstadoBomba bomba5;
  final EstadoBomba bomba6;

  EstadoBombas({
    required this.bomba1,
    required this.bomba2,
    required this.bomba3,
    required this.bomba4,
    required this.bomba5,
    required this.bomba6,
  });

  factory EstadoBombas.fromJson(Map<String, dynamic> json) => EstadoBombas(
        bomba1: EstadoBomba.fromJson(json['bomba1']),
        bomba2: EstadoBomba.fromJson(json['bomba2']),
        bomba3: EstadoBomba.fromJson(json['bomba3']),
        bomba4: EstadoBomba.fromJson(json['bomba4']),
        bomba5: EstadoBomba.fromJson(json['bomba5']),
        bomba6: EstadoBomba.fromJson(json['bomba6']),
      );
}

class EstadoBomba {
  final bool encendida;
  final int tiempo;
  final bool pausada;

  EstadoBomba({
    required this.encendida,
    required this.tiempo,
    required this.pausada,
  });

  factory EstadoBomba.fromJson(Map<String, dynamic> json) => EstadoBomba(
        encendida: json['encendida'],
        tiempo: json['tiempo'],
        pausada: json['pausada'] ?? false,
      );
}