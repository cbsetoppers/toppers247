import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import 'main_navigation_screen.dart';
import 'email_otp_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Form Keys for each step
  final _formKey0 = GlobalKey<FormState>();
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dobController = TextEditingController();

  String? _selectedGender;
  String? _selectedClass;
  String? _selectedStream;
  final List<String> _selectedExams = [];
  String _countryCode = '+91';

  List<Map<String, dynamic>> _classes = [];
  List<String> _exams = [];
  List<String> _streams = [];
  bool _isLoadingData = true;



  @override
  void initState() {
    super.initState();
    _loadDynamicData();
  }

  Future<void> _loadDynamicData() async {
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final fetchedClasses = await supabaseService.fetchClasses();
      final fetchedExams = await supabaseService.fetchCompetitiveExams();
      if (mounted) {
        setState(() {
          _classes = fetchedClasses;
          _exams = fetchedExams;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _nextPage() {
    bool isValid = false;
    if (_currentPage == 0) {
      isValid = _formKey0.currentState?.validate() ?? false;
    } else if (_currentPage == 1)
      isValid = _formKey1.currentState?.validate() ?? false;

    if (isValid && _currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _handleRegister() async {
    if (!(_formKey2.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();

    try {
      await ref
          .read(authProvider.notifier)
          .register(
            email: email,
            password: _passwordController.text,
            name: _nameController.text.trim(),
            studentClass: _selectedClass!,
            stream: _selectedStream,
            competitiveExams: _selectedExams,
            gender: _selectedGender ?? 'OTHER',
            phone: _phoneController.text.trim().isNotEmpty
                ? '$_countryCode ${_phoneController.text.trim()}'
                : null,
            dob: _dobController.text,
          );

      if (!mounted) return;

      // Check if there's an active session (user is confirmed)
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        // Successfully registered and signed in — go to home
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const MainNavigationScreen(),
            transitionsBuilder: (_, a, _, c) =>
                FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 700),
          ),
          (route) => false,
        );
      } else {
        // Email confirmation required — show OTP screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmailOtpScreen(
              email: email,
              password: _passwordController.text,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch(authProvider) or ref.watch(supabaseServiceProvider) if needed
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: SafeArea(
          child: _isLoadingData
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildTopSection(
                      Theme.of(context).brightness == Brightness.dark,
                    ),
                    _buildHeader(),
                    _buildProgressBar(),
                    Expanded(
                      child: CenteredContent(
                        maxWidth: 500,
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (page) =>
                              setState(() => _currentPage = page),
                          children: [
                            _buildStep(
                              formKey: _formKey0,
                              title: 'The basics',
                              subtitle: 'Tell us a bit about yourself',
                              children: [
                                _buildField(
                                  'Full Name',
                                  _nameController,
                                  Icons.person_outline,
                                  hint: 'Enter your name',
                                ),
                                const SizedBox(height: 24),
                                _buildDateField(),
                                const SizedBox(height: 24),
                                _buildGenderSelector(),
                                const SizedBox(height: 24),
                                _buildPhoneField(),
                              ],
                            ),
                            _buildStep(
                              formKey: _formKey1,
                              title: 'Your goals',
                              subtitle: 'Help us tailor the content for you',
                              children: [
                                _buildDropdown(
                                  'Class / Grade',
                                  _selectedClass,
                                  _classes.map((e) => e['name'].toString()).toList(),
                                  Icons.school_outlined,
                                  (val) async {
                                    final selectedClassObj = _classes.firstWhere((e) => e['name'] == val);
                                    final isSenior = selectedClassObj['class_type'] == 'SENIOR SECONDARY';
                                    
                                    setState(() {
                                      _selectedClass = val;
                                      _selectedStream = null;
                                      _streams = [];
                                    });
                                    
                                    if (isSenior) {
                                      final supabaseService = ref.read(supabaseServiceProvider);
                                      final linkedStreams = await supabaseService.fetchStreams(classId: selectedClassObj['id']);
                                      if (mounted) {
                                        setState(() => _streams = linkedStreams);
                                      }
                                    }
                                  },
                                ),
                                if (_selectedClass != null && _streams.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  _buildDropdown(
                                    'Stream / Branch',
                                    _selectedStream,
                                    _streams,
                                    Icons.science_outlined,
                                    (val) => setState(() => _selectedStream = val),
                                    required: true,
                                  ),
                                ],
                                const SizedBox(height: 32),
                                _buildExamsChipGroup(),
                              ],
                            ),
                            _buildStep(
                              formKey: _formKey2,
                              title: 'Finish setup',
                              subtitle: 'Secure your new account',
                              children: [
                                _buildField(
                                  'Email Address',
                                  _emailController,
                                  Icons.email_outlined,
                                  hint: 'you@example.com',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (val) {
                                    if (val == null || val.isEmpty)
                                      return 'Required';
                                    if (!val.contains('@'))
                                      return 'Invalid email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                _buildField(
                                  'Password',
                                  _passwordController,
                                  Icons.lock_outline,
                                  obscure: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                  validator: (val) => (val?.length ?? 0) < 6
                                      ? 'Min 6 characters'
                                      : null,
                                ),
                                const SizedBox(height: 24),
                                _buildField(
                                  'Confirm Password',
                                  _confirmPasswordController,
                                  Icons.lock_outline,
                                  obscure: _obscureConfirmPassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val != _passwordController.text) {
                                      return 'Passwords match required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildBottomNav(isLoading),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTopSection(bool isDark) {
    if (_currentPage > 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20, bottom: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBlack : Colors.white,
              shape: BoxShape.circle,
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Image.asset(
              'assets/logo.png',
              width: 60,
              height: 60,
              errorBuilder: (_, _, _) => Icon(
                Icons.school_rounded,
                size: 40,
                color: AppTheme.primaryColor,
              ),
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text(
            'T0PPERS 24/7',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryColor,
              letterSpacing: 2,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _currentPage == 0
                ? () => Navigator.pop(context)
                : _previousPage,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              padding: const EdgeInsets.all(12),
            ),
          ),
          Column(
            children: [
              Text(
                'CREATE ACCOUNT',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'Step ${_currentPage + 1} of 3',
                style: GoogleFonts.outfit(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 48), // for symmetry
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentPage;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 4,
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.primaryColor
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep({
    required GlobalKey<FormState> formKey,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? hint,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          decoration:
              InputDecoration(
                hintText: hint ?? label,
                prefixIcon: Icon(icon, color: AppTheme.primaryColor),
              ).copyWith(
                suffixIcon: suffixIcon,
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.02),
              ),
          validator:
              validator ??
              (val) => (val == null || val.isEmpty) ? 'Required field' : null,
        ),
      ],
    );
  }

  Widget _buildDateField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DATE OF BIRTH',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _dobController,
          readOnly: true,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().subtract(
                const Duration(days: 365 * 15),
              ),
              firstDate: DateTime(1990),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              _dobController.text = "${date.day}/${date.month}/${date.year}";
            }
          },
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          decoration:
              InputDecoration(
                hintText: 'Select your birthday',
                prefixIcon: Icon(
                  Icons.cake_outlined,
                  color: AppTheme.primaryColor,
                ),
              ).copyWith(
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.02),
              ),
          validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GENDER',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildGenderBtn('MALE', Icons.male)),
            const SizedBox(width: 16),
            Expanded(child: _buildGenderBtn('FEMALE', Icons.female)),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderBtn(String gender, IconData icon) {
    final isSelected = _selectedGender == gender;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.grey),
            const SizedBox(width: 8),
            Text(
              gender,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PHONE NUMBER',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: CountryCodePicker(
                onChanged: (c) => _countryCode = c.dialCode!,
                initialSelection: 'IN',
                countryFilter: const ['IN', 'RU', 'IL', 'JP', 'BT'],
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                alignLeft: false,
                textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                decoration:
                    InputDecoration(
                      hintText: 'Phone',
                      prefixIcon: Icon(
                        Icons.phone_outlined,
                        color: AppTheme.primaryColor,
                      ),
                    ).copyWith(
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.02),
                    ),
                validator: (val) =>
                    (val?.length ?? 0) < 10 ? 'Invalid number' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    IconData icon,
    void Function(String?) onChanged, {
    bool required = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: onChanged,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration:
              InputDecoration(
                hintText: 'Select $label',
                prefixIcon: Icon(icon, color: AppTheme.primaryColor),
              ).copyWith(
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.02),
              ),
          validator: required
              ? (val) => val == null ? 'Selection required' : null
              : null,
        ),
      ],
    );
  }

  Widget _buildExamsChipGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ARE YOU PREPARING FOR?',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _exams.map((exam) {
            final isSelected = _selectedExams.contains(exam);
            return FilterChip(
              label: Text(exam),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedExams.add(exam);
                  } else {
                    _selectedExams.remove(exam);
                  }
                });
              },
              backgroundColor: Colors.transparent,
              selectedColor: AppTheme.primaryColor,
              labelStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : Colors.grey,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomNav(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          if (_currentPage != 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'BACK',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : (_currentPage == 2 ? _handleRegister : _nextPage),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      _currentPage == 2 ? 'CREATE ACCOUNT' : 'CONTINUE',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
