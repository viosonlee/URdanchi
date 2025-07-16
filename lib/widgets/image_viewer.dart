import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';

class ImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;

  const ImageViewer({super.key, required this.imageUrl, this.heroTag});

  static void show(BuildContext context, String imageUrl, {String? heroTag}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ImageViewer(
          imageUrl: imageUrl,
          heroTag: heroTag,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        barrierDismissible: true,
        opaque: false,
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // 设置状态栏为透明
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    // 恢复状态栏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    if (_transformationController.value.getMaxScaleOnAxis() == 1.0) {
      setState(() {
        _isZoomed = false;
      });
    } else {
      setState(() {
        _isZoomed = true;
      });
    }
  }

  void _resetZoom() {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.reset();
    _animationController.forward();
    
    _animation!.addListener(() {
      _transformationController.value = _animation!.value;
    });
    
    setState(() {
      _isZoomed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.network(
      widget.imageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            color: Colors.white,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.imageLoadFailed,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );

    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 背景点击关闭
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),
          // 图片查看器
          Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              onInteractionEnd: _onInteractionEnd,
              minScale: 1.0,
              maxScale: 4.0,
              child: GestureDetector(
                onTap: () {
                  if (!_isZoomed) {
                    Navigator.of(context).pop();
                  }
                },
                child: imageWidget,
              ),
            ),
          ),
          // 顶部工具栏
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 关闭按钮
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                // 重置缩放按钮
                if (_isZoomed)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.zoom_out, color: Colors.white),
                      onPressed: _resetZoom,
                    ),
                  ),
              ],
            ),
          ),
          // 底部提示文字
          if (!_isZoomed)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.pinchToZoomTapToReturn,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}