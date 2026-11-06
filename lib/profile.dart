// profile_screen.dart
import 'package:flutter/material.dart';
import 'package:farmer_app/Services/auth_services.dart'; // Assuming you have this
import 'package:farmer_app/login.dart'; // Assuming you have this

class ProfileScreen extends StatefulWidget {
  final String token;

  const ProfileScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // You can add more user data fields as needed
  String userName = "Bee Keeper";
  String email = "beekeeper@example.com";
  String role = "Farm Manager";

  // You can fetch actual user data in initState if you have an API for it
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    // Replace with actual API call to get user profile
    // Example:
    // final userData = await UserService.getUserProfile(widget.token);
    // setState(() {
    //   userName = userData.name;
    //   email = userData.email;
    //   role = userData.role;
    // });
  }

  void _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Logout'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldLogout) {
      // Perform logout
      try {
        await AuthService.logout(); // Assuming you have this method

        // Navigate to login screen and clear navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile header
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.amber[100],
              child: Icon(Icons.person, size: 80, color: Colors.amber[800]),
            ),
            const SizedBox(height: 16),
            Text(
              userName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
            ),
            Text(
              email,
              style: TextStyle(fontSize: 16, color: Colors.brown[600]),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                role,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Profile sections
            _buildProfileSection(
              title: 'Account Information',
              icon: Icons.account_circle,
              children: [
                _buildProfileItem(
                  title: 'Edit Profile',
                  icon: Icons.edit,
                  onTap: () {
                    // Navigate to edit profile screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Edit Profile - Coming Soon'),
                      ),
                    );
                  },
                ),
                _buildProfileItem(
                  title: 'Change Password',
                  icon: Icons.lock,
                  onTap: () {
                    // Navigate to change password screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Change Password - Coming Soon'),
                      ),
                    );
                  },
                ),
              ],
            ),

            _buildProfileSection(
              title: 'App Settings',
              icon: Icons.settings,
              children: [
                _buildProfileItem(
                  title: 'Notification Settings',
                  icon: Icons.notifications,
                  onTap: () {
                    // Navigate to notification settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification Settings - Coming Soon'),
                      ),
                    );
                  },
                ),
                _buildProfileItem(
                  title: 'Language',
                  icon: Icons.language,
                  value: 'English',
                  onTap: () {
                    // Navigate to language settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Language Settings - Coming Soon'),
                      ),
                    );
                  },
                ),
                _buildProfileItem(
                  title: 'Theme',
                  icon: Icons.color_lens,
                  value: 'Light',
                  onTap: () {
                    // Navigate to theme settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Theme Settings - Coming Soon'),
                      ),
                    );
                  },
                ),
              ],
            ),

            _buildProfileSection(
              title: 'Support',
              icon: Icons.help,
              children: [
                _buildProfileItem(
                  title: 'Help Center',
                  icon: Icons.help_center,
                  onTap: () {
                    // Navigate to help center
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Help Center - Coming Soon'),
                      ),
                    );
                  },
                ),
                _buildProfileItem(
                  title: 'Contact Support',
                  icon: Icons.support_agent,
                  onTap: () {
                    // Navigate to contact support
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Contact Support - Coming Soon'),
                      ),
                    );
                  },
                ),
                _buildProfileItem(
                  title: 'About',
                  icon: Icons.info,
                  onTap: () {
                    // Navigate to about page
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('About - Coming Soon')),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Logout button
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Colors.amber[800]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileItem({
    required String title,
    required IconData icon,
    String? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.brown[400], size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, color: Colors.brown),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: TextStyle(color: Colors.brown[600], fontSize: 14),
              ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

