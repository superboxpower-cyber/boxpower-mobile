import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfilesView extends StatefulWidget {
  const ProfilesView({super.key});

  @override
  State<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends State<ProfilesView> {
  String _clientName = 'Cliente';
  List<dynamic> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final name = await ApiService.getUsername();
    final accountsList = await ApiService.fetchAccounts();

    setState(() {
      _clientName = name;
      _accounts = accountsList;
      _isLoading = false;
    });
  }

  void _handleLogout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _onProfileSelected(Map<String, dynamic> account) {
    if (account['status'] != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta sessão expirou. O administrador precisa atualizá-la.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    
    // Navigate to WebView screen passing the selected account details
    Navigator.pushNamed(context, '/webview', arguments: account);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0E14),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Workspaces Disponíveis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Olá, $_clientName',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Atualizar lista',
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent),
            onPressed: _handleLogout,
            tooltip: 'Sair do Portal',
          ),
        ],
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFF1F222E), width: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 48, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum workspace disponível',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Solicite ao administrador que cadastre suas contas do Flow.',
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _accounts.length,
                  itemBuilder: (context, index) {
                    final acc = _accounts[index] as Map<String, dynamic>;
                    final bool isActive = acc['status'] == 'active';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          acc['name'] ?? 'Conta sem nome',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              acc['email'] ?? '',
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Último acesso: ${acc['last_used'] ?? 'Nunca'}',
                              style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            border: Border.all(
                              color: isActive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isActive ? 'Ativa' : 'Expirada',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.greenAccent : Colors.redAccent,
                            ),
                          ),
                        ),
                        onTap: () => _onProfileSelected(acc),
                      ),
                    );
                  },
                ),
    );
  }
}
