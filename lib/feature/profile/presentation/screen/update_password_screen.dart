import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xocobaby13/core/notifiers/button_status_notifier.dart';
import 'package:xocobaby13/core/notifiers/snackbar_notifier.dart';
import 'package:xocobaby13/feature/auth/controller/change_password_controller.dart';
import 'package:xocobaby13/feature/profile/presentation/routes/profile_routes.dart';
import 'package:xocobaby13/feature/profile/presentation/widgets/profile_style.dart';
import 'package:xocobaby13/feature/profile/presentation/widgets/profile_text_field.dart';
import 'package:xocobaby13/core/common/widget/button/loading_buttons.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late final SnackbarNotifier _snackbarNotifier;
  late final ChangePasswordController _controller;

  @override
  void initState() {
    super.initState();
    _snackbarNotifier = SnackbarNotifier(context: context);
    _controller = ChangePasswordController(_snackbarNotifier);
    _currentController.addListener(_syncControllerState);
    _newController.addListener(_syncControllerState);
    _confirmController.addListener(_syncControllerState);
    _controller.processStatusNotifier.addListener(_onStateChanged);
    _controller.addListener(_onStateChanged);
  }

  void _syncControllerState() {
    _controller
      ..oldPassword = _currentController.text
      ..newPassword = _newController.text
      ..confirmPassword = _confirmController.text;
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _currentController.removeListener(_syncControllerState);
    _newController.removeListener(_syncControllerState);
    _confirmController.removeListener(_syncControllerState);
    _controller.processStatusNotifier.removeListener(_onStateChanged);
    _controller.removeListener(_onStateChanged);
    _controller.dispose();
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    _syncControllerState();
    _controller.changePassword(
      onSuccess: () => context.pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading =
        _controller.processStatusNotifier.status is LoadingStatus;
    final bool canSave = _controller.canChange() && !isLoading;

    return ProfileFlowScaffold(
      title: 'Update Password',
      showBack: true,
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            ProfileTextField(
              label: 'Current password',
              hint: '••••••',
              controller: _currentController,
              obscureText: true,
            ),
            const SizedBox(height: 14),
            ProfileTextField(
              label: 'New password',
              hint: '••••••',
              controller: _newController,
              obscureText: true,
            ),
            const SizedBox(height: 14),
            ProfileTextField(
              label: 'Confirm password',
              hint: '••••••',
              controller: _confirmController,
              obscureText: true,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: AppElevatedButton(
                onPressed: canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ProfilePalette.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
