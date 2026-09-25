import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum ResetStep { enterEmail, answerQuestions }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _questionsFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _answer1Controller = TextEditingController();
  final _answer2Controller = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  ResetStep _currentStep = ResetStep.enterEmail;
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  String? _q1;
  String? _q2;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _answer1Controller.dispose();
    _answer2Controller.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuestions() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final email = _emailController.text.trim();
      final questions = await SupabaseService.instance.getSecurityQuestionsForEmail(email);
      
      if (questions == null || questions['question_1'] == null || questions['question_2'] == null) {
        setState(() {
          _isSuccess = false;
          _message = 'Account recovery is not set up for this email. Please ask your teacher or an administrator to reset your password.';
        });
      } else {
        setState(() {
          _q1 = questions['question_1'];
          _q2 = questions['question_2'];
          _currentStep = ResetStep.answerQuestions;
          _message = null;
        });
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _message = 'Error fetching account details. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitAnswers() async {
    if (!_questionsFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await SupabaseService.instance.resetPasswordWithSecurityQuestions(
        _emailController.text.trim(),
        _answer1Controller.text,
        _answer2Controller.text,
        _newPasswordController.text,
      );
      
      setState(() {
        _isSuccess = true;
        _message = 'Your password has been successfully reset! You can now log in with your new password.';
      });
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _message = e.toString().replaceAll('UserFacingError: ', '').replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter your email address to recover your account using your security questions.',
            style: TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.email, color: Color(0xFF0F3460)),
              filled: true,
              fillColor: const Color(0xFF16213E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (_message != null && !_isSuccess)
            _buildMessage(_message!, false),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : _fetchQuestions,
            style: _primaryButtonStyle(),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsStep() {
    if (_isSuccess) {
      return Column(
        children: [
          _buildMessage(_message!, true),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: _primaryButtonStyle(),
            child: const Text('Back to Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    return Form(
      key: _questionsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Answer your security questions to set a new password.',
            style: TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildQuestionField('Question 1', _q1 ?? '', _answer1Controller),
          const SizedBox(height: 16),
          _buildQuestionField('Question 2', _q2 ?? '', _answer2Controller),
          const SizedBox(height: 32),
          const Divider(color: Colors.white24),
          const SizedBox(height: 24),
          _buildPasswordField(
            'New Password', 
            _newPasswordController, 
            _obscurePassword, 
            (val) => setState(() => _obscurePassword = !val)
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            'Confirm New Password', 
            _confirmPasswordController, 
            _obscureConfirmPassword, 
            (val) => setState(() => _obscureConfirmPassword = !val),
            validator: (value) {
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              if (value == null || value.isEmpty) return 'Please confirm your password';
              return null;
            }
          ),
          const SizedBox(height: 24),
          if (_message != null) _buildMessage(_message!, false),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitAnswers,
            style: _primaryButtonStyle(),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Reset Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoading ? null : () {
              setState(() {
                _currentStep = ResetStep.enterEmail;
                _message = null;
              });
            },
            child: const Text('Go Back', style: TextStyle(color: Colors.white70)),
          )
        ],
      ),
    );
  }

  Widget _buildQuestionField(String label, String question, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Text(question, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Your answer...',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF16213E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (value) => (value == null || value.isEmpty) ? 'Please answer the question' : null,
        ),
      ],
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool obscure, Function(bool) onToggleObscure, {String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.lock, color: Color(0xFF0F3460)),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
          onPressed: () => onToggleObscure(!obscure),
        ),
        filled: true,
        fillColor: const Color(0xFF16213E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) return 'Please enter a new password';
        if (value.length < 8) return 'Password must be at least 8 characters';
        return null;
      },
    );
  }

  Widget _buildMessage(String text, bool isSuccess) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        border: Border.all(color: isSuccess ? Colors.green : Colors.red, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle : Icons.error, color: isSuccess ? Colors.green : Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: isSuccess ? Colors.green : Colors.red, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF0F3460),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Reset Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.lock_reset, size: 80, color: Color(0xFF0F3460)),
              const SizedBox(height: 24),
              const Text(
                'Account Recovery',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_currentStep == ResetStep.enterEmail) _buildEmailStep() else _buildQuestionsStep(),
              if (_currentStep == ResetStep.enterEmail) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Login', style: TextStyle(color: Color(0xFF0F3460), fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
