import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';

Future<void> nutritionTestStorage() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  AccountStorageScope.current = '';
  final directory = await Directory.systemTemp.createTemp(
    'fit_nutrition_test_',
  );
  Hive.init(directory.path);
  addTearDown(() async {
    AccountStorageScope.current = '';
    await Hive.close();
    await directory.delete(recursive: true);
  });
}
