import 'dart:io';

void main() {
  final file = File('lib/screen/login_screen.dart');
  String content = file.readAsStringSync();

  final loginCatchPattern = '''    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }''';

  final loginCatchReplacement = '''    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String msg = 'Something went wrong. Please try again';
      switch (e.code) {
        case 'user-not-found': msg = 'No account found with this email'; break;
        case 'wrong-password': msg = 'Incorrect password'; break;
        case 'invalid-credential': msg = 'Incorrect email or password'; break;
        case 'email-already-in-use': msg = 'An account already exists with this email'; break;
        case 'weak-password': msg = 'Password must be at least 6 characters'; break;
        case 'invalid-email': msg = 'Please enter a valid email address'; break;
        case 'network-request-failed': msg = 'No internet connection'; break;
        case 'too-many-requests': msg = 'Too many attempts. Please try again later'; break;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again'), backgroundColor: Colors.red),
      );
    }''';

  final googleCatchReplacement = '''    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String msg = 'Google Sign-In failed. Please try again';
      switch (e.code) {
        case 'account-exists-with-different-credential': msg = 'An account already exists with this email. Please sign in with your password instead'; break;
        case 'network-request-failed': msg = 'No internet connection'; break;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Sign-In failed. Please try again'), backgroundColor: Colors.red),
      );
    }''';

  // We need to carefully replace the login Catch pattern with either login or google catch.
  // Actually, there's `_handleLogin`, `_handleGoogleSignIn`, `_handleForgotPassword` in `_LoginPageState`.
  // And `_handleSignUp`, `_handleGoogleSignIn` in `_SignUpPageState`.

  // Instead of simple replacement, let's use RegExp to find `_handleGoogleSignIn` blocks
  // and replace the catch block inside them separately from the others.
  
  // Let's just do it directly.
  int googleSignInIndex1 = content.indexOf('Future<void> _handleGoogleSignIn() async {');
  int googleSignInIndex2 = content.indexOf('Future<void> _handleGoogleSignIn() async {', googleSignInIndex1 + 1);

  // We will replace all `loginCatchPattern` with `loginCatchReplacement` EXCEPT within `_handleGoogleSignIn` methods.
  // Since `loginCatchPattern` appears exactly 4 times (login, google, signup, google).
  // Wait, there are 2 google sign in, 1 login, 1 signup.
  // The forgot password has a finally block, so it's a different pattern.
  
  // Let's replace the one in forgot password first:
  final forgotPasswordCatchPattern = '''    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {''';

  final forgotPasswordReplacement = '''    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = 'Something went wrong. Please try again';
      switch (e.code) {
        case 'user-not-found': msg = 'No account found with this email'; break;
        case 'invalid-email': msg = 'Please enter a valid email address'; break;
        case 'network-request-failed': msg = 'No internet connection'; break;
        case 'too-many-requests': msg = 'Too many attempts. Please try again later'; break;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {''';

  content = content.replaceAll(forgotPasswordCatchPattern, forgotPasswordReplacement);

  // Now replace Google Sign in ones
  content = content.replaceRange(
      googleSignInIndex1, 
      content.indexOf('}', content.indexOf(loginCatchPattern, googleSignInIndex1)) + 1,
      content.substring(googleSignInIndex1, content.indexOf('}', content.indexOf(loginCatchPattern, googleSignInIndex1)) + 1).replaceFirst(loginCatchPattern, googleCatchReplacement)
  );

  int googleSignInIndex2New = content.indexOf('Future<void> _handleGoogleSignIn() async {', googleSignInIndex1 + 100);
  content = content.replaceRange(
      googleSignInIndex2New, 
      content.indexOf('}', content.indexOf(loginCatchPattern, googleSignInIndex2New)) + 1,
      content.substring(googleSignInIndex2New, content.indexOf('}', content.indexOf(loginCatchPattern, googleSignInIndex2New)) + 1).replaceFirst(loginCatchPattern, googleCatchReplacement)
  );

  // Replace remaining
  content = content.replaceAll(loginCatchPattern, loginCatchReplacement);

  file.writeAsStringSync(content);
}
