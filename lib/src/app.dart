import 'package:flutter/material.dart';
import 'package:moor_example_3/src/data/moor_database.dart';
import 'package:moor_example_3/src/screens/home_page.dart';
import 'package:provider/provider.dart';

class MoorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final db = AppDatabase();
    return MultiProvider(
      providers: [
        Provider(builder: (_) => db.taskDao),
        Provider(builder: (_) => db.tagDao),
      ],
      child: MaterialApp(
        title: 'Moor App',
        debugShowCheckedModeBanner: false,
        home: HomePage(),
      ),
    );
  }
}
