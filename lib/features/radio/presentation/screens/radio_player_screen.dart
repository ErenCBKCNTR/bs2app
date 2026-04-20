
import 'package:flutter/material.dart';
import '../../data/radio_stations.dart';
import '../widgets/radio_player_widget.dart';

class RadioPlayerScreen extends StatefulWidget {
  final int initialIndex;
  final List<RadioStation> stations;
  const RadioPlayerScreen({super.key, required this.initialIndex, required this.stations});

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _nextStation() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.stations.length;
    });
  }

  void _previousStation() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + widget.stations.length) % widget.stations.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final station = widget.stations[_currentIndex];
    return Scaffold(
      appBar: AppBar(title: Text(station.name)),
      body: SafeArea(
        child: RadioPlayerWidget(
          station: station,
          onNext: _nextStation,
          onPrevious: _previousStation,
        ),
      ),
    );
  }
}
