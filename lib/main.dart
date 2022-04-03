import 'package:dukkantek/app/core/values/app_translations.dart';
import 'package:dukkantek/app/initial_binding.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'app/routes/app_pages.dart';

void main() {
  runApp(
    GetMaterialApp(
      title: "Dukkantek",
      initialBinding: InitialBinding(),
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
      locale: const Locale('en'),
      fallbackLocale: const Locale('en', 'US'),
      translations: AppTranslations(),
    ),
  );
}
