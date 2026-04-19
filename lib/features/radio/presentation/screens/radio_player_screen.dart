
import 'package:flutter/material.dart';
import '../../data/radio_stations.dart';
import '../widgets/radio_player_widget.dart';

class RadioPlayerScreen extends StatelessWidget {
  final RadioStation station;
  const RadioPlayerScreen({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(station.name)),
      body: Center(child: RadioPlayerWidget(station: station)),
    );
  }
}
