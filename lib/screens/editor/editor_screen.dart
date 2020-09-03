import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:app.gridpicture/extensions/file_extension.dart';
import 'package:app.gridpicture/helpers/file_helpers.dart';
import 'package:app.gridpicture/screens/editor/editor_channel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'common/constants.dart';
import 'common/helper.dart';
import 'widgets/crop_painter.dart';

class EditorScreen extends StatefulWidget {
  final File image;
  final double maximumScale;
  final ImageErrorListener onImageError;
  final double chipRadius;
  final String chipShape;

  const EditorScreen(
      {Key key,
        this.image,
        this.maximumScale: 2.0,
        this.onImageError,
        this.chipRadius = 150,
        this.chipShape = 'circle'})
      : assert(image != null),
        assert(maximumScale != null),
        super(key: key);

  @override
  State<StatefulWidget> createState() => EditorScreenState();

  static EditorScreenState of(BuildContext context) {
    return context.findAncestorStateOfType();
  }
}

class EditorScreenState extends State<EditorScreen> with TickerProviderStateMixin, Drag {
  final _surfaceKey = GlobalKey();
  AnimationController _activeController;
  AnimationController _settleController;
  ImageStream _imageStream;
  ui.Image _image;
  double _scale;
  double _ratio;
  Rect _view;
  Rect _area;
  Offset _lastFocalPoint;
  CropAction _action;
  double _startScale;
  Rect _startView;
  Tween<Rect> _viewTween;
  Tween<double> _scaleTween;
  ImageStreamListener _imageListener;

  double get scale => _area.shortestSide / _scale;

  Rect get area {
    return _view.isEmpty
        ? null
        : Rect.fromLTWH(
      _area.left * _view.width / _scale - _view.left,
      _area.top * _view.height / _scale - _view.top,
      _area.width * _view.width / _scale,
      _area.height * _view.height / _scale,
    );
  }

  bool get _isEnabled => !_view.isEmpty && _image != null;

  CropNumber _cropNumber = CropNumber.Three;

  @override
  void initState() {
    super.initState();
    _area = Rect.zero;
    _view = Rect.zero;
    _scale = 1.0;
    _ratio = 1.0;
    _lastFocalPoint = Offset.zero;
    _action = CropAction.none;
    _activeController = AnimationController(
      vsync: this,
      value: 0.0,
    )..addListener(() => setState(() {})); // 裁剪背景灰度控制
    _settleController = AnimationController(vsync: this)
      ..addListener(_settleAnimationChanged);
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_imageListener);
    _activeController.dispose();
    _settleController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _getImage();
  }

  @override
  void didUpdateWidget(EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) {
      _getImage();
    }
    _activate(1.0);
  }

  Future<void> cropCompleted(File file, {int pictureQuality = 1}) async {
    final options = await EditorChannel.getImageOptions(file: file);
    debugPrint('image width: ${options.width}, height: ${options.height}');

    List<Rect> areas = getAreasOfImage(area, _cropNumber);

    int index = 0;
    for(Rect rect in areas) {
      var croppedFile = await EditorChannel.cropImage(
        file: file,
        area: rect,
      );
      croppedFile.copySync(FileHelper.pictureFolder + '/${index}_' + croppedFile.name);
      croppedFile.deleteSync();
      index++;
    }
  }

  void _getImage({bool force: false}) {
    final oldImageStream = _imageStream;
    _imageStream = FileImage(widget.image).resolve(createLocalImageConfiguration(context));
    if (_imageStream.key != oldImageStream?.key || force) {
      oldImageStream?.removeListener(_imageListener);
      _imageListener = ImageStreamListener(_updateImage, onError: widget.onImageError);
      _imageStream.addListener(_imageListener);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          ConstrainedBox(
              constraints: const BoxConstraints.expand(),
              child: GestureDetector(
                key: _surfaceKey,
                behavior: HitTestBehavior.opaque,
                onScaleStart: _isEnabled ? _handleScaleStart : null,
                onScaleUpdate: _isEnabled ? _handleScaleUpdate : null,
                onScaleEnd: _isEnabled ? _handleScaleEnd : null,
                child: CustomPaint(
                  painter: CropPainter(
                    image: _image,
                    ratio: _ratio,
                    view: _view,
                    area: _area,
                    scale: _scale,
                    active: _activeController.value,
                    chipShape: widget.chipShape,
                    cropNumber: _cropNumber
                  ),
                ),
              ),
          ),
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            child: Container(
              color: Colors.black12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, size: 30, color: Colors.white),
                  ),
                  CupertinoButton(
                    onPressed: () => cropCompleted(widget.image),
                    child: Icon(Icons.check, size: 30, color: Colors.white),
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            left: 0,
            child: Container(
              color: Colors.black12,
              padding: EdgeInsets.only(left: 20, right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => setState((){ _cropNumber = CropNumber.TwoV; }),
                    child: Opacity(
                      opacity: _cropNumber == CropNumber.TwoV ? 1 : 0.6,
                      child: Image.asset('resources/images/two-h.png' , width: 24),
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => setState((){ _cropNumber = CropNumber.TwoH; }),
                    child: Opacity(
                        opacity: _cropNumber == CropNumber.TwoH ? 1 : 0.6,
                        child: Image.asset('resources/images/two-v.png' , width: 24)
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => setState((){ _cropNumber = CropNumber.Three; }),
                    child: Opacity(
                        opacity: _cropNumber == CropNumber.Three ? 1 : 0.6,
                        child: Image.asset('resources/images/three.png' , width: 24)
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => setState((){ _cropNumber = CropNumber.Four; }),
                    child: Opacity(
                        opacity: _cropNumber == CropNumber.Four ? 1 : 0.6,
                        child: Image.asset('resources/images/four-2.png' , width: 24)
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => setState((){ _cropNumber = CropNumber.FourEvenly; }),
                    child: Opacity(
                        opacity: _cropNumber == CropNumber.FourEvenly ? 1 : 0.6,
                        child: Image.asset('resources/images/four.png' , width: 24)
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _activate(double val) {
    _activeController.animateTo(
      val,
      curve: Curves.fastOutSlowIn,
      duration: const Duration(milliseconds: 250),
    );
  }

  // NOTE: 区域性缩小 总区域 - 10 * 10 区域
  Size get _boundaries {
    return _surfaceKey.currentContext.size -
        Offset(kCropHandleSize, kCropHandleSize);
  }

  void _settleAnimationChanged() {
    setState(() {
      _scale = _scaleTween.transform(_settleController
          .value); // 将0 ～ 1的动画转变过程，转换至 _scaleTween 的begin ~ end
      _view = _viewTween.transform(_settleController.value);
    });
  }

  Rect _calculateDefaultArea({
    int imageWidth,
    int imageHeight,
    double viewWidth,
    double viewHeight,
  }) {
    if (imageWidth == null || imageHeight == null) {
      return Rect.zero;
    }

    final _deviceWidth =
        MediaQuery.of(context).size.width - (2 * kCropHandleSize);
    final _areaOffset = (_deviceWidth - (widget.chipRadius * 2));
    final _areaOffsetRadio = _areaOffset / _deviceWidth;
    final width = 1.0 - _areaOffsetRadio;

    final height =
        (imageWidth * viewWidth * width) / (imageHeight * viewHeight * 1.0);
    return Rect.fromLTWH((1.0 - width) / 2, (1.0 - height) / 2, width, height);
  }

  void _updateImage(ImageInfo imageInfo, bool synchronousCall) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      setState(() {
        _image = imageInfo.image;
        _scale = imageInfo.scale;

        // NOTE: conver img  _ratio value >= 0
        _ratio = max(
          _boundaries.width / _image.width,
          _boundaries.height / _image.height,
        );

        // NOTE: 计算图片显示比值，最大1.0为全部显示
        final viewWidth = _boundaries.width / (_image.width * _scale * _ratio);
        final viewHeight =
            _boundaries.height / (_image.height * _scale * _ratio);
        _area = _calculateDefaultArea(
          viewWidth: viewWidth,
          viewHeight: viewHeight,
          imageWidth: _image.width,
          imageHeight: _image.height,
        );

        // NOTE: 相对于整体图片已显示的view大小， viewWidth - 1.0 为未显示区域， / 2 算出 left的比例模型
        _view = Rect.fromLTWH(
          (viewWidth - 1.0) / 2,
          (viewHeight - 1.0) / 2,
          viewWidth,
          viewHeight,
        );
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _activate(1.0);
    _settleController.stop(canceled: false);
    _lastFocalPoint = details.focalPoint;
    _action = CropAction.none;
    _startScale = _scale;
    _startView = _view;
  }

  Rect _getViewInBoundaries(double scale) {
    return Offset(
      max(
        min(
          _view.left,
          _area.left * _view.width / scale,
        ),
        _area.right * _view.width / scale - 1.0,
      ),
      max(
        min(
          _view.top,
          _area.top * _view.height / scale,
        ),
        _area.bottom * _view.height / scale - 1.0,
      ),
    ) &
    _view.size;
  }

  double get _maximumScale => widget.maximumScale;

  double get _minimumScale {
    final scaleX = _boundaries.width * _area.width / (_image.width * _ratio);
    final scaleY = _boundaries.height * _area.height / (_image.height * _ratio);
    return min(_maximumScale, max(scaleX, scaleY));
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _activate(0);

    final targetScale =
    _scale.clamp(_minimumScale, _maximumScale); //NOTE: 处理缩放边界值
    _scaleTween = Tween<double>(
      begin: _scale,
      end: targetScale,
    );

    _startView = _view;
    _viewTween = RectTween(
      begin: _view,
      end: _getViewInBoundaries(targetScale),
    );

    _settleController.value = 0.0;
    _settleController.animateTo(
      1.0,
      curve: Curves.fastOutSlowIn,
      duration: const Duration(milliseconds: 350),
    );
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    _action = details.rotation == 0.0 && details.scale == 1.0
        ? CropAction.moving
        : CropAction.scaling;

    if (_action == CropAction.moving) {
      final delta = details.focalPoint - _lastFocalPoint; // offset相减 得出一次相对移动距离
      _lastFocalPoint = details.focalPoint;

      setState(() {
        // move只做两维方向移动
        _view = _view.translate(
          delta.dx / (_image.width * _scale * _ratio),
          delta.dy / (_image.height * _scale * _ratio),
        );
      });
    } else if (_action == CropAction.scaling) {
      setState(() {
        _scale = _startScale * details.scale;

        // 计算已缩放的比值；
        final dx = _boundaries.width *
            (1.0 - details.scale) /
            (_image.width * _scale * _ratio);
        final dy = _boundaries.height *
            (1.0 - details.scale) /
            (_image.height * _scale * _ratio);

        _view = Rect.fromLTWH(
          _startView.left + dx / 2,
          _startView.top + dy / 2,
          _startView.width,
          _startView.height,
        );
      });
    }
  }
}
