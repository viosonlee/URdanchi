import 'package:flutter/material.dart';
import '../models/danchi.dart';
import '../l10n/app_localizations.dart';
import '../widgets/room_list_item.dart';

class NewRoomsScreen extends StatelessWidget {
  final Map<String, List<Room>> newRoomsMap;
  final Map<String, DanchiInfo> danchiInfoMap;

  const NewRoomsScreen({super.key, required this.newRoomsMap, required this.danchiInfoMap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.newRooms),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: newRoomsMap.length,
        itemBuilder: (context, index) {
          final danchiId = newRoomsMap.keys.elementAt(index);
          final newRooms = newRoomsMap[danchiId]!;
          final danchiInfo = danchiInfoMap[danchiId];

          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Danchi header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.apartment,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              danchiInfo?.name ?? danchiId,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppLocalizations.of(context)!.newRoomsCount}: ${newRooms.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade600,
                        ),
                      ),
                      if (danchiInfo?.address != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.grey.shade600,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                danchiInfo!.address!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // New rooms list
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: newRooms.length,
                  itemBuilder: (context, roomIndex) {
                    final room = newRooms[roomIndex];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: RoomListItem(
                        room: room,
                        isNewRoom: true,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}