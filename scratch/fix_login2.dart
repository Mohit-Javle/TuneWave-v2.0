import 'dart:io';

void main() {
  final file = File('lib/screen/login_screen.dart');
  String content = file.readAsStringSync();
  content = content.replaceAll('\r\n', '\n');

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

  int googleSignInIndex1 = content.indexOf('Future<void> _handleGoogleSignIn() async {');
  if (googleSignInIndex1 != -1) {
    int catchIndex = content.indexOf(loginCatchPattern, googleSignInIndex1);
    int endIndex = content.indexOf('}', catchIndex) + 1;
    String sub = content.substring(googleSignInIndex1, endIndex);
    content = content.replaceRange(googleSignInIndex1, endIndex, sub.replaceFirst(loginCatchPattern, googleCatchReplacement));
  }

  int googleSignInIndex2 = content.indexOf('Future<void> _handleGoogleSignIn() async {', googleSignInIndex1 + 100);
  if (googleSignInIndex2 != -1) {
    int catchIndex = content.indexOf(loginCatchPattern, googleSignInIndex2);
    int endIndex = content.indexOf('}', catchIndex) + 1;
    String sub = content.substring(googleSignInIndex2, endIndex);
    content = content.replaceRange(googleSignInIndex2, endIndex, sub.replaceFirst(loginCatchPattern, googleCatchReplacement));
  }

  content = content.replaceAll(loginCatchPattern, loginCatchReplacement);

  file.writeAsStringSync(content);
}
