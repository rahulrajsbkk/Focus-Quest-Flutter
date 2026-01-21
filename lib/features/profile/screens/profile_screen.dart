import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focus_quest/features/auth/providers/auth_provider.dart';
import 'package:focus_quest/features/profile/providers/user_progress_provider.dart';
import 'package:focus_quest/models/app_user.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: authState.when(
        data: (user) {
          if (user == null) {
            return _buildLoginView(context);
          }
          return _buildProfileView(context, user);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          // If error is user cancellation, show login view instead
          final errorMsg = err.toString();
          if (errorMsg.contains('canceled') || errorMsg.contains('cancelled')) {
            return _buildLoginView(context);
          }
          // For other errors, show login view with no error display
          // The SnackBar will handle showing the error
          return _buildLoginView(context);
        },
      ),
    );
  }

  Widget _buildLoginView(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rocket_launch_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Focus Quest',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Gamify your productivity journey.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            _buildGoogleSignInButton(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildGuestSignUpButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () async {
          final notifier = ref.read(authProvider.notifier);
          await notifier.signInWithGoogle();

          // Check if sign-in failed
          if (!mounted) return;
          ref
              .read(authProvider)
              .whenOrNull(
                error: (error, stack) {
                  // Don't show error if user cancelled
                  final errorMsg = error.toString();
                  if (errorMsg.contains('canceled') ||
                      errorMsg.contains('cancelled')) {
                    // User cancelled, silently ignore
                    return;
                  }

                  // Show user-friendly error message
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(_getErrorMessage(errorMsg)),
                          backgroundColor: Colors.red,
                        ),
                      );
                  }
                },
              );
        },
        icon: const Icon(
          Icons.g_mobiledata,
          size: 32,
        ), // Should use Google Logo asset
        label: const Text(
          'Continue with Google',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  String _getErrorMessage(String error) {
    if (error.contains('network') || error.contains('Network')) {
      return 'Network error. Please check your internet connection.';
    } else if (error.contains('popup_blocked')) {
      return 'Sign-in popup was blocked. Please allow popups.';
    } else if (error.contains('account-exists')) {
      return 'An account with this email already exists.';
    } else {
      return 'Sign-in failed. Please try again later.';
    }
  }

  Widget _buildGuestSignUpButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () => _showGuestSetupDialog(context),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
        child: const Text('Continue as Guest'),
      ),
    );
  }

  Future<void> _showGuestSetupDialog(BuildContext context) async {
    _nameController.clear();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile Setup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your name to get started.'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Adventurer',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (_nameController.text.trim().isNotEmpty) {
                final randomAvatar = _generateRandomAvatar();
                await ref
                    .read(authProvider.notifier)
                    .signInAsGuest(
                      _nameController.text.trim(),
                      randomAvatar,
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Start Quest'),
          ),
        ],
      ),
    );
  }

  String _generateRandomAvatar() {
    // Generate a random color hex or simple identifier
    // For now returning a placeholder URL or identifier
    final randomId = Random().nextInt(100);
    return 'https://api.dicebear.com/7.x/bottts/png?seed=$randomId';
  }

  Widget _buildProfileView(BuildContext context, AppUser user) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, user),
            if (user.isGamificationEnabled) _buildStatsOverview(context),
            const SizedBox(height: 24),
            _buildSettingsSection(context, user),
            const SizedBox(height: 48),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppUser user) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.1),
            backgroundImage: user.photoUrl.startsWith('http')
                ? NetworkImage(user.photoUrl)
                : null,
            child: !user.photoUrl.startsWith('http')
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user.isGuest)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      'Guest Account',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Text(
                    user.email ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview(BuildContext context) {
    final progress = ref.watch(userProgressProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return progress.when(
      data: (data) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF7A9E7E), // Muted green
                      const Color(0xFF5A7A7A), // Darker teal
                    ]
                  : [
                      const Color(0xFF8AB08E), // Lighter green
                      const Color(0xFF7AACAC), // Lighter teal
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF7A9E7E).withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Level',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // XP Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'XP ${data.xpProgressInCurrentLevel} / '
                        '${data.xpForNextLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final percentage =
                              ((data.xpProgressInCurrentLevel /
                                          data.xpForNextLevel) *
                                      100)
                                  .toInt();
                          return Text(
                            '$percentage%',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value:
                          data.xpProgressInCurrentLevel / data.xpForNextLevel,
                      minHeight: 8,
                      backgroundColor: Colors.black.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildSettingsSection(BuildContext context, AppUser user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'SETTINGS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: user.isSyncEnabled,
                  onChanged: (value) async {
                    if (user.isGuest && value) {
                      // Prompt to sign in if trying to enable sync
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Sign in with Google to enable sync & backup',
                          ),
                        ),
                      );

                      final notifier = ref.read(authProvider.notifier);
                      await notifier.signInWithGoogle();

                      // Check if sign-in failed (but ignore cancellation)
                      if (!mounted) return;
                      ref
                          .read(authProvider)
                          .whenOrNull(
                            error: (error, stack) {
                              final errorMsg = error.toString();
                              if (errorMsg.contains('canceled') ||
                                  errorMsg.contains('cancelled')) {
                                return;
                              }

                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text(_getErrorMessage(errorMsg)),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                              }
                            },
                          );
                    } else {
                      await ref
                          .read(authProvider.notifier)
                          .updateSettings(isSyncEnabled: value);
                    }
                  },
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A9E7E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cloud_sync_rounded,
                      color: Color(0xFF7A9E7E), // Muted green
                    ),
                  ),
                  title: const Text('Sync & Backup'),
                  subtitle: const Text('Save progress across devices'),
                ),
                Divider(
                  height: 1,
                  indent: 60,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
                SwitchListTile.adaptive(
                  value: user.isGamificationEnabled,
                  onChanged: (value) async {
                    await ref
                        .read(authProvider.notifier)
                        .updateSettings(isGamificationEnabled: value);
                  },
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8D5A3).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.videogame_asset_rounded,
                      color: Color(0xFFD4A574), // Warm accent
                    ),
                  ),
                  title: const Text('Gamification'),
                  subtitle: const Text('XP, Levels, Stats & Streaks'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
