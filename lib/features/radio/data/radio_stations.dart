
class RadioStation {
  final String id;
  final String name;
  final String url;

  RadioStation({required this.id, required this.name, required this.url});
}

final List<RadioStation> radioStations = [
  RadioStation(id: "KralPop", name: "Kral Pop", url: "https://moondigitaledge.radyotvonline.net/kralpop/playlist.m3u8"),
  RadioStation(id: "KralFM", name: "Kral FM", url: "https://moondigitaledge.radyotvonline.net/kralfm/playlist.m3u8"),
  RadioStation(id: "PowerTurk", name: "PowerTürk", url: "https://listen.powerapp.com.tr/powerturk/mpeg/icecast.audio"),
  RadioStation(id: "PowerFM", name: "Power FM", url: "http://powerfm.listenpowerapp.com/powerfm/mpeg/icecast.audio"),
  RadioStation(id: "TRTFM", name: "TRT FM", url: "http://trtcanlifm-lh.akamaihd.net/i/TRTFM_1@417056/master.m3u8"),
  RadioStation(id: "AlemFM", name: "Alem FM", url: "http://turkmedya.radyotvonline.net/turkmedya/alemfm.stream/playlist.m3u8"),
  RadioStation(id: "RadyoFenomen", name: "Radyo Fenomen", url: "https://listen.radyofenomen.com/fenomen/128/icecast.audio"),
  RadioStation(id: "FenomenTurk", name: "Fenomen Türk", url: "https://listen.radyofenomen.com/fenomenturk/128/icecast.audio"),
  RadioStation(id: "VirginRadio", name: "Virgin Radio Türkiye", url: "https://listen.radyofenomen.com/virginradioturkiye/128/icecast.audio"),
  RadioStation(id: "ShowRadyo", name: "Show Radyo", url: "http://46.20.3.201/"),
  RadioStation(id: "BestFM", name: "Best FM", url: "http://46.20.7.126/"),
  RadioStation(id: "NTVRadyo", name: "NTV Radyo", url: "http://ntv.radyotvonline.net/ntvradyo/ntvradyo.stream/playlist.m3u8"),
  RadioStation(id: "HaberturkRadyo", name: "Habertürk Radyo", url: "http://haberturkradyo.radyotvonline.net/haberturkradyo/haberturkradyo.stream/playlist.m3u8"),
  RadioStation(id: "KafaRadyo", name: "Kafa Radyo", url: "http://yayin.kafaradyo.com:8020/"),
];
