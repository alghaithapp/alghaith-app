import 'package:flutter/material.dart';
import 'app_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFCFA), Color(0xFFFFF0E9), Color(0xFFFCE4DA)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80,
                left: -60,
                child: _SplashBlob(
                  size: 240,
                  colors: const [Color(0xFFFFD3BF), Color(0xFFFFA46B)],
                ),
              ),
              Positioned(
                bottom: -80,
                right: -60,
                child: _SplashBlob(
                  size: 220,
                  colors: const [Color(0xFFFFE0D4), Color(0xFFE84A3A)],
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    AppLogo(size: 150),
                    SizedBox(height: 22),
                    Text(
                      'الغيث',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                        color: Color(0xFF2A1A17),
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Color(0xFFE84A3A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _SplashBlob({
    required this.size,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}
