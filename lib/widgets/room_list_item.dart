
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/danchi.dart';
import '../l10n/app_localizations.dart';
import 'image_viewer.dart';

class RoomListItem extends StatelessWidget {
  final Room room;
  final bool isNewRoom;

  const RoomListItem({
    super.key,
    required this.room,
    this.isNewRoom = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 新房间标识
            if (isNewRoom)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppLocalizations.of(context)!.newRoom,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            
            // 房间头部区域
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 房间图片区域 - 显示房间图片、间取り图或占位符
                GestureDetector(
                  onTap: () {
                    // 确定要显示哪张图片
                    if (room.image != null && room.image!.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageViewer(
                            imageUrl: room.image!,
                            heroTag: 'room_image_${room.id}',
                          ),
                        ),
                      );
                    } else if (room.madori != null && room.madori!.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageViewer(
                            imageUrl: room.madori!,
                            heroTag: 'room_madori_${room.id}',
                          ),
                        ),
                      );
                    }
                    // 如果没有可用图片，则不执行任何操作（不导航）
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      color: Colors.grey.shade100,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImageContent(),
                    ),
                  ),
                ),
                
                // 房间详细信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        icon: Icons.attach_money,
                        label: AppLocalizations.of(context)!.rent,
                        value: room.rent,
                        color: Colors.green,
                      ),
                      if (room.commonfee != null && room.commonfee!.isNotEmpty)
                        _buildInfoRow(
                          icon: Icons.receipt,
                          label: AppLocalizations.of(context)!.commonFee(''),
                          value: room.commonfee!,
                          color: Colors.blue,
                        ),
                      _buildInfoRow(
                        icon: Icons.home,
                        label: AppLocalizations.of(context)!.type,
                        value: room.type,
                        color: Colors.grey,
                      ),
                      _buildInfoRow(
                        icon: Icons.square_foot,
                        label: AppLocalizations.of(context)!.area,
                        value: room.floorspace.replaceAll('&#13217;', '㎡'),
                        color: Colors.orange,
                      ),
                      _buildInfoRow(
                        icon: Icons.layers,
                        label: AppLocalizations.of(context)!.floor,
                        value: room.floor,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // 操作按钮 - 仅显示详细链接按钮
            const SizedBox(height: 12),
            if (room.link != null && room.link!.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openDetailLink(context, room.link!),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(AppLocalizations.of(context)!.viewDetails),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetailLink(BuildContext context, String url) async {
    try {
      // 处理相对URL，添加基础URL
      String fullUrl = url;
      if (!url.startsWith('http')) {
        fullUrl = 'https://www.ur-net.go.jp$url';
      }
      
      
      final uri = Uri.parse(fullUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        _showErrorMessage(context, AppLocalizations.of(context)!.cannotOpenUrl);
      }
    } catch (e) {
      if (!context.mounted) return;
      _showErrorMessage(context, AppLocalizations.of(context)!.linkOpenError);
    }
  }
  
  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildImageContent() {
    // 优先级：房间图片 > 间取り图 > 占位符
    if (room.image != null && room.image!.isNotEmpty) {
      return Image.network(
        room.image!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // 如果房间图片加载失败，尝试显示间取り图
          if (room.madori != null && room.madori!.isNotEmpty) {
            return Image.network(
              room.madori!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholder();
              },
            );
          }
          return _buildPlaceholder();
        },
      );
    } else if (room.madori != null && room.madori!.isNotEmpty) {
      return Image.network(
        room.madori!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
      );
    }
    
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(
        Icons.home,
        color: Colors.grey,
        size: 24,
      ),
    );
  }
}