import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/danchi.dart';
import 'api_service.dart';
import 'danchi_cache_service.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final ApiService _apiService = ApiService();
  final DanchiCacheService _cacheService = DanchiCacheService();

  static const String _subscriptionsKey = 'subscribed_danchi_list';
  static const String _lastCheckKey = 'last_subscription_check';
  static const String _roomHistoryPrefix = 'room_history_';

  /// Get all subscribed danchi IDs
  Future<List<String>> getSubscribedDanchiIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subscriptionsJson = prefs.getString(_subscriptionsKey);
      
      if (subscriptionsJson == null) return [];
      
      final List<dynamic> subscriptionsList = jsonDecode(subscriptionsJson);
      return subscriptionsList.cast<String>();
    } catch (e) {
      debugPrint('获取订阅团地ID错误: $e');
      return [];
    }
  }

  /// Subscribe to a danchi
  Future<bool> subscribeToDanchi(String danchiId) async {
    try {
      final currentSubscriptions = await getSubscribedDanchiIds();
      
      if (!currentSubscriptions.contains(danchiId)) {
        currentSubscriptions.add(danchiId);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_subscriptionsKey, jsonEncode(currentSubscriptions));
        
        // Load and cache initial room data AND save to room history
        await _loadAndCacheInitialRoomData(danchiId);
        
        return true;
      }
      
      return false; // Already subscribed
    } catch (e) {
      debugPrint('订阅团地错误: $e');
      return false;
    }
  }

  /// Unsubscribe from a danchi
  Future<bool> unsubscribeFromDanchi(String danchiId) async {
    try {
      final currentSubscriptions = await getSubscribedDanchiIds();
      
      if (currentSubscriptions.contains(danchiId)) {
        currentSubscriptions.remove(danchiId);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_subscriptionsKey, jsonEncode(currentSubscriptions));
        
        // Clear room history for this danchi
        await prefs.remove('$_roomHistoryPrefix$danchiId');
        
        return true;
      }
      
      return false; // Not subscribed
    } catch (e) {
      debugPrint('取消订阅团地错误: $e');
      return false;
    }
  }

  /// Check if a danchi is subscribed
  Future<bool> isSubscribed(String danchiId) async {
    final subscriptions = await getSubscribedDanchiIds();
    return subscriptions.contains(danchiId);
  }

  /// Load and cache initial room data for a danchi when subscribing
  Future<void> _loadAndCacheInitialRoomData(String danchiId) async {
    try {
      // Get ALL rooms for initial caching (all pages)
      final rooms = await _getAllRoomsForDanchi(danchiId);
      await _cacheService.cacheRoomList(danchiId, rooms);
      
      // Save room IDs to persistent history for new room detection
      await _saveRoomHistory(danchiId, rooms);
    } catch (e) {
      debugPrint('加载团地房间数据错误 $danchiId: $e');
    }
  }

  /// Save room history to persistent storage
  Future<void> _saveRoomHistory(String danchiId, List<Room> rooms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roomIds = rooms.map((room) => room.id).toList();
      await prefs.setString('$_roomHistoryPrefix$danchiId', jsonEncode(roomIds));
    } catch (e) {
      debugPrint('保存房间历史错误 $danchiId: $e');
    }
  }

  /// Get room history from persistent storage
  Future<Set<String>> _getRoomHistory(String danchiId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('$_roomHistoryPrefix$danchiId');
      
      if (historyJson != null) {
        final List<dynamic> roomIds = jsonDecode(historyJson);
        return roomIds.cast<String>().toSet();
      }
    } catch (e) {
      debugPrint('获取房间历史错误 $danchiId: $e');
    }
    
    return <String>{};
  }

  /// Check for new rooms in subscribed danchi
  Future<Map<String, List<Room>>> checkForNewRooms() async {
    final newRoomsMap = <String, List<Room>>{};
    
    try {
      final subscribedIds = await getSubscribedDanchiIds();
      
      for (final danchiId in subscribedIds) {
        final newRooms = await _checkDanchiForNewRooms(danchiId);
        if (newRooms.isNotEmpty) {
          newRoomsMap[danchiId] = newRooms;
        }
      }
      
      // Update last check timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
      
    } catch (e) {
      debugPrint('检查新房间错误: $e');
    }
    
    return newRoomsMap;
  }

  /// Check a specific danchi for new rooms
  Future<List<Room>> _checkDanchiForNewRooms(String danchiId) async {
    try {
      // Get historical room IDs from persistent storage (not cache)
      final historicalRoomIds = await _getRoomHistory(danchiId);
      
      // If no history exists, this might be the first time checking
      // In this case, don't treat all rooms as new
      if (historicalRoomIds.isEmpty) {
        debugPrint('No room history found for $danchiId, initializing...');
        final currentRooms = await _getAllRoomsForDanchi(danchiId);
        await _saveRoomHistory(danchiId, currentRooms);
        await _cacheService.cacheRoomList(danchiId, currentRooms);
        return []; // No new rooms on first initialization
      }
      
      // Get ALL current rooms from API (all pages)
      final currentRooms = await _getAllRoomsForDanchi(danchiId);
      
      // Find new rooms by comparing with historical data
      final newRooms = currentRooms.where((room) => !historicalRoomIds.contains(room.id)).toList();
      
      // Update both cache and history with current data
      await _cacheService.cacheRoomList(danchiId, currentRooms);
      await _saveRoomHistory(danchiId, currentRooms);
      
      return newRooms;
    } catch (e) {
      debugPrint('检查团地新房间错误 $danchiId: $e');
      return [];
    }
  }

  /// Get all rooms for a danchi (all pages)
  Future<List<Room>> _getAllRoomsForDanchi(String danchiId) async {
    final allRooms = <Room>[];
    String? lastId;
    bool hasMore = true;
    
    while (hasMore) {
      try {
        final rooms = await _apiService.getRoomList(danchiId, lastId: lastId);
        
        if (rooms.isEmpty) {
          hasMore = false;
        } else {
          allRooms.addAll(rooms);
          lastId = rooms.last.id;
          
          // If we got less than expected, probably no more pages
          // This is a reasonable assumption since API usually returns consistent page sizes
          if (rooms.length < 20) { // Assume typical page size is around 20
            hasMore = false;
          }
        }
      } catch (e) {
        debugPrint('获取团地房间页面错误 $danchiId: $e');
        hasMore = false;
      }
    }
    
    return allRooms;
  }

  /// Get detailed info for subscribed danchi with new rooms
  Future<Map<String, DanchiInfo>> getSubscribedDanchiInfo(List<String> danchiIds) async {
    final danchiInfoMap = <String, DanchiInfo>{};
    
    for (final danchiId in danchiIds) {
      try {
        // Try cache first
        var danchiInfo = await _cacheService.getCachedDanchiInfo(danchiId);
        
        if (danchiInfo == null) {
          // Load from API and cache
          danchiInfo = await _apiService.getDanchiInfo(danchiId);
          await _cacheService.cacheDanchiInfo(danchiId, danchiInfo);
        }
        
        danchiInfoMap[danchiId] = danchiInfo;
      } catch (e) {
        debugPrint('获取团地信息错误 $danchiId: $e');
      }
    }
    
    return danchiInfoMap;
  }

  /// Get last check timestamp
  Future<DateTime?> getLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastCheckKey);
      
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('获取上次检查时间错误: $e');
    }
    
    return null;
  }

  /// Clear all subscriptions
  Future<void> clearAllSubscriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subscribedIds = await getSubscribedDanchiIds();
      
      // Clear room history for all subscribed danchi
      for (final danchiId in subscribedIds) {
        await prefs.remove('$_roomHistoryPrefix$danchiId');
      }
      
      await prefs.remove(_subscriptionsKey);
      await prefs.remove(_lastCheckKey);
    } catch (e) {
      debugPrint('清除所有订阅错误: $e');
    }
  }
}