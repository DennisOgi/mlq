import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart' show MainNavigationScreen;
import '../../services/supabase_service.dart';
import '../../providers/user_provider.dart';

class SetupSecurityQuestionsScreen extends StatefulWidget {
  final bool isModal; // if true, popped when done; if false, pushes to home

  const SetupSecurityQuestionsScreen({super.key, this.isModal = false});

  @override
  State<SetupSecurityQuestionsScreen> createState() => _SetupSecurityQuestionsScreenState();
}

class _SetupSecurityQuestionsScreenState extends State<SetupSecurityQuestionsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedQ1;
  String? _selectedQ2;
  
  final _answer1Controller = TextEditingController();
  final _answer2Controller = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _questions = [
    'What is the name of your first pet?',
    'What is your favorite color?',
    'What city were you born in?',
    'What is your mother\'s maiden name?',
    'What is your favorite food?',
    'What was the name of your first school?',
    'What is your favorite movie?',
    'What is the name of your best friend?',
  ];

  @override
  void dispose() {
    _answer1Controller.dispose();
    _answer2Controller.dispose();
    super.dispose();
  }

  void _navigateAfterSuccess() {
    // Return to MainNavigationScreen when pushed on top of the app shell.
    if (widget.isModal || Navigator.canPop(context)) {
      Navigator.pop(context, true);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedQ1 == _selectedQ2) {
      setState(() {
        _errorMessage = 'Please select two different questions.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Save security questions to database
      await SupabaseService.instance.setSecurityQuestions(
        _selectedQ1!,
        _answer1Controller.text,
        _selectedQ2!,
        _answer2Controller.text,
      );
      
      if (mounted) {
        final userProvider =
            Provider.of<UserProvider>(context, listen: false);
        
        // Step 2: Mark as configured locally (immediate UI update)
        await userProvider.markSecurityQuestionsConfigured();
        
        // Step 3: Refresh user profile from server to get the actual database state
        // This ensures the hasSecurityQuestions flag is synced with the database
        try {
          await userProvider.refreshUser();
          debugPrint('✅ User profile refreshed after setting security questions');
        } catch (e) {
          debugPrint('⚠️ Error refreshing user after setting security questions: $e');
          // Don't fail the whole operation if refresh fails - we already marked it locally
        }

        _navigateAfterSuccess();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('UserFacingError: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Account Recovery Setup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: widget.isModal,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.security, size: 64, color: Color(0xFF0F3460)),
                const SizedBox(height: 16),
                const Text(
                  'Set Up Security Questions',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'These questions will help you recover your account if you forget your password. Please choose questions with memorable answers.',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Question 1
                _buildDropdownField('Security Question 1', _selectedQ1, (val) => setState(() => _selectedQ1 = val)),
                const SizedBox(height: 12),
                _buildAnswerField('Answer 1', _answer1Controller),
                
                const SizedBox(height: 32),
                
                // Question 2
                _buildDropdownField('Security Question 2', _selectedQ2, (val) => setState(() => _selectedQ2 = val)),
                const SizedBox(height: 12),
                _buildAnswerField('Answer 2', _answer2Controller),
                
                const SizedBox(height: 32),
                
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3460),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Security Questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                
                if (widget.isModal) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Skip for now', style: TextStyle(color: Colors.white54)),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, String? currentValue, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF16213E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      dropdownColor: const Color(0xFF16213E),
      style: const TextStyle(color: Colors.white, fontFamily: 'Nunito'),
      items: _questions.map((q) => DropdownMenuItem(value: q, child: Text(q, style: const TextStyle(fontFamily: 'Nunito', color: Colors.white), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Please select a question' : null,
      isExpanded: true,
    );
  }

  Widget _buildAnswerField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF16213E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (value) => (value == null || value.isEmpty) ? 'Please provide an answer' : null,
    );
  }
}
