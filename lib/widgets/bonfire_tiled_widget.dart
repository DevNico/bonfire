import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../base/custom_game_widget.dart';
import '../bonfire.dart';
import '../tiled/model/tiled_world_data.dart';
import '../util/mixins/pointer_detector.dart';

class BonfireTiledWidget extends StatefulWidget {
  /// The player-controlling component.
  final JoystickController? joystick;

  /// Represents the character controlled by the user in the game. Instances of this class has actions and movements ready to be used and configured.
  final Player? player;

  /// The way you cand raw things like life bars, stamina and settings. In another words, anything that you may add to the interface to the game.
  final GameInterface? interface;

  /// Background of the game. This can be a color or custom component
  final GameBackground? background;

  /// Used to show grid in the map and facilitate the construction and testing of the map
  final bool constructionMode;

  /// Used to draw area collision in objects.
  final bool showCollisionArea;

  /// Used to show in the interface the FPS.
  final bool showFPS;

  /// Used to extensively control game elements
  final GameController? gameController;

  /// Color grid when `constructionMode` is true
  final Color? constructionModeColor;

  /// Color of the collision area when `showCollisionArea` is true
  final Color? collisionAreaColor;

  /// Used to configure lighting in the game
  final Color? lightingColorGame;

  /// Represents a map (or world) where the game occurs.
  final TiledWorldMap map;

  /// The [FocusNode] to control the games focus to receive event inputs.
  /// If omitted, defaults to an internally controlled focus node.
  final FocusNode? focusNode;

  /// Whether the [focusNode] requests focus once the game is mounted.
  /// Defaults to true.
  final bool autofocus;

  /// Initial mouse cursor for this [GameWidget]
  /// mouse cursor can be changed in runtime using [Game.mouseCursor]
  final MouseCursor? mouseCursor;

  final TapInGame? onTapDown;
  final TapInGame? onTapUp;

  final ValueChanged<BonfireGame>? onReady;
  final Map<String, OverlayWidgetBuilder<BonfireGame>>? overlayBuilderMap;
  final List<String>? initialActiveOverlays;
  final List<GameComponent>? components;
  final Widget? progress;
  final CameraConfig? cameraConfig;
  final AnimatedSwitcherTransitionBuilder transitionBuilder;
  final Duration progressTransitionDuration;
  final GameColorFilter? colorFilter;

  const BonfireTiledWidget({
    Key? key,
    required this.map,
    this.joystick,
    this.player,
    this.interface,
    this.background,
    this.constructionMode = false,
    this.showCollisionArea = false,
    this.showFPS = false,
    this.gameController,
    this.constructionModeColor,
    this.collisionAreaColor,
    this.lightingColorGame,
    this.progress,
    this.cameraConfig,
    this.transitionBuilder = AnimatedSwitcher.defaultTransitionBuilder,
    this.progressTransitionDuration = const Duration(milliseconds: 500),
    this.colorFilter,
    this.components,
    this.overlayBuilderMap,
    this.initialActiveOverlays,
    this.onTapDown,
    this.onTapUp,
    this.onReady,
    this.focusNode,
    this.autofocus = true,
    this.mouseCursor,
  }) : super(key: key);
  @override
  _BonfireTiledWidgetState createState() => _BonfireTiledWidgetState();
}

class _BonfireTiledWidgetState extends State<BonfireTiledWidget>
    with TickerProviderStateMixin {
  BonfireGame? _game;
  late StreamController<bool> _loadingStream;

  @override
  void didUpdateWidget(BonfireTiledWidget oldWidget) {
    if (widget.constructionMode) {
      widget.map.build().then((value) async {
        final game = _game;

        if (game != null) {
          await game.map.updateTiles(value.map.tiles);
          game.decorations().forEach((d) => d.removeFromParent());
          game.enemies().forEach((e) => e.removeFromParent());
          await Future.wait((value.components ?? [])
              .map(game.add)
              .where((element) => element != null)
              .map((e) => e!));
        }
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void initState() {
    _loadingStream = StreamController<bool>();
    _loadGame();
    super.initState();
  }

  @override
  void dispose() {
    _loadingStream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_game != null)
          CustomGameWidget(
            game: _game!,
            overlayBuilderMap: widget.overlayBuilderMap,
            initialActiveOverlays: widget.initialActiveOverlays,
            mouseCursor: widget.mouseCursor,
            autofocus: widget.autofocus,
            focusNode: widget.focusNode,
          ),
        StreamBuilder<bool>(
          stream: _loadingStream.stream,
          builder: (context, snapshot) {
            bool _loading = !snapshot.hasData || snapshot.data == true;
            return AnimatedSwitcher(
              duration: widget.progressTransitionDuration,
              transitionBuilder: widget.transitionBuilder,
              child: _loading ? _defaultProgress() : SizedBox.shrink(),
            );
          },
        ),
      ],
    );
  }

  void _loadGame() async {
    try {
      TiledWorldData tiled = await widget.map.build();

      setState(() {
        List<GameComponent> components = (tiled.components ?? []);
        components.addAll(widget.components ?? []);
        _game = BonfireGame(
          context: context,
          joystickController: widget.joystick,
          player: widget.player,
          interface: widget.interface,
          map: tiled.map,
          components: components,
          background: widget.background,
          constructionMode: widget.constructionMode,
          showCollisionArea: widget.showCollisionArea,
          showFPS: widget.showFPS,
          gameController: widget.gameController,
          constructionModeColor:
              widget.constructionModeColor ?? Colors.cyan.withOpacity(0.5),
          collisionAreaColor: widget.collisionAreaColor ??
              Colors.lightGreenAccent.withOpacity(0.5),
          lightingColorGame: widget.lightingColorGame,
          cameraConfig: widget.cameraConfig,
          colorFilter: widget.colorFilter,
          onTapDown: widget.onTapDown,
          onTapUp: widget.onTapUp,
          onReady: (game) {
            _showProgress(false);
            widget.onReady?.call(game);
          },
        );
      });
    } catch (e) {
      print('(BonfireTiledWidget) Error: $e');
    }
  }

  Widget _defaultProgress() {
    return widget.progress ??
        Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
  }

  void _showProgress(bool show) async {
    await Future.delayed(Duration.zero);
    _loadingStream.add(show);
  }
}
