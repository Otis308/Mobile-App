import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_button.dart';
import 'auth_controller.dart';

// ==========================================
// TRANG ĐĂNG NHẬP (Giữ nguyên)
// ==========================================
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  
  bool _obscurePassword = true;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).login(_login.text.trim(), _password.text);
  }

  InputDecoration _buildInputDecoration(BuildContext context, String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey.shade400),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.withValues(alpha: 0.1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(authControllerProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    
                    child: Image.asset(
                      'assets/images/logo_teamwork.png',
                      width: 300,
                      height: 300,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Chào mừng bạn quay trở lại!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 30)),
                const SizedBox(height: 36),

                TextField(
                  controller: _login,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: _buildInputDecoration(context, 'Tên đăng nhập hoặc Email', Icons.person_outline),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: _buildInputDecoration(
                    context, 
                    'Mật khẩu', 
                    Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade500),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ForgotPasswordPage()));
                    },
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text('Quên mật khẩu?', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
                  ),
                ),

                if (s.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                        ],
                      ),
                    ),
                  ),

                if (s.loading)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Đang kết nối...', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                  ),

                const SizedBox(height: 24),
                SizedBox(height: 56, child: AppButton(label: 'Đăng nhập', loading: s.loading, onPressed: _submit)),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Chưa có tài khoản?', style: TextStyle(color: Colors.grey.shade500)),
                    TextButton(
                      onPressed: () {
                        ref.read(authControllerProvider.notifier).clearError();
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RegisterPage()));
                      },
                      child: const Text('Đăng ký ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// TRANG ĐĂNG KÝ (ĐÃ CẬP NHẬT ĐẦY ĐỦ YÊU CẦU)
// ==========================================
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _dob = TextEditingController(); 
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  
  String? _selectedGender;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _phone.dispose();
    _email.dispose();
    _dob.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    
    // Chạy toàn bộ các validation của Form (kiểm tra SĐT, định dạng Email, Pass...)
    if (!_formKey.currentState!.validate()) {
      return; 
    }

    ref.read(authControllerProvider.notifier).register(
          _fullName.text.trim(),
          _username.text.trim(),
          _phone.text.trim(),
          _email.text.trim(),
          _dob.text.trim(),
          _selectedGender!, 
          _password.text,
        );
  }

  // Mở DatePicker (kiểu dropdown ngày tháng)
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'CHỌN NGÀY SINH',
    );
    if (picked != null) {
      setState(() {
        _dob.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  InputDecoration _buildInputDecoration(BuildContext context, String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey.shade400),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.withValues(alpha: 0.1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.isAuthenticated) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final s = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản'), centerTitle: true, elevation: 0, backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tham gia cùng chúng tôi', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Điền thông tin bên dưới để bắt đầu', style: TextStyle(color: Colors.grey.shade500)),
                const SizedBox(height: 24),

                // 1. HỌ VÀ TÊN
                TextFormField(
                  controller: _fullName,
                  textInputAction: TextInputAction.next,
                  decoration: _buildInputDecoration(context, 'Họ và tên', Icons.badge_outlined),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Không được bỏ trống' : null,
                ),
                const SizedBox(height: 16),
                
                // 2. TÊN ĐĂNG NHẬP
                TextFormField(
                  controller: _username,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: _buildInputDecoration(context, 'Tên đăng nhập', Icons.person_outline),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Không được bỏ trống';
                    if (value.trim().length <= 4) return 'Phải lớn hơn 4 kí tự';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 3. SỐ ĐIỆN THOẠI
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _buildInputDecoration(context, 'Số điện thoại', Icons.phone_outlined),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Không được bỏ trống';
                    
                    final phone = value.trim();
                    // Yêu cầu: Đúng số điện thoại chỉ có 10 số
                    if (phone.length != 10) {
                      return 'Số điện thoại chỉ có 10 số';
                    }
                    // Yêu cầu: Kiểm tra đầu số tất cả các nhà mạng VN
                    // 03[2-9]: Viettel
                    // 05[2689]: Vietnamobile, Gmobile
                    // 07[06-9]: Mobifone
                    // 08[1-9]: Vinaphone, Viettel, Mobifone, Itel
                    // 09[0-46-9]: Tất cả các nhà mạng
                    if (!RegExp(r'^(03[2-9]|05[2689]|07[06-9]|08[1-9]|09[0-46-9])').hasMatch(phone)) {
                      return 'Không có số điện thoại này tại Việt Nam';
                    }
                    
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // 4. EMAIL
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: _buildInputDecoration(context, 'Email', Icons.email_outlined),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Không được bỏ trống';
                    // Regex kiểm tra định dạng email chuẩn
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                      return 'Không đúng định dạng email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 5. NGÀY THÁNG NĂM SINH
                TextFormField(
                  controller: _dob,
                  readOnly: true, // Không cho gõ phím
                  onTap: _selectDate, // Bấm vào để mở Dropdown Picker
                  decoration: _buildInputDecoration(context, 'Ngày tháng năm sinh', Icons.calendar_today, suffixIcon: const Icon(Icons.arrow_drop_down)),
                  validator: (value) => (value == null || value.isEmpty) ? 'Không được bỏ trống' : null,
                ),
                const SizedBox(height: 16),

                // 6. GIỚI TÍNH (Tích chọn)
                FormField<String>(
                  validator: (value) => _selectedGender == null ? 'Không được bỏ trống' : null,
                  builder: (state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Nam'),
                                value: _selectedGender == 'Nam',
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (val) {
                                  setState(() => _selectedGender = 'Nam');
                                  state.didChange('Nam'); // Cập nhật trạng thái validation
                                },
                              ),
                            ),
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Nữ'),
                                value: _selectedGender == 'Nữ',
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (val) {
                                  setState(() => _selectedGender = 'Nữ');
                                  state.didChange('Nữ');
                                },
                              ),
                            ),
                          ],
                        ),
                        if (state.hasError) // Hiển thị lỗi màu đỏ giống TextFormField
                          Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 8),
                            child: Text(state.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                          )
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                
                // 7. MẬT KHẨU
                TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: _buildInputDecoration(
                    context, 
                    'Mật khẩu', 
                    Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade500),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Không được bỏ trống';
                    if (value.length < 8) return 'Phải từ 8 kí tự trở lên';
                    if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) return 'Phải có ít nhất 1 chữ in hoa';
                    if (!RegExp(r'(?=.*\d)').hasMatch(value)) return 'Phải có ít nhất 1 chữ số';
                    if (!RegExp(r'(?=.*[\W_])').hasMatch(value)) return 'Phải có ít nhất 1 kí tự đặc biệt';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 8. NHẬP LẠI MẬT KHẨU
                TextFormField(
                  controller: _confirmPassword,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: _buildInputDecoration(
                    context, 
                    'Nhập lại mật khẩu', 
                    Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade500),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Không được bỏ trống';
                    if (value != _password.text) return 'Mật khẩu không khớp';
                    return null;
                  },
                ),
                
                if (s.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 32),
                SizedBox(height: 56, child: AppButton(label: 'Đăng ký', loading: s.loading, onPressed: _submit)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// TRANG QUÊN MẬT KHẨU (Giữ nguyên)
// ==========================================
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  int _currentStep = 1; 
  final _step3FormKey = GlobalKey<FormState>(); // Key kiểm tra form Mật khẩu
  
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmNewPasswordCtrl = TextEditingController(); // Thêm controller nhập lại mật khẩu
  
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmNewPasswordCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  InputDecoration _buildInputDecoration(BuildContext context, String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey.shade400),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.withValues(alpha: 0.1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2)),
    );
  }

  Future<void> _handleSendOtp() async {
    if (_emailCtrl.text.trim().isEmpty) {
      _showError('Vui lòng nhập email!');
      return;
    }
    setState(() => _isLoading = true);
    
    // Gọi API từ Controller
    final error = await ref.read(authControllerProvider.notifier).requestOtp(_emailCtrl.text.trim());
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    if (error != null) {
      _showError(error);
    } else {
      setState(() => _currentStep = 2);
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpCtrl.text.trim().length != 6) {
      _showError('Mã OTP phải gồm 6 chữ số!');
      return;
    }
    setState(() => _isLoading = true);
    
    final error = await ref.read(authControllerProvider.notifier).verifyOtp(_emailCtrl.text.trim(), _otpCtrl.text.trim());
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    if (error != null) {
      _showError(error);
    } else {
      setState(() => _currentStep = 3);
    }
  }

  Future<void> _handleResetPassword() async {
    FocusScope.of(context).unfocus();
    if (!_step3FormKey.currentState!.validate()) return; // Chạy Validate form
    
    setState(() => _isLoading = true);
    final error = await ref.read(authControllerProvider.notifier).resetPassword(
      _emailCtrl.text.trim(), 
      _otpCtrl.text.trim(), 
      _newPasswordCtrl.text
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    if (error != null) {
      _showError(error);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đổi mật khẩu thành công! Vui lòng đăng nhập bằng mật khẩu mới.'), backgroundColor: Colors.green)
      );
      Navigator.pop(context); // Trở về trang đăng nhập
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khôi phục mật khẩu'), centerTitle: true, elevation: 0, backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentStep == 1) ...[
                Icon(Icons.mark_email_read_outlined, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                const Text('Nhập email của bạn, chúng tôi sẽ gửi mã OTP gồm 6 chữ số để đặt lại mật khẩu.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                const SizedBox(height: 32),
                TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: _buildInputDecoration(context, 'Email', Icons.email_outlined)),
                const SizedBox(height: 24),
                SizedBox(height: 56, child: AppButton(label: 'Gửi mã OTP', loading: _isLoading, onPressed: _handleSendOtp)),
              ] 
              else if (_currentStep == 2) ...[
                Icon(Icons.password_outlined, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text('Mã OTP đã được gửi đến:\n${_emailCtrl.text}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 32),
                TextField(controller: _otpCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold), decoration: _buildInputDecoration(context, 'Nhập mã 6 số', Icons.dialpad)),
                const SizedBox(height: 24),
                SizedBox(height: 56, child: AppButton(label: 'Xác nhận OTP', loading: _isLoading, onPressed: _handleVerifyOtp)),
                TextButton(onPressed: () => setState(() => _currentStep = 1), child: const Text('Sửa lại Email'))
              ] 
              else if (_currentStep == 3) ...[
                Icon(Icons.lock_reset_outlined, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                const Text('Mã hợp lệ! Vui lòng tạo mật khẩu mới cho tài khoản của bạn.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                const SizedBox(height: 32),
                
                // Form Validate Mật Khẩu
                Form(
                  key: _step3FormKey,
                  child: Column(
                    children: [
                      // Mật khẩu mới
                      TextFormField(
                        controller: _newPasswordCtrl,
                        obscureText: _obscureNewPassword,
                        decoration: _buildInputDecoration(
                          context, 'Mật khẩu mới', Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(_obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade500),
                            onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Không được bỏ trống';
                          if (value.length < 8) return 'Phải từ 8 kí tự trở lên';
                          if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) return 'Phải có ít nhất 1 chữ in hoa';
                          if (!RegExp(r'(?=.*\d)').hasMatch(value)) return 'Phải có ít nhất 1 chữ số';
                          if (!RegExp(r'(?=.*[\W_])').hasMatch(value)) return 'Phải có ít nhất 1 kí tự đặc biệt';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Nhập lại mật khẩu
                      TextFormField(
                        controller: _confirmNewPasswordCtrl,
                        obscureText: _obscureConfirmPassword,
                        decoration: _buildInputDecoration(
                          context, 'Nhập lại mật khẩu', Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade500),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Không được bỏ trống';
                          if (value != _newPasswordCtrl.text) return 'Mật khẩu không khớp';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                SizedBox(height: 56, child: AppButton(label: 'Lưu mật khẩu mới', loading: _isLoading, onPressed: _handleResetPassword)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
