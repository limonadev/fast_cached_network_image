import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'models/fast_cache_progress_data.dart';
import 'package:dio/dio.dart';

class FastCachedImage extends StatefulWidget {
  ///Provide the [url] for the image to display.
  final String url;

  ///Provide the [headers] for the image to display.
  final Map<String, dynamic>? headers;

  ///[errorBuilder] must return a widget. This widget will be displayed if there is any error in downloading or displaying
  ///the downloaded image
  final ImageErrorWidgetBuilder? errorBuilder;

  /// [errorListener] will be called every time an error occurs while providing
  /// the image. This callback should not depend on the context of the widget
  /// tree, as an error can occur after this widget is disposed (for example
  /// if the widget is disposed before the Future of fetching the image is
  /// completed).
  final void Function(Object, StackTrace?)? errorListener;

  ///[loadingBuilder] is the builder which can show the download progress of an image.

  ///Usage: loadingBuilder(context, FastCachedProgressData progressData){return  Text('${progress.downloadedBytes ~/ 1024} / ${progress.totalBytes! ~/ 1024} kb')}
  final Widget Function(BuildContext, FastCachedProgressData)? loadingBuilder;

  ///[fadeInDuration] can be adjusted to change the duration of the fade transition between the [loadingBuilder]
  ///and the actual image. Default value is 500 ms.
  final Duration fadeInDuration;

  final int? cacheWidth;
  final int? cacheHeight;

  /// If [cacheWidth] or [cacheHeight] are provided, it indicates to the
  /// engine that the image must be decoded at the specified size. The image
  /// will be rendered to the constraints of the layout or [width] and [height]
  /// regardless of these parameters. These parameters are primarily intended
  /// to reduce the memory usage of [ImageCache].
  /// If non-null, this color is blended with each image pixel using [colorBlendMode].
  /// If the image is of a high quality and its pixels are perfectly aligned
  /// with the physical screen pixels, extra quality enhancement may not be
  /// necessary. If so, then [FilterQuality.none] would be the most efficient.
  ///[width] width of the image
  final double? width;

  ///[height] of the image
  final double? height;

  ///[scale] property in Flutter memory image.
  final double scale;

  ///[color] property in Flutter memory image.
  final Color? color;

  ///[opacity] property in Flutter memory image.
  final Animation<double>? opacity;

  /// If the pixels are not perfectly aligned with the screen pixels, or if the
  /// image itself is of a low quality, [FilterQuality.none] may produce
  /// undesirable artifacts. Consider using other [FilterQuality] values to
  /// improve the rendered image quality in this case. Pixels may be misaligned
  /// with the screen pixels as a result of transforms or scaling.
  /// [opacity] can be used to adjust the opacity of the image.
  /// Used to combine [color] with this image.
  final FilterQuality filterQuality;

  ///[colorBlendMode] property in Flutter memory image
  final BlendMode? colorBlendMode;

  ///[fit] How a box should be inscribed into another box
  final BoxFit? fit;

  /// The alignment aligns the given position in the image to the given position
  /// in the layout bounds. For example, an [Alignment] alignment of (-1.0,
  /// -1.0) aligns the image to the top-left corner of its layout bounds, while an
  /// [Alignment] alignment of (1.0, 1.0) aligns the bottom right of the
  /// image with the bottom right corner of its layout bounds. Similarly, an
  /// alignment of (0.0, 1.0) aligns the bottom middle of the image with the
  /// middle of the bottom edge of its layout bounds.
  final AlignmentGeometry alignment;

  ///[repeat] property in Flutter memory image.
  final ImageRepeat repeat;

  ///[centerSlice] property in Flutter memory image.
  final Rect? centerSlice;

  ///[matchTextDirection] property in Flutter memory image.
  final bool matchTextDirection;

  /// Whether to continue showing the old image (true), or briefly show nothing
  /// (false), when the image provider changes. The default value is false.
  ///
  /// ## Design discussion
  ///
  /// ### Why is the default value of [gaplessPlayback] false?
  ///
  /// Having the default value of [gaplessPlayback] be false helps prevent
  /// situations where stale or misleading information might be presented.
  /// Consider the following case:
  final bool gaplessPlayback;

  ///[semanticLabel] property in Flutter memory image.
  final String? semanticLabel;

  ///[excludeFromSemantics] property in Flutter memory image.
  final bool excludeFromSemantics;

  ///[isAntiAlias] property in Flutter memory image.
  final bool isAntiAlias;

  ///[showDebugLogs] can be set to false if you want to ignore debug logs.
  final bool showDebugLogs;

  ///[FastCachedImage] creates a widget to display network images. This widget downloads the network image
  ///when this widget is build for the first time. Later whenever this widget is called the image will be displayed from
  ///the downloaded database instead of the network. This can avoid unnecessary downloads and load images much faster.
  const FastCachedImage({
    required this.url,
    this.headers,
    this.scale = 1.0,
    this.errorBuilder,
    this.errorListener,
    this.semanticLabel,
    this.loadingBuilder,
    this.excludeFromSemantics = false,
    this.showDebugLogs = true,
    this.width,
    this.height,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.gaplessPlayback = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.low,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.cacheWidth,
    this.cacheHeight,
    Key? key,
  }) : super(key: key);

  @override
  State<FastCachedImage> createState() => _FastCachedImageState();
}

class _FastCachedImageState extends State<FastCachedImage>
    with TickerProviderStateMixin {
  ///[_animation] not public API.
  late final Animation<double> _animation;

  ///[_animationController] not public API.
  late final AnimationController _animationController;

  ///[_progressData] holds the data indicating the progress of download.
  late final FastCachedProgressData _progressData;

  /// [_dio] is responsible of fetching the image if it's not cached yet.
  late final Dio _dio;

  ///[_imageResponse] not public API.
  _ImageResponse? _imageResponse;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: widget.fadeInDuration,
    );
    _animation = Tween<double>(
      begin: widget.fadeInDuration == Duration.zero ? 1 : 0,
      end: 1,
    ).animate(_animationController);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _loadAsync(widget.url, widget.headers);
      _animationController.addStatusListener(_animationListener);
    });

    _progressData = FastCachedProgressData(
      progressPercentage: ValueNotifier(0),
      totalBytes: null,
      downloadedBytes: 0,
      isDownloading: false,
    );

    _dio = Dio();
  }

  @override
  void dispose() {
    _animationController.removeStatusListener(
      _animationListener,
    );
    _animationController.dispose();
    super.dispose();
  }

  void _animationListener(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        mounted &&
        widget.fadeInDuration != Duration.zero) {
      setState(() {});
    }
  }

  Future<Uint8List?> _loadImageFromCache(String url) async {
    try {
      FastCachedImageConfig._checkInit();
      final image = await FastCachedImageConfig._getImage(url);

      return image;
    } catch (e, s) {
      widget.errorListener?.call(e, s);
    }

    return null;
  }

  Future<Uint8List> _loadImageFromNetwork(
    String url,
    Map<String, dynamic>? headers,
  ) async {
    try {
      final resolvedUri = Uri.base.resolve(url);

      _progressData.isDownloading = true;

      final response = await _dio.get<Uint8List>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
        ),
        onReceiveProgress: (int received, int total) {
          try {
            if (received < 0 || total < 0) {
              return;
            }
            if (widget.loadingBuilder != null) {
              _progressData.downloadedBytes = received;
              _progressData.totalBytes = total;
              _progressData.progressPercentage.value =
                  double.parse((received / total).toStringAsFixed(2));
            }
          } catch (e, s) {
            widget.errorListener?.call(e, s);
          }
        },
      );

      if (response.statusCode != 200) {
        throw NetworkImageLoadException(
          statusCode: response.statusCode ?? 0,
          uri: resolvedUri,
        );
      }

      _progressData.isDownloading = false;

      final bytes = response.data;

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Image is empty.');
      }

      await FastCachedImageConfig._saveImage(url, bytes);

      return bytes;
    } catch (e, s) {
      widget.errorListener?.call(e, s);
      rethrow;
    }
  }

  ///[_loadAsync] Not public API.
  Future<void> _loadAsync(String url, Map<String, dynamic>? headers) async {
    final cacheImage = await _loadImageFromCache(url);
    if (cacheImage != null && mounted) {
      setState(() {
        _imageResponse = _ImageResponse(
          imageData: cacheImage,
          error: null,
        );
      });
      if (widget.loadingBuilder == null) {
        _animationController.forward();
      }

      return;
    }

    try {
      final networkImage = await _loadImageFromNetwork(url, headers);

      if (mounted) {
        setState(() {
          _imageResponse = _ImageResponse(
            imageData: networkImage,
            error: null,
          );
        });
        if (widget.loadingBuilder == null) {
          _animationController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _imageResponse = _ImageResponse(
            imageData: Uint8List.fromList([]),
            error: e.toString(),
          );
        });
      }
    }
  }

  void _logDebugErrors(dynamic object) {
    if (widget.showDebugLogs) {
      debugPrint('$object - Image url : ${widget.url}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageResponse?.error != null && widget.errorBuilder != null) {
      _logDebugErrors(_imageResponse?.error);
      return widget.errorBuilder!(
        context,
        Object,
        StackTrace.fromString(_imageResponse!.error!),
      );
    }

    return SizedBox(
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.passthrough,
        children: [
          if (_animationController.status != AnimationStatus.completed &&
              widget.loadingBuilder != null) ...[
            ValueListenableBuilder(
              valueListenable: _progressData.progressPercentage,
              builder: (context, p, c) {
                return widget.loadingBuilder!(context, _progressData);
              },
            ),
          ],
          if (_imageResponse != null)
            FadeTransition(
              opacity: _animation,
              child: Image.memory(
                _imageResponse!.imageData,
                color: widget.color,
                width: widget.width,
                height: widget.height,
                alignment: widget.alignment,
                key: widget.key,
                cacheWidth: widget.cacheWidth,
                cacheHeight: widget.cacheHeight,
                fit: widget.fit,
                errorBuilder: (context, e, s) {
                  if (_animationController.status !=
                      AnimationStatus.completed) {
                    _animationController.forward();
                    _logDebugErrors(widget.showDebugLogs);
                    widget.errorListener?.call(e, s);
                    FastCachedImageConfig.deleteCachedImage(
                      imageUrl: widget.url,
                      showDebugLogs: widget.showDebugLogs,
                    ).ignore();
                  }
                  return widget.errorBuilder != null
                      ? widget.errorBuilder!(context, e, s)
                      : const SizedBox();
                },
                centerSlice: widget.centerSlice,
                colorBlendMode: widget.colorBlendMode,
                excludeFromSemantics: widget.excludeFromSemantics,
                filterQuality: widget.filterQuality,
                gaplessPlayback: widget.gaplessPlayback,
                isAntiAlias: widget.isAntiAlias,
                matchTextDirection: widget.matchTextDirection,
                opacity: widget.opacity,
                repeat: widget.repeat,
                scale: widget.scale,
                semanticLabel: widget.semanticLabel,
                frameBuilder: widget.loadingBuilder != null
                    ? (context, child, frame, _) {
                        if (frame == null) {
                          return widget.loadingBuilder!(
                            context,
                            FastCachedProgressData(
                              progressPercentage:
                                  _progressData.progressPercentage,
                              totalBytes: _progressData.totalBytes,
                              downloadedBytes: _progressData.downloadedBytes,
                              isDownloading: false,
                            ),
                          );
                        }

                        if (_animationController.status !=
                            AnimationStatus.completed) {
                          _animationController.forward();
                        }
                        return child;
                      }
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageResponse {
  Uint8List imageData;
  String? error;
  _ImageResponse({required this.imageData, required this.error});
}

///[FastCachedImageConfig] is the class to manage and set the cache configurations.
class FastCachedImageConfig {
  static LazyBox? _imageKeyBox;
  static LazyBox? _imageBox;
  static const String _notInitMessage =
      'FastCachedImage is not initialized. Please use FastCachedImageConfig.init to initialize FastCachedImage';

  ///[init] function initializes the cache management system. Use this code only once in the app in main to avoid errors.
  /// You can provide a [subDir] where the boxes should be stored.
  ///[clearCacheAfter] property is used to set a  duration after which the cache will be cleared.
  ///Default value of [clearCacheAfter] is 7 days which means if [clearCacheAfter] is set to null,
  /// an image cached today will be cleared when you open the app after 7 days from now.
  static Future<void> init({
    String? subDir,
    Duration? clearCacheAfter,
    bool isHiveAlreadyInitialized = false,
  }) async {
    clearCacheAfter ??= const Duration(days: 7);

    if (!isHiveAlreadyInitialized) {
      await Hive.initFlutter(subDir);
    }

    if (!Hive.isBoxOpen(_BoxNames.imagesKeyBox)) {
      _imageKeyBox = await Hive.openLazyBox(_BoxNames.imagesKeyBox);
    }
    if (!Hive.isBoxOpen(_BoxNames.imagesBox)) {
      _imageBox = await Hive.openLazyBox(_BoxNames.imagesBox);
    }

    await _clearOldCache(clearCacheAfter);
  }

  static Future<Uint8List?> _getImage(String url) async {
    final key = _keyFromUrl(url);
    if (_imageKeyBox!.keys.contains(url) && _imageBox!.containsKey(url)) {
      // Migrating old keys to new keys
      await _replaceImageKey(oldKey: url, newKey: key);
      await _replaceOldImage(
          oldKey: url, newKey: key, image: await _imageBox!.get(url));
    }

    if (_imageKeyBox!.keys.contains(key) && _imageBox!.keys.contains(key)) {
      Uint8List? data = await _imageBox!.get(key);
      if (data == null || data.isEmpty) return null;

      return data;
    }

    return null;
  }

  ///[_saveImage] is to save an image to cache. Not part of public API.
  static Future<void> _saveImage(String url, Uint8List image) async {
    final key = _keyFromUrl(url);

    await _imageKeyBox!.put(key, DateTime.now());
    await _imageBox!.put(key, image);
  }

  ///[_clearOldCache] clears the old cache. Not part of public API.
  static Future<void> _clearOldCache(Duration clearCacheAfter) async {
    DateTime today = DateTime.now();

    for (final key in _imageKeyBox!.keys) {
      DateTime? dateCreated = await _imageKeyBox!.get(key);

      if (dateCreated == null) continue;

      if (today.difference(dateCreated) > clearCacheAfter) {
        await _imageKeyBox!.delete(key);
        await _imageBox!.delete(key);
      }
    }
  }

  static Future<void> _replaceImageKey(
      {required String oldKey, required String newKey}) async {
    _checkInit();

    DateTime? dateCreated = await _imageKeyBox!.get(oldKey);

    if (dateCreated == null) return;

    _imageKeyBox!.delete(oldKey);
    _imageKeyBox!.put(newKey, dateCreated);
  }

  static Future<void> _replaceOldImage({
    required String oldKey,
    required String newKey,
    required Uint8List image,
  }) async {
    await _imageBox!.delete(oldKey);
    await _imageBox!.put(newKey, image);
  }

  ///[deleteCachedImage] function takes in a image [imageUrl] and removes the image corresponding to the url
  /// from the cache if the image is present in the cache.
  static Future<void> deleteCachedImage({
    required String imageUrl,
    bool showDebugLogs = true,
  }) async {
    _checkInit();

    final key = _keyFromUrl(imageUrl);
    if (_imageKeyBox!.keys.contains(key) && _imageBox!.keys.contains(key)) {
      await _imageKeyBox!.delete(key);
      await _imageBox!.delete(key);
      if (showDebugLogs) {
        debugPrint('FastCacheImage: Removed image $imageUrl from cache.');
      }
    }
  }

  ///[clearAllCachedImages] function clears all cached images. This can be used in scenarios such as
  ///logout functionality of your app, so that all cached images corresponding to the user's account is removed.
  static Future<void> clearAllCachedImages({bool showLog = true}) async {
    _checkInit();
    await _imageKeyBox!.deleteFromDisk();
    await _imageBox!.deleteFromDisk();
    if (showLog) debugPrint('FastCacheImage: All cache cleared.');
    _imageKeyBox = await Hive.openLazyBox(_BoxNames.imagesKeyBox);
    _imageBox = await Hive.openLazyBox(_BoxNames.imagesBox);
  }

  ///[_checkInit] method ensures the hive db is initialized. Not part of public API
  static void _checkInit() {
    if ((FastCachedImageConfig._imageKeyBox == null ||
            !FastCachedImageConfig._imageKeyBox!.isOpen) ||
        FastCachedImageConfig._imageBox == null ||
        !FastCachedImageConfig._imageBox!.isOpen) {
      throw Exception(_notInitMessage);
    }
  }

  ///[isCached] returns a boolean indicating whether the given image is cached or not.
  ///Returns true if cached, false if not.
  static bool isCached({required String imageUrl}) {
    _checkInit();

    final key = _keyFromUrl(imageUrl);
    if (_imageKeyBox!.containsKey(key) && _imageBox!.keys.contains(key)) {
      return true;
    }
    return false;
  }

  static _keyFromUrl(String url) => const Uuid().v5(Uuid.NAMESPACE_URL, url);
}

///[_BoxNames] contains the name of the boxes. Not part of public API
class _BoxNames {
  ///[imagesBox] db for images
  static String imagesBox = 'cachedImages';

  ///[imagesKeyBox] db for keys of images
  static String imagesKeyBox = 'cachedImagesKeys';
}

/// The fast cached image implementation of [image_provider.NetworkImage].
@immutable
class FastCachedImageProvider extends ImageProvider<NetworkImage>
    implements NetworkImage {
  /// Creates an object that fetches the image at the given URL.
  ///
  /// The arguments [url] and [scale] must not be null.
  const FastCachedImageProvider(this.url, {this.scale = 1.0, this.headers});

  @override
  final String url;

  @override
  final double scale;

  @override
  final Map<String, String>? headers;

  @override
  Future<FastCachedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<FastCachedImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadBuffer(
      NetworkImage key, DecoderBufferCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key as FastCachedImageProvider, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<NetworkImage>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    FastCachedImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderBufferCallback decode,
  ) async {
    try {
      assert(key == this);
      Dio dio = Dio();
      FastCachedImageConfig._checkInit();
      Uint8List? image = await FastCachedImageConfig._getImage(url);
      if (image != null) {
        final ui.ImmutableBuffer buffer =
            await ui.ImmutableBuffer.fromUint8List(image);
        return decode(buffer);
      }

      final Uri resolved = Uri.base.resolve(key.url);

      if (headers != null) dio.options.headers.addAll(headers!);
      Response response = await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (int received, int total) {
          chunkEvents.add(ImageChunkEvent(
            cumulativeBytesLoaded: received,
            expectedTotalBytes: total,
          ));
        },
      );

      final Uint8List bytes = response.data;
      if (bytes.lengthInBytes == 0) {
        throw Exception('NetworkImage is an empty file: $resolved');
      }

      final ui.ImmutableBuffer buffer =
          await ui.ImmutableBuffer.fromUint8List(bytes);
      await FastCachedImageConfig._saveImage(url, bytes);
      return decode(buffer);
    } catch (e) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    } finally {
      await chunkEvents.close();
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is FastCachedImageProvider &&
        other.url == url &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'NetworkImage')}("$url", scale: $scale)';
}
