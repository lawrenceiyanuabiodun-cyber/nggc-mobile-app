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
      setState(() {
        _users = response.asList ?? [];
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
    final newRole = currentRole == 'admin' ? 'user' : 'admin';
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
    final role = user['role']?.toString() ?? 'user';
    final createdAt = user['created_at']?.toString() ?? '';
    final isAdmin = role == 'admin';
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
    final fullName = lastName.isNotEmpty
        ? '$firstName $lastName'
        : firstName;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: isAdmin
                  ? AppTheme.accentGold
                  : AppTheme.primaryBlue.withOpacity(0.15),
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isAdmin
                      ? AppTheme.primaryBlueDark
                      : AppTheme.primaryBlue,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        fullName.isEmpty ? 'Unknown' : fullName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentGoldDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(phone,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  if (createdAt.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Joined ${_formatDate(createdAt)}',
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textHint),
                    ),
                  ],
                ],
              ),
            ),
            // Role toggle button
            TextButton(
              onPressed: () => _changeRole(id, role),
              style: TextButton.styleFrom(
                foregroundColor: isAdmin
                    ? AppTheme.errorRed
                    : AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
              ),
              child: Text(
                isAdmin ? 'Demote' : 'Make Admin',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
              ),
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
          Text('No users found',
              style: TextStyle(color: AppTheme.textSecondary)),
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
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) { return raw; }
  }
}
