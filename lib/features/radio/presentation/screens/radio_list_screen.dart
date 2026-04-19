
import 'package:flutter/material.dart';
import '../../data/radio_stations.dart';
import 'radio_player_screen.dart';

class RadioListScreen extends StatefulWidget {
  const RadioListScreen({super.key});

  @override
  State<RadioListScreen> createState() => _RadioListScreenState();
}

class _RadioListScreenState extends State<RadioListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<RadioStation> _filteredStations = radioStations;

  void _filterStations(String query) {
    setState(() {
      _filteredStations = radioStations
          .where((station) =>
              station.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canlı Radyo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterStations,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Kanal Ara...',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: _filteredStations.length,
        itemBuilder: (context, index) {
          final station = _filteredStations[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              child: const Icon(Icons.radio, color: Colors.blueAccent),
            ),
            title: Text(station.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white24),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RadioPlayerScreen(
                    initialIndex: radioStations.indexOf(station),
                    stations: radioStations,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
