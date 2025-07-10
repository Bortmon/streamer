import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:streamer/home_page.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryTextColor = Colors.white;
    const Color secondaryTextColor = Colors.white70;
    const Color backgroundColor = Color(0xFF121212); 
    const Color surfaceColor = Color(0xFF1E1E1E);
    const Color accentColor = Color(0xFF00BCD4);

    // Creëer het basisthema met Google Fonts
    final baseTheme = ThemeData.dark();
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme).apply(
      bodyColor: primaryTextColor,
      displayColor: primaryTextColor,
    );

    return MaterialApp(
      title: 'Streamer',
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: backgroundColor,
        primaryColor: accentColor,
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: accentColor,
          secondary: accentColor,
          surface: surfaceColor,
          onSurface: primaryTextColor,
          background: backgroundColor,
          onBackground: primaryTextColor,
          error: Colors.redAccent,
        ),

        textTheme: textTheme,
        primaryTextTheme: textTheme,

        appBarTheme: AppBarTheme(
          backgroundColor: backgroundColor.withOpacity(0.85),
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: Colors.black.withOpacity(0.5),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: const IconThemeData(color: primaryTextColor),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accentColor,
          foregroundColor: Colors.black,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceColor,
          hintStyle: const TextStyle(color: secondaryTextColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: accentColor, width: 2.0),
          ),
        ),

        cardTheme: CardTheme(
          color: surfaceColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),

        dialogTheme: DialogTheme(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
        ),

        badgeTheme: BadgeThemeData(
          backgroundColor: accentColor,
          textColor: Colors.black,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      debugShowCheckedModeBanner: false, 
      home: const HomePage(),
    );
  }
}