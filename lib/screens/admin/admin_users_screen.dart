import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() { _isLoading = true; _error = null; });
    final response = await ApiService.get('/users/');
    if (!mounted) return;
    if (response.isSuccess) {
      final data = response.asMap;
      final usersList = data?['users'] as List? ?? response.asList ?? [];
      setState(() {
        _users = usersList;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? 'Failed to load users';
        _isLoading = false;
      });
    }
  }

  Future<void> _changeRole(String userId, String currentRole) async {
    final newRole = currentRole == 'admin' ? 'member' : 'admin';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Role',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
        content: Text(
            'Change this user\'s role to ${newRole.toUpperCase()}?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final response = await ApiService.post(
      '/users/$userId/role',
      body: {'role': newRole},
    );
    if (!mounted) return;
    if (response.isSuccess) {
      _fetchUsers();
      _showSnack('Role updated to $newRole', AppTheme.successGreen);
    } else {
      _showSnack(response.error ?? 'Failed', AppTheme.errorRed);
    }
  }

  Future<void> _toggleActive(String userId, bool currentlyActive) async {
    final actionName = currentlyActive ? 'deactivate' : 'reactivate';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          currentlyActive ? 'Deactivate User' : 'Reactivate User',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
        ),
        content: Text(
          'Are you sure you want to $actionName this user?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentlyActive ? AppTheme.errorRed : AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(currentlyActive ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final response = await ApiService.post('/auth/$actionName/$userId');
    if (!mounted) return;
    if (response.isSuccess) {
      _fetchUsers();
      _showSnack('User ${currentlyActive ? "deactivated" : "reactivated"}', AppTheme.successGreen);
    } else {
      _showSnack(response.error ?? 'Failed', AppTheme.errorRed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: Text('Users (${_users.length})'),
        backgroundColor: AppTheme.primaryBlueDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchUsers),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : _error != null
              ? _buildError()
              : _users.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: _fetchUsers,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index] as Map<String, dynamic>;
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final id = user['id']?.toString() ?? '';
    final firstName = user['first_name']?.toString() ?? '';
    final lastName = user['last_name']?.toString() ?? '';
    final phone = user['phone']?.toString() ?? '';
    final role = user['role']?.toString() ?? 'member';
    final createdAt = user['created_at']?.toString() ?? '';
    final lastLogin = user['last_login_at']?.toString() ?? '';
    final isActive = user['active'] != false;
    final isAdmin = role == 'admin';
    final isEditor = role == 'editor';
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    final fullName = lastName.isNotEmpty ? '$firstName $lastName' : firstName;

    // Detect Channel / Platform (Android vs Web)
    final platformRaw = (user['platform'] ?? user['last_platform'] ?? user['device_type'] ?? '')
        .toString()
        .toLowerCase();

    bool isAndroid = platformRaw.contains('android') || platformRaw.contains('apk') || platformRaw.contains('mobile');
    bool isWeb = platformRaw.contains('web') || platformRaw.contains('chrome') || platformRaw.contains('browser');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isActive ? Colors.white : Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: isAdmin
                  ? AppTheme.accentGold
                  : isEditor
                      ? const Color(0xFF6A1B9A).withOpacity(0.2)
                      : AppTheme.primaryBlue.withOpacity(0.15),
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isAdmin
                      ? AppTheme.primaryBlueDark
                      : isEditor
                          ? const Color(0xFF6A1B9A)
                          : AppTheme.primaryBlue,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fullName.isEmpty ? 'Unknown' : fullName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isActive ? AppTheme.textPrimary : AppTheme.textHint,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Admin',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.accentGoldDark)),
                        ),
                      if (!isActive)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Inactive',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.errorRed)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        phone,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      // Platform / Channel Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAndroid
                              ? Colors.green.withOpacity(0.15)
                              : isWeb
                                  ? Colors.blue.withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAndroid
                                  ? Icons.android
                                  : isWeb
                                      ? Icons.language
                                      : Icons.devices,
                              size: 11,
                              color: isAndroid
                                  ? Colors.green[800]
                                  : isWeb
                                      ? Colors.blue[800]
                                      : Colors.grey[700],
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isAndroid
                                  ? 'Android App'
                                  : isWeb
                                      ? 'Web App'
                                      : 'Member',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isAndroid
                                    ? Colors.green[800]
                                    : isWeb
                                        ? Colors.blue[800]
                                        : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (lastLogin.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Last login: ${_formatDate(lastLogin)}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textHint),
                    ),
                  ] else if (createdAt.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Joined ${_formatDate(createdAt)} (never logged in)',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textHint),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _changeRole(id, role),
                  style: TextButton.styleFrom(
                    foregroundColor: isAdmin ? AppTheme.errorRed : AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isAdmin ? 'Demote' : 'Make Admin',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => _toggleActive(id, isActive),
                  style: TextButton.styleFrom(
                    foregroundColor: isActive ? Colors.orange : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isActive ? 'Disable' : 'Enable',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 48, color: AppTheme.textHint),
          SizedBox(height: 12),
          Text('No users found', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.textHint),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchUsers,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('MMM d, yyyy h:mma').format(dt);
    } catch (_) { return raw; }
  }
}