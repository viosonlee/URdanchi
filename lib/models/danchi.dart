class DanchiMarker {
  final String id;
  final double lat;
  final double lng;
  final int roomCount;

  DanchiMarker({
    required this.id,
    required this.lat,
    required this.lng,
    required this.roomCount,
  });

  factory DanchiMarker.fromJson(Map<String, dynamic> json) {
    return DanchiMarker(
      id: json['id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      roomCount: json['roomCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': lat,
      'lng': lng,
      'roomCount': roomCount,
    };
  }
}

class Room {
  final String id;
  final String name;
  final String? madori; // 户型图url
  final String rent;
  final String? commonfee;
  final String type;
  final String floorspace;
  final String floor;
  final String? image; // 房间图片
  final String? link;  // PC端详情页链接
  final String? linkSp; // 手机端详情页链接

  Room({
    required this.id,
    required this.name,
    this.madori,
    required this.rent,
    this.commonfee,
    required this.type,
    required this.floorspace,
    required this.floor,
    this.image,
    this.link,
    this.linkSp,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      madori: json['madori'] as String?,
      rent: json['rent'] as String,
      commonfee: json['commonfee'] as String?,
      type: json['type'] as String,
      floorspace: json['floorspace'] as String,
      floor: json['floor'] as String,
      image: json['image'] as String?,
      link: json['urlDetail'] as String? ?? json['link'] as String?,
      linkSp: json['link_sp'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'madori': madori,
      'rent': rent,
      'commonfee': commonfee,
      'type': type,
      'floorspace': floorspace,
      'floor': floor,
      'image': image,
      'link': link,
      'link_sp': linkSp,
    };
  }
}

class DanchiInfo {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String? link;
  final String? linkSp;
  final String? image;
  final String? access;
  final String? address;
  final String? rent;
  final String? type;
  final String? deposit;
  final String? requirement;
  final int? roomCountAll;
  final List<Room> rooms;

  DanchiInfo({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.link,
    this.linkSp,
    this.image,
    this.access,
    this.address,
    this.rent,
    this.type,
    this.deposit,
    this.requirement,
    this.roomCountAll,
    required this.rooms,
  });

  factory DanchiInfo.fromJson(Map<String, dynamic> json) {
    var roomsJson = json['room'] as List<dynamic>? ?? [];
    return DanchiInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      link: json['link'] as String?,
      linkSp: json['link_sp'] as String?,
      image: json['image'] as String?,
      access: json['access'] as String?,
      address: json['address'] as String?,
      rent: json['rent'] as String?,
      type: json['type'] as String?,
      deposit: json['deposit'] as String?,
      requirement: json['requirement'] as String?,
      roomCountAll: json['roomCountAll'] as int?,
      rooms: roomsJson.map((e) => Room.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'link': link,
      'link_sp': linkSp,
      'image': image,
      'access': access,
      'address': address,
      'rent': rent,
      'type': type,
      'deposit': deposit,
      'requirement': requirement,
      'roomCountAll': roomCountAll,
      'room': rooms.map((room) => room.toJson()).toList(),
    };
  }
}
