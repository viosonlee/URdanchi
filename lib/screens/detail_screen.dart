import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/danchi.dart';
import '../services/api_service.dart';
import 'package:flutter_html/flutter_html.dart';

class DetailScreen extends StatefulWidget {
  final String danchiId;

  const DetailScreen({Key? key, required this.danchiId}) : super(key: key);

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _apiService = ApiService();
  DanchiInfo? _danchiInfo;
  final List<Room> _rooms = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchDanchiInfo();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _hasMore && !_isLoading) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load danchi info: $e')),
        );
      }
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
      final newRooms = await _apiService.getRoomList(widget.danchiId, lastId: lastId);
      setState(() {
        _rooms.addAll(newRooms);
        _isLoading = false;
        _checkHasMore();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load rooms: $e')),
        );
      }
    }
  }

  void _checkHasMore() {
    if (_danchiInfo != null && _danchiInfo!.roomCountAll != null && _rooms.length >= (_danchiInfo!.roomCountAll ?? 0)) {
      _hasMore = false;
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
                    expandedHeight: 200.0,
                    floating: false,
                    pinned: true,
                    automaticallyImplyLeading: false,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    flexibleSpace: LayoutBuilder(
                      builder: (context, constraints) {
                        final double delta = constraints.maxHeight - kToolbarHeight;
                        final bool collapsed = delta < 40; // 你可以根据实际高度微调
                        return FlexibleSpaceBar(
                          title: Text(
                            _danchiInfo!.name,
                            style: TextStyle(
                              fontSize: 16.0,
                              color: collapsed ? Colors.black : Colors.white,
                              shadows: collapsed
                                  ? []
                                  : [
                                      const Shadow(
                                        blurRadius: 4.0,
                                        color: Colors.black54,
                                        offset: Offset(1.0, 1.0),
                                      ),
                                    ],
                            ),
                          ),
                          titlePadding: EdgeInsets.only(
                            left: collapsed ? 56 : 16,
                            bottom: 16,
                          ),
                          collapseMode: CollapseMode.parallax,
                          background: (_danchiInfo!.image != null && _danchiInfo!.image!.isNotEmpty)
                              ? Image.network(
                                  _danchiInfo!.image!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.apartment, size: 100, color: Colors.grey),
                                )
                              : const Icon(Icons.apartment, size: 100, color: Colors.grey),
                        );
                      },
                    ),
                    backgroundColor: Colors.white,
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 地址
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2.0, right: 6.0),
                                child: Icon(Icons.location_on, color: Colors.green, size: 20),
                              ),
                              Expanded(
                                child: Text(
                                  _danchiInfo!.address ?? '',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 车站信息
                          if (_danchiInfo!.access != null && _danchiInfo!.access!.isNotEmpty)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2.0, right: 6.0),
                                  child: Icon(Icons.train, color: Colors.blue, size: 20),
                                ),
                                Expanded(child: Html(data: _danchiInfo!.access!)),
                              ],
                            ),
                          const SizedBox(height: 20),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              '可租房间数: ${_danchiInfo?.roomCountAll ?? _rooms.length}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _rooms.isEmpty && !_isLoading
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Column(
                              children: [
                                Image.asset('assets/images/empty_box.png', height: 150), // Placeholder image
                                const SizedBox(height: 20),
                                const Text('No rooms available at the moment.'),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index == _rooms.length) {
                                return _hasMore
                                    ? const Center(child: CircularProgressIndicator())
                                    : const Center(child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text('All rooms loaded.'),
                                    ));
                              }
                              final room = _rooms[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: ListTile(
                                  leading: (room.madori != null && room.madori!.isNotEmpty)
                                      ? Image.network(
                                          room.madori!,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => 
                                            (room.image != null && room.image!.isNotEmpty)
                                              ? Image.network(
                                                  room.image!,
                                                  width: 100,
                                                  height: 100,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                                                )
                                              : const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                                        )
                                      : (room.image != null && room.image!.isNotEmpty)
                                          ? Image.network(
                                              room.image!,
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                                            )
                                          : const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                                  title: Text(room.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('租金: ${room.rent}'),
                                      if (room.commonfee != null && room.commonfee!.isNotEmpty)
                                        Text('共益费: ${room.commonfee}'),
                                      Text('户型: ${room.type}'),
                                      Text('面积: ${room.floorspace.replaceAll('&#13217;', '㎡')}'),
                                      Text('楼层: ${room.floor}'),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () async {
                                    if (room.link != null && room.link!.isNotEmpty) {
                                      final url = Uri.parse(room.link!.startsWith('http')
                                          ? room.link!
                                          : 'https://chintai.r6.ur-net.go.jp${room.link}');
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(url);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Could not launch ${room.link}')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                            childCount: _rooms.length + (_hasMore ? 1 : 0),
                          ),
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
