import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/auth.dart';

void main() {
  test('name from email: used for Google and Apple sign-in', () {
    expect(Auth.nameFromEmail('john.doe42@gmail.com'), 'John Doe');
    expect(Auth.nameFromEmail('sidharthbabu9@gmail.com'), 'Sidharthbabu');
    expect(Auth.nameFromEmail('a_b-c@x.com'), 'A B C');
    expect(Auth.nameFromEmail('MARY.JANE@x.com'), 'Mary Jane');
    expect(Auth.nameFromEmail('123@x.com'), 'Friend');
  });

  test('Google sign-in takes the name from the email. Email sign-up needs a name', () async {
    SharedPreferences.setMockInitialValues({});
    final a = Auth.instance;

    expect(await a.signIn(AuthProvider.google), isNull); // mock build
    expect(Auth.email, 'demo.google@example.com');
    expect(Auth.displayName, 'Demo Google');
    expect(Auth.signedIn, isTrue);

    expect(await a.signIn(AuthProvider.email, emailAddress: 'sam@example.com', name: ''), 'Please enter your name.');
    expect(await a.signIn(AuthProvider.email, emailAddress: 'bad', name: 'Sam'), 'Please enter a valid email address.');
    expect(await a.signIn(AuthProvider.email, emailAddress: 'sam@example.com', name: '  Sam Lee '), isNull);
    expect(Auth.displayName, 'Sam Lee');
    expect(Auth.email, 'sam@example.com');

    await a.signOut();
    expect(Auth.signedIn, isFalse);
    expect(Auth.displayName, 'Guest');
  });
}
