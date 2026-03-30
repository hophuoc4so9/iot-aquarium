import 'package:flutter/material.dart';

/// Trang quản lý tài khoản: thông tin user + các hành động cơ bản.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder: sau này có thể nối với backend auth / user profile
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.person_rounded, size: 32),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Người dùng demo',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'farmer@example.com',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Thiết lập',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_reset_rounded),
                    title: const Text('Đổi mật khẩu'),
                    onTap: () {
                      // TODO: mở màn hình đổi mật khẩu
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_rounded),
                    title: const Text('Cập nhật thông tin'),
                    onTap: () {
                      // TODO: cập nhật thông tin tài khoản
                    },
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: thực hiện logout
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Đăng xuất'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

