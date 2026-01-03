```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(TattooStudioApp());
}

class TattooStudioApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tattoo Studio Manager',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF9C27B0),
          secondary: Color(0xFFE91E63),
          surface: Color(0xFF1E1E1E),
          background: Color(0xFF121212),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),
        cardTheme: CardTheme(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Color(0xFF2D2D2D),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
      ),
      home: LicenseManager(),
    );
  }
}

class LicenseManager extends StatefulWidget {
  @override
  _LicenseManagerState createState() => _LicenseManagerState();
}

class _LicenseManagerState extends State<LicenseManager> {
  bool _isLicensed = false;
  int _daysLeft = 5;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    String? licenseKey = prefs.getString('license_key');
    if (licenseKey != null && _validateLicense(licenseKey)) {
      setState(() {
        _isLicensed = true;
        _isLoading = false;
      });
      return;
    }

    int? firstRun = prefs.getInt('first_run');
    if (firstRun == null) {
      await prefs.setInt('first_run', DateTime.now().millisecondsSinceEpoch);
      firstRun = DateTime.now().millisecondsSinceEpoch;
    }

    DateTime firstRunDate = DateTime.fromMillisecondsSinceEpoch(firstRun);
    int daysPassed = DateTime.now().difference(firstRunDate).inDays;
    int daysLeft = 5 - daysPassed;

    setState(() {
      _daysLeft = daysLeft > 0 ? daysLeft : 0;
      _isLoading = false;
    });
  }

  bool _validateLicense(String key) {
    if (key.length != 19) return false;
    List<String> parts = key.split('-');
    if (parts.length != 4) return false;
    
    String combined = parts.join('');
    var bytes = utf8.encode(combined + 'tattoo_studio_secret');
    var digest = sha256.convert(bytes);
    
    return digest.toString().substring(0, 8).toUpperCase() == parts[0];
  }

  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isLicensed) {
      return MainApp();
    }

    if (_daysLeft > 0) {
      return MainApp(daysLeft: _daysLeft);
    }

    return LicenseScreen();
  }
}

class LicenseScreen extends StatefulWidget {
  @override
  _LicenseScreenState createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final TextEditingController _licenseController = TextEditingController();
  String _errorMessage = '';

  bool _validateLicense(String key) {
    if (key.length != 19) return false;
    List<String> parts = key.split('-');
    if (parts.length != 4) return false;
    
    String combined = parts.join('');
    var bytes = utf8.encode(combined + 'tattoo_studio_secret');
    var digest = sha256.convert(bytes);
    
    return digest.toString().substring(0, 8).toUpperCase() == parts[0];
  }

  Future<void> _activateLicense() async {
    String license = _licenseController.text.trim().toUpperCase();
    
    if (_validateLicense(license)) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('license_key', license);
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => MainApp()),
      );
    } else {
      setState(() {
        _errorMessage = 'Chave de licença inválida';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 64, color: Colors.red),
                  SizedBox(height: 24),
                  Text(
                    'Período de Teste Expirado',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Digite sua chave de licença para continuar usando o app',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  TextField(
                    controller: _licenseController,
                    decoration: InputDecoration(
                      labelText: 'Chave de Licença',
                      hintText: 'XXXX-XXXX-XXXX-XXXX',
                      border: OutlineInputBorder(),
                      errorText: _errorMessage.isEmpty ? null : _errorMessage,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _activateLicense,
                    child: Text('Ativar Licença'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  final int? daysLeft;
  
  MainApp({this.daysLeft});

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  List<Client> clients = [];
  List<Appointment> appointments = [];
  List<TattooWork> gallery = [];
  List<Quote> quotes = [];
  List<Payment> payments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    String? clientsJson = prefs.getString('clients');
    if (clientsJson != null) {
      List<dynamic> clientsList = jsonDecode(clientsJson);
      clients = clientsList.map((e) => Client.fromJson(e)).toList();
    }

    String? appointmentsJson = prefs.getString('appointments');
    if (appointmentsJson != null) {
      List<dynamic> appointmentsList = jsonDecode(appointmentsJson);
      appointments = appointmentsList.map((e) => Appointment.fromJson(e)).toList();
    }

    setState(() {});
  }

  Future<void> _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('clients', jsonEncode(clients.map((e) => e.toJson()).toList()));
    await prefs.setString('appointments', jsonEncode(appointments.map((e) => e.toJson()).toList()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tattoo Studio Manager'),
        backgroundColor: Color(0xFF1E1E1E),
        actions: widget.daysLeft != null ? [
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Trial: ${widget.daysLeft} dias',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ] : null,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(
            clients: clients,
            appointments: appointments,
            payments: payments,
          ),
          ClientsScreen(
            clients: clients,
            onClientAdded: (client) {
              setState(() {
                clients.add(client);
              });
              _saveData();
            },
            onClientUpdated: () {
              setState(() {});
              _saveData();
            },
          ),
          CalendarScreen(
            appointments: appointments,
            clients: clients,
            onAppointmentAdded: (appointment) {
              setState(() {
                appointments.add(appointment);
              });
              _saveData();
            },
            onAppointmentUpdated: () {
              setState(() {});
              _saveData();
            },
          ),
          StyleCatalogScreen(),
          GalleryScreen(gallery: gallery),
          QuotesScreen(quotes: quotes, clients: clients),
          FinancialScreen(payments: payments),
          MaterialsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.calendar_today), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.style), label: 'Estilos'),
          NavigationDestination(icon: Icon(Icons.photo_library), label: 'Galeria'),
          NavigationDestination(icon: Icon(Icons.request_quote), label: 'Orçamentos'),
          NavigationDestination(icon: Icon(Icons.monetization_on), label: 'Financeiro'),
          NavigationDestination(icon: Icon(Icons.inventory), label: 'Materiais'),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  final List<Client> clients;
  final List<Appointment> appointments;
  final List<Payment> payments;

  DashboardScreen({
    required this.clients,
    required this.appointments,
    required this.payments,
  });

  @override
  Widget build(BuildContext context) {
    DateTime today = DateTime.now();
    List<Appointment> todayAppointments = appointments.where((apt) =>
      apt.date.year == today.year &&
      apt.date.month == today.month &&
      apt.date.day == today.day
    ).toList();

    double monthlyRevenue = payments.where((payment) =>
      payment.date.year == today.year &&
      payment.date.month == today.month
    ).fold(0.0, (sum, payment) => sum + payment.amount);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bem-vindo ao seu estúdio!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Color(0xFF9C27B0),
            ),
          ),
          SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Agendamentos Hoje',
                  value: '${todayAppointments.length}',
                  icon: Icons.today,
                  color: Color(0xFF9C27B0),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Total Clientes',
                  value: '${clients.length}',
                  icon: Icons.people,
                  color: Color(0xFFE91E63),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Faturamento Mensal',
                  value: 'R\$ ${monthlyRevenue.toStringAsFixed(2)}',
                  icon: Icons.monetization_on,
                  color: Color(0xFF4CAF50),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Trabalhos Realizados',
                  value: '${appointments.where((a) => a.status == 'Concluído').length}',
                  icon: Icons.brush,
                  color: Color(0xFFFF9800),
                ),
              ),
            ],
          ),

          SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agendamentos de Hoje',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  if (todayAppointments.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.event_available, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Nenhum agendamento para hoje'),
                        ],
                      ),
                    )
                  else
                    ...todayAppointments.map((apt) {
                      Client client = clients.firstWhere((c) => c.id == apt.clientId);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(apt.status),
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(client.name),
                        subtitle: Text('${apt.time} - ${apt.description}'),
                        trailing: Chip(
                          label: Text(apt.status),
                          backgroundColor: _getStatusColor(apt.status).withOpacity(0.2),
                        ),
                      );
                    }).toList(),
                ],