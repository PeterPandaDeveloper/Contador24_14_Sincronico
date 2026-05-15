import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(ContadorSincronicoApp());
}

class ContadorSincronicoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Contador 24 14 Sincronico',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: TimerRomuloPage(),
    );
  }
}

class TimerRomuloPage extends StatefulWidget {
  @override
  _TimerRomuloPageState createState() => _TimerRomuloPageState();
}

class _TimerRomuloPageState extends State<TimerRomuloPage> {
  BluetoothConnection? connection;
  int tiempoRestante = 0;
  int ultimoTiempoSeteado = 24; 
  Timer? _timer;
  
  String logStatus = "Sin conexión Bluetooth";
  final TextEditingController _timeController = TextEditingController();

  final Color fondoOscuro = const Color(0xFF0A192F); 
  final Color amarilloFrey = const Color(0xFFFFD600); 
  final Color botonGris = const Color(0xFF1E293B);

  void conectarBluetooth() async {
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      if (!mounted) return;

      BluetoothDevice? selectedDevice = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Seleccionar Módulo App"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(devices[i].name ?? "Desconocido"),
                subtitle: Text(devices[i].address),
                onTap: () => Navigator.pop(context, devices[i]),
              ),
            ),
          ),
        ),
      );

      if (selectedDevice != null) {
        setState(() => logStatus = "Conectando...");
        connection = await BluetoothConnection.toAddress(selectedDevice.address);
        setState(() => logStatus = "Conectado a ${selectedDevice.name}");
      }
    } catch (e) {
      setState(() => logStatus = "Error de conexión");
    }
  }

  // =======================================================================
  // HACK DE LA METRALLETA: Envía ráfagas de 3 bytes para penetrar los 115200
  // =======================================================================
  void enviarComandoByte(int byteCmd, int seg) async {
    if (connection != null && connection!.isConnected) {
      
      // Disparamos 3 veces el mismo comando súper rápido
      for(int i = 0; i < 3; i++) {
        connection!.output.add(Uint8List.fromList([byteCmd]));
        await connection!.output.allSent;
        // Pequeña pausa de 30ms entre balas para no ahogar al Arduino
        await Future.delayed(const Duration(milliseconds: 30)); 
      }
      
      setState(() {
        tiempoRestante = seg;
        logStatus = "Señal blindada: $byteCmd";
      });
    } else {
      setState(() {
        tiempoRestante = seg;
        logStatus = "Sin Bluetooth";
      });
    }
  }

  void togglePlayPause() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
      enviarComandoByte(251, tiempoRestante); // PAUSE
    } else {
      if (tiempoRestante > 0) {
        enviarComandoByte(250, tiempoRestante); // START
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (tiempoRestante > 0) {
            setState(() => tiempoRestante--);
          } else {
            _timer?.cancel();
            setState(() {});
          }
        });
      }
    }
    setState(() {});
  }

  void resetToLast() {
    if (ultimoTiempoSeteado <= 0) return;
    _timer?.cancel();
    // Reseteo inteligente ajustado sin el botón 8
    if (ultimoTiempoSeteado == 14) enviarComandoByte(253, 14);
    else if (ultimoTiempoSeteado == 24) enviarComandoByte(254, 24);
    else enviarComandoByte(ultimoTiempoSeteado, ultimoTiempoSeteado);
  }

  void setZero() {
    _timer?.cancel();
    enviarComandoByte(252, 0); 
    setState(() {
      tiempoRestante = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isRunning = _timer != null && _timer!.isActive;

    return Scaffold(
      backgroundColor: fondoOscuro, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("CONTADOR 24 14 SINCRÓNICO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: amarilloFrey, letterSpacing: 1.2)),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.bluetooth, size: 30, color: amarilloFrey), onPressed: conectarBluetooth)
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: amarilloFrey.withOpacity(0.15), blurRadius: 20, spreadRadius: 5)],
                  border: Border.all(color: amarilloFrey, width: 3),
                ),
                alignment: Alignment.center,
                child: Text(
                  tiempoRestante.toString().padLeft(2, '0'),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 130, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 15),
              Text(logStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white54)),
              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBotonAtajo("14", () { 
                    _timer?.cancel(); ultimoTiempoSeteado = 14; enviarComandoByte(253, 14); 
                  }),
                  _buildBotonAtajo("24", () { 
                    _timer?.cancel(); ultimoTiempoSeteado = 24; enviarComandoByte(254, 24); 
                  }),
                ],
              ),
              const SizedBox(height: 30),

              TextField(
                controller: _timeController,
                keyboardType: TextInputType.number,
                enableInteractiveSelection: false, 
                inputFormatters: [ FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2) ],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Escribir (0-99)",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true, fillColor: botonGris,
                  prefixIcon: Icon(Icons.edit, color: amarilloFrey),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.send_rounded, color: amarilloFrey, size: 35),
                    onPressed: () {
                      int? val = int.tryParse(_timeController.text);
                      if (val != null && val >= 0 && val <= 99) {
                        _timer?.cancel();
                        ultimoTiempoSeteado = val;
                        enviarComandoByte(val, val); 
                      }
                      _timeController.clear();
                      FocusScope.of(context).unfocus();
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBotonControl(child: const Text("0", style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.white)), color: botonGris, accion: setZero, size: 75),
                  _buildBotonControl(child: Icon(isRunning ? Icons.pause : Icons.play_arrow, color: fondoOscuro, size: 60), color: amarilloFrey, accion: togglePlayPause, size: 100),
                  _buildBotonControl(child: const Icon(Icons.refresh, color: Colors.white, size: 40), color: Colors.redAccent.shade700, accion: resetToLast, size: 75),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotonAtajo(String t, VoidCallback onPress) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: amarilloFrey,
        foregroundColor: fondoOscuro,
        minimumSize: const Size(120, 110), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 6,
      ),
      onPressed: onPress,
      child: Text(t, style: const TextStyle(fontSize: 45, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBotonControl({required Widget child, required Color color, required VoidCallback accion, required double size}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: Size(size, size),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        elevation: 8,
      ),
      onPressed: accion,
      child: child,
    );
  }
}