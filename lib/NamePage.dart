import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:air_quality_app/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

class NamePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return new NamePageState();
  }
}

class NamePageState extends State<NamePage> {
  TextEditingController _nameController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        margin: EdgeInsets.symmetric(
          horizontal: 40,
        ),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 90.0,
            ),
            Center(
              child: Text(
                "Enter your Name",
                style: GoogleFonts.roboto(
                  color: Colors.grey,
                  fontSize: 30,
                ),
              ),
            ),
            SizedBox(
              height: 50.0,
            ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                icon: Icon(
                  Icons.person,
                ),
                hintText: 'Your name',
                labelText: 'Enter your name',
              ),
            ),
            SizedBox(
              height: 50.0,
            ),
            TextButton(
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all<Color>(
                  Color(
                    0xffffffff,
                  ),
                ),
                backgroundColor: MaterialStateProperty.all<Color>(
                  Color(
                    0xff00C6BD,
                  ),
                ),
              ),
              onPressed: () async {
                if (_nameController.text == '') {
                  Fluttertoast.showToast(
                    msg: "Name Cannot be Empty",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.CENTER,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                } else {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser.uid)
                      .set({
                    'uid': FirebaseAuth.instance.currentUser.uid,
                    'name': _nameController.text,
                    'phoneNumber':
                        FirebaseAuth.instance.currentUser.phoneNumber,
                  });
                  Navigator.of(context).pushReplacement(
                    new MaterialPageRoute(
                      builder: (BuildContext context) {
                        return MyHomePage(
                          title: 'My Air',
                        );
                      },
                    ),
                  );
                }
              },
              child: Text(
                "Save",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
