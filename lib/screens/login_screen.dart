import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLogin = true;
  bool isLoading = false;

  Future<void> authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Authentication error")),
      );
    }

    setState(() => isLoading = false);
  }

  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google Sign-In failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // EV Icon
                  Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.electric_car,
                      size: 36,
                      color: Color(0xFF00C853),
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "Welcome Back",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    isLogin
                        ? "Login to continue your EV journey"
                        : "Create your EV account",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            hintText: "Email address",
                          ),
                          validator: (value) =>
                          value!.contains("@") ? null : "Enter valid email",
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            hintText: "Password",
                          ),
                          obscureText: true,
                          validator: (value) =>
                          value!.length >= 6 ? null : "Minimum 6 characters",
                        ),

                        const SizedBox(height: 24),

                        isLoading
                            ? const CircularProgressIndicator()
                            : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: authenticate,
                            child: Text(
                              isLogin ? "Login" : "Register",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() => isLogin = !isLogin);
                            },
                            child: Text(
                              isLogin
                                  ? "Don’t have an account? Register"
                                  : "Already have an account? Login",
                              style: const TextStyle(
                                color: Color(0xFF00C853),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Divider(),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: signInWithGoogle,
                            icon: const Icon(Icons.login),
                            label: const Text("Continue with Google"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(
                                color: Color(0xFF00C853),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("EV Charging Finder")),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   isLogin ? "Login" : "Register",
//                   style: const TextStyle(
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//
//                 TextFormField(
//                   controller: _emailController,
//                   decoration: const InputDecoration(labelText: "Email"),
//                   validator: (value) =>
//                   value!.contains("@") ? null : "Enter valid email",
//                 ),
//
//                 const SizedBox(height: 10),
//
//                 TextFormField(
//                   controller: _passwordController,
//                   decoration: const InputDecoration(labelText: "Password"),
//                   obscureText: true,
//                   validator: (value) =>
//                   value!.length >= 6 ? null : "Min 6 characters",
//                 ),
//
//                 const SizedBox(height: 20),
//
//                 if (isLoading)
//                   const CircularProgressIndicator()
//                 else
//                   ElevatedButton(
//                     onPressed: authenticate,
//                     child: Text(isLogin ? "Login" : "Register"),
//                   ),
//
//                 TextButton(
//                   onPressed: () {
//                     setState(() => isLogin = !isLogin);
//                   },
//                   child: Text(
//                     isLogin
//                         ? "Don't have an account? Register"
//                         : "Already have an account? Login",
//                   ),
//                 ),
//
//                 const Divider(height: 30),
//
//                 ElevatedButton(
//                   onPressed: signInWithGoogle,
//                   child: const Text("Sign in with Google"),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// Dummy HomeScreen (Replace with your actual map screen)
