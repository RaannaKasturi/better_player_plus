import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:better_player_plus/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player_plus/src/controls/better_player_clickable_widget.dart';
import 'package:better_player_plus/src/controls/better_player_controls_state.dart';
import 'package:better_player_plus/src/controls/better_player_material_progress_bar.dart';
import 'package:better_player_plus/src/controls/better_player_multiple_gesture_detector.dart';
import 'package:better_player_plus/src/controls/better_player_progress_colors.dart';
import 'package:better_player_plus/src/core/better_player_controller.dart';
import 'package:better_player_plus/src/core/better_player_utils.dart';
import 'package:better_player_plus/src/video_player/video_player.dart';

class BetterPlayerMaterialControls extends StatefulWidget {
  ///Callback used to send information if player bar is hidden or not
  final Function(bool visbility) onControlsVisibilityChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  const BetterPlayerMaterialControls({
    Key? key,
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _BetterPlayerMaterialControlsState();
  }
}

class _BetterPlayerMaterialControlsState
    extends BetterPlayerControlsState<BetterPlayerMaterialControls> {
  VideoPlayerValue? _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  Timer? _showAfterExpandCollapseTimer;
  bool _displayTapped = false;
  bool _wasLoading = false;
  VideoPlayerController? _controller;
  BetterPlayerController? _betterPlayerController;
  StreamSubscription? _controlsVisibilityStreamSubscription;

  BetterPlayerControlsConfiguration get _controlsConfiguration =>
      widget.controlsConfiguration;

  @override
  VideoPlayerValue? get latestValue => _latestValue;

  @override
  BetterPlayerController? get betterPlayerController => _betterPlayerController;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
      _controlsConfiguration;

  @override
  Widget build(BuildContext context) {
    return buildLTRDirectionality(_buildMainWidget());
  }

  ///Builds main widget of the controls.
  Widget _buildMainWidget() {
    _wasLoading = isLoading(_latestValue);

    if (_latestValue?.hasError == true) {
      return Stack(
        children: [
          Container(
            color: Colors.black,
            child: _buildErrorWidget(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              child: AnimatedOpacity(
                opacity: controlsNotVisible ? 1.0 : 1.0,
                duration: _controlsConfiguration.controlsHideTime,
                onEnd: _onPlayerHide,
                child: Container(
                  color: _controlsConfiguration.controlBarColor.withAlpha(
                    (0.75 * 255).toInt(),
                  ),
                  height: _controlsConfiguration.controlBarHeight,
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: Icon(
                              Icons.arrow_back,
                              color: _controlsConfiguration.textColor,
                            ),
                          ),
                          Text(
                            _controlsConfiguration.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              color: _controlsConfiguration.textColor,
                              fontSize: 16.0,
                            ),
                          ),
                        ],
                      ),
                      if (_controlsConfiguration.enablePip)
                        _buildPipButtonWrapperWidget(
                            controlsNotVisible, _onPlayerHide),
                      _buildMoreButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (isVideoFinished(_latestValue)) {
      return Stack(
        children: [
          Container(
            alignment: Alignment.center,
            color: Colors.black,
            child: _buildReplayButton(_controller!),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(title: _controlsConfiguration.title),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        BetterPlayerMultipleGestureDetector.of(context)?.onTap?.call();
        controlsNotVisible
            ? cancelAndRestartTimer()
            : changePlayerControlsNotVisible(true);
      },
      onDoubleTap: () {
        BetterPlayerMultipleGestureDetector.of(context)?.onDoubleTap?.call();
        cancelAndRestartTimer();
      },
      onLongPress: () {
        BetterPlayerMultipleGestureDetector.of(context)?.onLongPress?.call();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Loading or Gesture HitArea
          if (_wasLoading)
            Center(child: _buildLoadingWidget())
          else
            _buildHitArea(), // This includes double tap zones

          // Top and Bottom bars with visibility control
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(title: _controlsConfiguration.title),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(),
          ),

          // Next video pop-up
          _buildNextVideoWidget(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    _latestValue = _controller!.value;

    if (_oldController != _betterPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Widget _buildErrorWidget() {
    final errorBuilder =
        _betterPlayerController!.betterPlayerConfiguration.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(
          context,
          _betterPlayerController!
              .videoPlayerController!.value.errorDescription);
    } else {
      final textStyle = TextStyle(color: _controlsConfiguration.textColor);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              color: _controlsConfiguration.iconsColor,
              size: 42,
            ),
            Text(
              _betterPlayerController!.translations.generalDefaultError,
              style: textStyle,
            ),
            if (_controlsConfiguration.enableRetry)
              TextButton(
                onPressed: () {
                  _betterPlayerController!.retryDataSource();
                },
                child: Text(
                  _betterPlayerController!.translations.generalRetry,
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      );
    }
  }

  Widget _buildTopBar({required String title}) {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    return Container(
      child: (_controlsConfiguration.enableOverflowMenu)
          ? AnimatedOpacity(
              opacity: controlsNotVisible ? 0.0 : 1.0,
              duration: _controlsConfiguration.controlsHideTime,
              onEnd: _onPlayerHide,
              child: Container(
                color: _controlsConfiguration.controlBarColor.withAlpha(
                  (0.75 * 255).toInt(),
                ),
                height: _controlsConfiguration.controlBarHeight,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: Icon(
                            Icons.arrow_back,
                            color: _controlsConfiguration.textColor,
                          ),
                        ),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            color: _controlsConfiguration.textColor,
                            fontSize: 16.0,
                          ),
                        ),
                      ],
                    ),
                    if (_controlsConfiguration.enablePip)
                      _buildPipButtonWrapperWidget(
                          controlsNotVisible, _onPlayerHide),
                    _buildMoreButton(),
                  ],
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildPipButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        betterPlayerController!.enablePictureInPicture(
            betterPlayerController!.betterPlayerGlobalKey!);
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          betterPlayerControlsConfiguration.pipMenuIcon,
          color: betterPlayerControlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildPipButtonWrapperWidget(
      bool hideStuff, void Function() onPlayerHide) {
    return FutureBuilder<bool>(
      future: betterPlayerController!.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        final bool isPipSupported = snapshot.data ?? false;
        if (isPipSupported &&
            _betterPlayerController!.betterPlayerGlobalKey != null) {
          return AnimatedOpacity(
            opacity: hideStuff ? 0.0 : 1.0,
            duration: betterPlayerControlsConfiguration.controlsHideTime,
            onEnd: onPlayerHide,
            child: Container(
              height: betterPlayerControlsConfiguration.controlBarHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildPipButton(),
                ],
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMoreButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        onShowMoreClicked();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          _controlsConfiguration.overflowMenuIcon,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        padding: const EdgeInsets.only(top: 12.0, bottom: 6.0),
        color: _controlsConfiguration.controlBarColor.withAlpha(
          (0.75 * 255).toInt(),
        ),
        height: _controlsConfiguration.controlBarHeight + 20.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            if (_betterPlayerController!.isLiveStream())
              const SizedBox()
            else
              _controlsConfiguration.enableProgressBar
                  ? _buildProgressBar()
                  : const SizedBox(),
            Expanded(
              flex: 75,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_controlsConfiguration.enableMute)
                      _buildMuteButton(_controller),
                    if (_controlsConfiguration.enablePlayPause)
                      Row(
                        children: [
                          _buildSkipButton(),
                          _buildPlayPause(_controller!),
                          _buildForwardButton(),
                        ],
                      ),
                    if (_betterPlayerController!.isLiveStream())
                      _buildLiveWidget(),
                    if (_controlsConfiguration.enableFullscreen)
                      _buildExpandButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveWidget() {
    return Text(
      _betterPlayerController!.translations.controlsLive,
      style: TextStyle(
          color: _controlsConfiguration.liveTextColor,
          fontWeight: FontWeight.bold),
    );
  }

  Widget _buildExpandButton() {
    return Padding(
      padding: EdgeInsets.only(right: 12.0),
      child: BetterPlayerMaterialClickableWidget(
        onTap: _onExpandCollapse,
        child: AnimatedOpacity(
          opacity: controlsNotVisible ? 0.0 : 1.0,
          duration: _controlsConfiguration.controlsHideTime,
          child: Container(
            height: _controlsConfiguration.controlBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Icon(
                _betterPlayerController!.isFullScreen
                    ? _controlsConfiguration.fullscreenDisableIcon
                    : _controlsConfiguration.fullscreenEnableIcon,
                color: _controlsConfiguration.iconsColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHitArea() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return Container(
      height: double.infinity,
      width: double.infinity,
      child: Center(
        child: AnimatedOpacity(
          opacity: controlsNotVisible ? 0.0 : 1.0,
          duration: _controlsConfiguration.controlsHideTime,
          child: _buildMiddleRow(),
        ),
      ),
    );
  }

  Widget _buildMiddleRow() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: _betterPlayerController?.isLiveStream() == true
          ? const SizedBox()
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  flex: 2,
                  child: InkWell(
                    child: SizedBox(
                      height: double.infinity,
                      width: double.infinity,
                    ),
                    onDoubleTap: () {
                      skipBack();
                    },
                    onTap: () {
                      setState(() {
                        controlsNotVisible = !controlsNotVisible;
                      });
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: InkWell(
                    child: SizedBox(
                      height: double.infinity,
                      width: double.infinity,
                    ),
                    onDoubleTap: () {
                      _onPlayPause();
                    },
                    onTap: () {
                      setState(() {
                        controlsNotVisible = !controlsNotVisible;
                      });
                    },
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    child: SizedBox(
                      height: double.infinity,
                      width: double.infinity,
                    ),
                    onDoubleTap: () {
                      skipForward();
                    },
                    onTap: () {
                      setState(() {
                        controlsNotVisible = !controlsNotVisible;
                      });
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHitAreaClickableButton(
      {Widget? icon, required void Function() onClicked}) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 80.0, maxWidth: 80.0),
      child: BetterPlayerMaterialClickableWidget(
        onTap: onClicked,
        child: Align(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(48),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [icon!],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return _buildHitAreaClickableButton(
      icon: Icon(
        _controlsConfiguration.skipBackIcon,
        size: 24,
        color: _controlsConfiguration.iconsColor,
      ),
      onClicked: skipBack,
    );
  }

  Widget _buildForwardButton() {
    return _buildHitAreaClickableButton(
      icon: Icon(
        _controlsConfiguration.skipForwardIcon,
        size: 24,
        color: _controlsConfiguration.iconsColor,
      ),
      onClicked: skipForward,
    );
  }

  Widget _buildReplayButton(VideoPlayerController controller) {
    final bool isFinished = isVideoFinished(_latestValue);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildHitAreaClickableButton(
          icon: isFinished
              ? Icon(
                  Icons.replay,
                  size: 42,
                  color: _controlsConfiguration.iconsColor,
                )
              : Icon(
                  controller.value.isPlaying
                      ? _controlsConfiguration.pauseIcon
                      : _controlsConfiguration.playIcon,
                  size: 42,
                  color: _controlsConfiguration.iconsColor,
                ),
          onClicked: () {
            if (isFinished) {
              if (_latestValue != null && _latestValue!.isPlaying) {
                if (_displayTapped) {
                  changePlayerControlsNotVisible(true);
                } else {
                  cancelAndRestartTimer();
                }
              } else {
                _onPlayPause();
                changePlayerControlsNotVisible(true);
              }
            } else {
              _onPlayPause();
            }
          },
        ),
        Text(
          "Replay",
          style: TextStyle(
            color: _controlsConfiguration.textColor,
            fontSize: 16.0,
          ),
        ),
      ],
    );
  }

  Widget _buildNextVideoWidget() {
    return StreamBuilder<int?>(
      stream: _betterPlayerController!.nextVideoTimeStream,
      builder: (context, snapshot) {
        final time = snapshot.data;
        if (time != null && time > 0) {
          return BetterPlayerMaterialClickableWidget(
            onTap: () {
              _betterPlayerController!.playNextVideo();
            },
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: EdgeInsets.only(
                    bottom: _controlsConfiguration.controlBarHeight + 20,
                    right: 24),
                decoration: BoxDecoration(
                  color: _controlsConfiguration.controlBarColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "${_betterPlayerController!.translations.controlsNextVideoIn} $time...",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMuteButton(
    VideoPlayerController? controller,
  ) {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        cancelAndRestartTimer();
        if (_latestValue!.volume == 0) {
          _betterPlayerController!.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller!.value.volume;
          _betterPlayerController!.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRect(
          child: Container(
            height: _controlsConfiguration.controlBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              (_latestValue != null && _latestValue!.volume > 0)
                  ? _controlsConfiguration.muteIcon
                  : _controlsConfiguration.unMuteIcon,
              color: _controlsConfiguration.iconsColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPause(VideoPlayerController controller) {
    return BetterPlayerMaterialClickableWidget(
      key: const Key("better_player_material_controls_play_pause_button"),
      onTap: _onPlayPause,
      child: Container(
        height: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(
          controller.value.isPlaying
              ? _controlsConfiguration.pauseIcon
              : _controlsConfiguration.playIcon,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildStartPosition() {
    final position =
        _latestValue != null ? _latestValue!.position : Duration.zero;

    return Padding(
      padding: _controlsConfiguration.enablePlayPause
          ? const EdgeInsets.only(right: 12)
          : const EdgeInsets.symmetric(horizontal: 22),
      child: RichText(
        text: TextSpan(
          text: BetterPlayerUtils.formatDuration(position),
          style: TextStyle(
            fontSize: 10.0,
            color: _controlsConfiguration.textColor,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildEndPosition() {
    final duration = _latestValue != null && _latestValue!.duration != null
        ? _latestValue!.duration!
        : Duration.zero;

    return Padding(
      padding: _controlsConfiguration.enablePlayPause
          ? const EdgeInsets.only(left: 12)
          : const EdgeInsets.symmetric(horizontal: 22),
      child: RichText(
        text: TextSpan(
          text: BetterPlayerUtils.formatDuration(duration),
          style: TextStyle(
            fontSize: 10.0,
            color: _controlsConfiguration.textColor,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    changePlayerControlsNotVisible(false);
    _displayTapped = true;
  }

  Future<void> _initialize() async {
    _controller!.addListener(_updateState);

    _updateState();

    if ((_controller!.value.isPlaying) ||
        _betterPlayerController!.betterPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    if (_controlsConfiguration.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        changePlayerControlsNotVisible(false);
      });
    }

    _controlsVisibilityStreamSubscription =
        _betterPlayerController!.controlsVisibilityStream.listen((state) {
      changePlayerControlsNotVisible(!state);
      if (!controlsNotVisible) {
        cancelAndRestartTimer();
      }
    });
  }

  void _onExpandCollapse() {
    changePlayerControlsNotVisible(true);
    _betterPlayerController!.toggleFullScreen();
    _showAfterExpandCollapseTimer =
        Timer(_controlsConfiguration.controlsHideTime, () {
      setState(() {
        cancelAndRestartTimer();
      });
    });
  }

  void _onPlayPause() {
    bool isFinished = false;

    if (_latestValue?.position != null && _latestValue?.duration != null) {
      isFinished = _latestValue!.position >= _latestValue!.duration!;
    }

    if (_controller!.value.isPlaying) {
      changePlayerControlsNotVisible(false);
      _hideTimer?.cancel();
      _betterPlayerController!.pause();
    } else {
      cancelAndRestartTimer();

      if (!_controller!.value.initialized) {
      } else {
        if (isFinished) {
          _betterPlayerController!.seekTo(const Duration());
        }
        _betterPlayerController!.play();
        _betterPlayerController!.cancelNextVideoTimer();
      }
    }
  }

  void _startHideTimer() {
    if (_betterPlayerController!.controlsAlwaysVisible) {
      return;
    }
    _hideTimer = Timer(const Duration(milliseconds: 3000), () {
      changePlayerControlsNotVisible(true);
    });
  }

  void _updateState() {
    if (mounted) {
      if (!controlsNotVisible ||
          isVideoFinished(_controller!.value) ||
          _wasLoading ||
          isLoading(_controller!.value)) {
        setState(() {
          _latestValue = _controller!.value;
          if (isVideoFinished(_latestValue) &&
              _betterPlayerController?.isLiveStream() == false) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  Widget _buildProgressBar() {
    return Expanded(
      flex: 40,
      child: Container(
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            _buildStartPosition(),
            Expanded(
              child: BetterPlayerMaterialVideoProgressBar(
                _controller,
                _betterPlayerController,
                onDragStart: () {
                  _hideTimer?.cancel();
                },
                onDragEnd: () {
                  _startHideTimer();
                },
                onTapDown: () {
                  cancelAndRestartTimer();
                },
                colors: BetterPlayerProgressColors(
                    playedColor: _controlsConfiguration.progressBarPlayedColor,
                    handleColor: _controlsConfiguration.progressBarHandleColor,
                    bufferedColor:
                        _controlsConfiguration.progressBarBufferedColor,
                    backgroundColor:
                        _controlsConfiguration.progressBarBackgroundColor),
              ),
            ),
            _buildEndPosition(),
          ],
        ),
      ),
    );
  }

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return Container(
        color: _controlsConfiguration.controlBarColor,
        child: _controlsConfiguration.loadingWidget,
      );
    }

    return CircularProgressIndicator(
      valueColor:
          AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
    );
  }
}
