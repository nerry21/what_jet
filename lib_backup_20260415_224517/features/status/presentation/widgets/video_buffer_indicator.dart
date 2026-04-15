import 'package:flutter/material.dart';

class VideoBufferIndicator extends StatelessWidget {
  const VideoBufferIndicator({
    super.key,
    required this.isBuffering,
    required this.isError,
    required this.onRetry,
  });

  final bool isBuffering;
  final bool isError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!isBuffering && !isError) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: isError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Media gagal dimuat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const <Widget>[
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Menyiapkan media...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
