import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/danchi.dart';
import '../services/api_service.dart';
import '../services/subscription_service.dart';

import '../widgets/room_list_item.dart';
import 'package:flutter_html/flutter_html.dart';
import '../l10n/app_localizations.dart';

class DetailScreen extends StatefulWidget {
  final String danchiId;

  const DetailScreen({super.key, required this.danchiId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _apiService = ApiService();
  final _subscriptionService = SubscriptionService();
  DanchiInfo? _danchiInfo;
  final List<Room> _rooms = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _fetchDanchiInfo();
    _checkSubscriptionStatus();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
              _scrollController.position.maxScrollExtent &&
          _hasMore &&
          !_isLoading) {
        _fetchRooms();
      }
    });
  }

  Future<void> _fetchDanchiInfo() async {
    try {
      final danchiInfo = await _apiService.getDanchiInfo(widget.danchiId);
      setState(() {
        _danchiInfo = danchiInfo;
        _rooms.addAll(danchiInfo.rooms);
        _checkHasMore();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.failedToLoadDanchiInfo(e.toString()),
          ),
        ),
      );
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final isSubscribed = await _subscriptionService.isSubscribed(
        widget.danchiId,
      );
      setState(() {
        _isSubscribed = isSubscribed;
      });
    } catch (e) {
      debugPrint('获取团地信息错误: $e');
    }
  }

  Future<void> _toggleSubscription() async {
    try {
      bool success;
      if (_isSubscribed) {
        success = await _subscriptionService.unsubscribeFromDanchi(
          widget.danchiId,
        );
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.unsubscribed)),
          );
        }
      } else {
        success = await _subscriptionService.subscribeToDanchi(widget.danchiId);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.subscribed)),
          );
        }
      }

      if (success && mounted) {
        setState(() {
          _isSubscribed = !_isSubscribed;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.operationFailed(e.toString()),
          ),
        ),
      );
    }
  }

  Future<void> _fetchRooms({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    if (refresh) {
      _rooms.clear();
      _hasMore = true;
      await _fetchDanchiInfo();
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final lastId = _rooms.isNotEmpty ? _rooms.last.id : null;
      final newRooms = await _apiService.getRoomList(
        widget.danchiId,
        lastId: lastId,
      );
      setState(() {
        _rooms.addAll(newRooms);
        _isLoading = false;
        _checkHasMore();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.failedToLoadRooms(e.toString()),
          ),
        ),
      );
    }
  }

  void _checkHasMore() {
    if (_danchiInfo != null &&
        _danchiInfo!.roomCountAll != null &&
        _rooms.length >= (_danchiInfo!.roomCountAll ?? 0)) {
      _hasMore = false;
    }
  }

  Future<void> _openMapWithCoordinates(double lat, double lng) async {
    try {
      Uri mapUri;

      if (kIsWeb) {
        // Web平台打开Google Maps
        mapUri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        );
      } else {
        // 移动平台尝试打开原生地图应用
        // 先尝试Google Maps
        mapUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');

        // 如果不能打开原生地图，则打开网页版
        if (!await canLaunchUrl(mapUri)) {
          mapUri = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
          );
        }
      }

      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.cannotOpenUrl)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.failedToOpenMap(e.toString()),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _danchiInfo == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _fetchRooms(refresh: true),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    expandedHeight: 250.0,
                    floating: false,
                    pinned: true,
                    automaticallyImplyLeading: false,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isSubscribed ? Colors.red : Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isSubscribed
                                ? Icons.notifications_off
                                : Icons.notifications,
                            color: Colors.white,
                          ),
                          onPressed: _toggleSubscription,
                        ),
                      ),
                    ],
                    flexibleSpace: LayoutBuilder(
                      builder: (context, constraints) {
                        final double delta =
                            constraints.maxHeight - kToolbarHeight;
                        final bool collapsed = delta < 40;
                        
                        // 计算标题左边距，Android平台需要更大的间距来避免与返回按钮重叠
                        final double titleLeftPadding = collapsed 
                            ? (Theme.of(context).platform == TargetPlatform.android ? 80 : 72)
                            : 16;
                        
                        return FlexibleSpaceBar(
                          title: Text(
                            _danchiInfo!.name,
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: collapsed ? Colors.black87 : Colors.white,
                              shadows: collapsed
                                  ? []
                                  : [
                                      const Shadow(
                                        blurRadius: 6.0,
                                        color: Colors.black87,
                                        offset: Offset(1.0, 1.0),
                                      ),
                                    ],
                            ),
                          ),
                          titlePadding: EdgeInsets.only(
                            left: titleLeftPadding,
                            bottom: 16,
                          ),
                          collapseMode: CollapseMode.parallax,
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              (_danchiInfo!.image != null &&
                                      _danchiInfo!.image!.isNotEmpty)
                                  ? Image.network(
                                      _danchiInfo!.image!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      Colors.blue[400]!,
                                                      Colors.blue[600]!,
                                                    ],
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.apartment,
                                                  size: 100,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.blue[400]!,
                                            Colors.blue[600]!,
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.apartment,
                                        size: 100,
                                        color: Colors.white70,
                                      ),
                                    ),
                              // 渐变遮罩
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withAlpha(
                                        (0.3 * 255).round(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    backgroundColor: Colors.white,
                  ),
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16.0),
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha((0.1 * 255).round()),
                            spreadRadius: 0,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 地址
                          GestureDetector(
                            onTap: () {
                              _openMapWithCoordinates(
                                _danchiInfo!.lat,
                                _danchiInfo!.lng,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _danchiInfo!.address ?? '',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.clickToViewMap,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.open_in_new,
                                    color: Colors.green[600],
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 租金信息
                          if (_danchiInfo!.rent != null &&
                              _danchiInfo!.rent!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.monetization_on,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _danchiInfo!.rent!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_danchiInfo!.rent != null &&
                              _danchiInfo!.rent!.isNotEmpty)
                            const SizedBox(height: 16),
                          // 类型信息
                          if (_danchiInfo!.type != null &&
                              _danchiInfo!.type!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.purple,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.category,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _danchiInfo!.type!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_danchiInfo!.type != null &&
                              _danchiInfo!.type!.isNotEmpty)
                            const SizedBox(height: 16),
                          // 车站信息
                          if (_danchiInfo!.access != null &&
                              _danchiInfo!.access!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.train,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Html(data: _danchiInfo!.access!),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          // 团地链接
                          if (_danchiInfo!.link != null &&
                              _danchiInfo!.link!.isNotEmpty)
                            GestureDetector(
                              onTap: () async {
                                // 根据平台选择合适的团地链接
                                String? targetLink;
                                if (Theme.of(context).platform ==
                                        TargetPlatform.android ||
                                    Theme.of(context).platform ==
                                        TargetPlatform.iOS) {
                                  // 移动端优先使用 linkSp
                                  targetLink =
                                      _danchiInfo!.linkSp ?? _danchiInfo!.link;
                                } else {
                                  // PC端使用 link
                                  targetLink = _danchiInfo!.link;
                                }

                                if (targetLink != null &&
                                    targetLink.isNotEmpty) {
                                  final url = Uri.parse(
                                    targetLink.startsWith('http')
                                        ? targetLink
                                        : 'https://www.ur-net.go.jp$targetLink',
                                  );
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  } else {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(context)!.cannotOpenLink(
                                            targetLink,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.indigo[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.link,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.urDanchiDetailsPage,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.clickToViewOfficialDetails,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.indigo[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.open_in_new,
                                      color: Colors.indigo[600],
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          // 房间数量标题
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[600]!, Colors.blue[700]!],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.home_work,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.availableRoomsCount(
                                    _danchiInfo?.roomCountAll ?? _rooms.length,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _rooms.isEmpty && !_isLoading
                      ? SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(60),
                                  ),
                                  child: Icon(
                                    Icons.home_work_outlined,
                                    size: 60,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.noRoomsAvailable,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.pleaseTryLaterOrCheckOtherDanchi,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            if (index == _rooms.length) {
                              return _hasMore
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.allRoomsLoaded,
                                        ),
                                      ),
                                    );
                            }
                            final room = _rooms[index];

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: RoomListItem(room: room),
                            );
                          }, childCount: _rooms.length + (_hasMore ? 1 : 0)),
                        ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
