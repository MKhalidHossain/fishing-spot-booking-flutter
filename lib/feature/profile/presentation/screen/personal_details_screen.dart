import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:xocobaby13/feature/profile/controller/profile_controller.dart';
import 'package:xocobaby13/feature/profile/model/user_profile_data_model.dart';
import 'package:xocobaby13/feature/profile/presentation/widgets/profile_avatar.dart';
import 'package:xocobaby13/feature/profile/presentation/widgets/profile_style.dart';
import 'package:xocobaby13/feature/profile/presentation/widgets/profile_text_field.dart';
import 'package:xocobaby13/core/common/widget/button/loading_buttons.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _descriptionController;
  late final ProfileController _controller;
  Worker? _profileWorker;
  late UserProfileDataModel _draft;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController.instance();
    final UserProfileDataModel profile = _controller.profile.value;
    _draft = profile;
    _nameController = TextEditingController(text: profile.name);
    _emailController = TextEditingController(text: profile.email);
    _phoneController = TextEditingController(text: profile.phone);
    _descriptionController = TextEditingController(text: profile.description);

    _profileWorker = ever<UserProfileDataModel>(_controller.profile, (
      UserProfileDataModel profile,
    ) {
      if (!mounted) return;
      _draft = profile;
      _nameController.text = profile.name;
      _emailController.text = profile.email;
      _phoneController.text = profile.phone;
      _descriptionController.text = profile.description;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _profileWorker?.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    await _controller.pickAvatarFromGallery();
    setState(() {
      _draft = _controller.profile.value;
    });
  }

  Future<void> _save() async {
    final String fullName = _nameController.text.trim().isEmpty
        ? _draft.name
        : _nameController.text.trim();
    final String email = _emailController.text.trim().isEmpty
        ? _draft.email
        : _emailController.text.trim();
    final String phone = _phoneController.text.trim().isEmpty
        ? _draft.phone
        : _phoneController.text.trim();
    final String description = _descriptionController.text.trim();

    final bool success = await _controller.updateProfileRemote(
      fullName: fullName,
      email: email,
      phone: phone,
      bio: description,
    );

    if (!mounted) return;
    if (success) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Personal details updated.'),
          margin: const EdgeInsets.all(14),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black.withValues(alpha: 0.78),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to update profile.'),
          margin: const EdgeInsets.all(14),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black.withValues(alpha: 0.78),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileFlowScaffold(
      title: 'Personal Details',
      showBack: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 6),
            Center(
              child: ProfileAvatar(
                profile: _draft,
                size: 86,
                onEditTap: _pickAvatar,
              ),
            ),
            const SizedBox(height: 14),
            ProfileTextField(
              label: 'Full name',
              controller: _nameController,
              hint: 'Khalid Hossain',
            ),
            const SizedBox(height: 14),
            ProfileTextField(
              label: 'Email address',
              controller: _emailController,
              hint: 'khalid@gmail.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            ProfileTextField(
              label: 'Phone Number',
              controller: _phoneController,
              hint: '(000) 000-0000',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            ProfileTextField(
              label: 'Write A Description About You',
              controller: _descriptionController,
              hint: 'Give a brief description about yourself',
              maxLines: 4,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: AppElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ProfilePalette.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
