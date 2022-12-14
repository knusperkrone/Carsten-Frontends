part of 'dto.dart';

typedef GetterFun = int Function(SpotifyImage);

@JsonSerializable()
class SpotifyPlaylist extends Dto implements SpotifyFeatured {
  final String id;
  @override
  final String name;
  @JsonKey(name: 'snapshot_id')
  final String snapshotId;
  final List<SpotifyImage>? images;
  final SpotifyUser owner;

  SpotifyPlaylist(this.id, this.name, this.snapshotId, this.images, this.owner);

  factory SpotifyPlaylist.fromJson(Map<String, dynamic> json) =>
      _$SpotifyPlaylistFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$SpotifyPlaylistToJson(this);

  @override
  String get imageUrl {
    SpotifyImage? selected;
    if (images?.isNotEmpty ?? false) {
      selected = images!.first;
    }
    return selected?.url ?? '';
  }

  @override
  bool operator ==(dynamic other) {
    if (other is SpotifyPlaylist) {
      return other.id == id;
    }
    return false;
  }

  @override
  int get hashCode => id.hashCode;
}
