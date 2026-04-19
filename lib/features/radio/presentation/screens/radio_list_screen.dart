
import 'package:flutter/material.dart';
import '../../data/radio_stations.dart';
import 'radio_player_screen.dart';

class RadioListScreen extends StatelessWidget {
  const RadioListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Canlı Radyo')),
      body: ListView.builder(
        itemCount: radioStations.length,
        itemBuilder: (context, index) {
          final station = radioStations[index];
          return ListTile(
            leading: const Icon(Icons.radio),
            title: Text(station.name),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RadioPlayerScreen(station: station),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
