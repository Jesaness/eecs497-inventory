import 'package:flutter/material.dart';

void main() {
  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// Model to hold item data
class InventoryItem {
  final String name;
  final String location;
  final String type; // "Disposable" or "Reusable"
  final int? quantity;

  InventoryItem({
    required this.name,
    required this.location,
    required this.type,
    this.quantity,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<InventoryItem> _inventory = [];

  // Controllers for the input fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  String _selectedType = "Reusable";

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Allows UI inside dialog to update (like the dropdown)
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Add New Item"),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Item Name")),
                    TextField(controller: _locationController, decoration: const InputDecoration(labelText: "Location")),
                    const SizedBox(height: 15),
                    DropdownButton<String>(
                      value: _selectedType,
                      isExpanded: true,
                      items: ["Reusable", "Disposable"].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (newValue) {
                        setDialogState(() => _selectedType = newValue!);
                      },
                    ),
                    if (_selectedType == "Disposable")
                      TextField(
                        controller: _qtyController,
                        decoration: const InputDecoration(labelText: "Quantity"),
                        keyboardType: TextInputType.number,
                      ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _inventory.add(InventoryItem(
                        name: _nameController.text,
                        location: _locationController.text,
                        type: _selectedType,
                        quantity: _selectedType == "Disposable" ? int.tryParse(_qtyController.text) : null,
                      ));
                    });
                    // Clear controllers and close
                    _nameController.clear();
                    _locationController.clear();
                    _qtyController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text("Save Item"),
                ),
              ],
            );
          },
        );
      },
    );
  }

void _viewItemDetails(InventoryItem item, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.close), 
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(Icons.location_on, "Location: ${item.location}"),
            _detailRow(Icons.category, "Type: ${item.type}"),
            if (item.type == "Disposable") 
              _detailRow(Icons.layers, "Quantity: ${item.quantity ?? 0}"),
            const SizedBox(height: 20),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
            ),
          ],
        ),
        actions: [
          // --- DELETE BUTTON ---
          TextButton.icon(
            onPressed: () {
              setState(() {
                _inventory.removeAt(index);
              });
              Navigator.pop(context); // Close the popup
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Item deleted"), duration: Duration(seconds: 2)),
              );
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text("Delete Item", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Helper for clean detail rows
  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Tracker'), backgroundColor: Colors.indigo.shade50),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                _buildStatBox("Total Items", _inventory.length.toString(), Colors.blue.shade100),
                const SizedBox(width: 16),
                _buildStatBox("Checked Out", "0", Colors.orange.shade100),
              ],
            ),
            const SizedBox(height: 24),
            const Align(alignment: Alignment.centerLeft, child: Text("Current Inventory", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.5,
                ),
                itemCount: _inventory.length,
                itemBuilder: (context, index) {
                  final item = _inventory[index];
                  return InkWell(
                    onTap: () => _viewItemDetails(item, index),
                    child: Card(
                      color: item.type == "Disposable" ? Colors.green.shade50 : Colors.purple.shade50,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(item.location, style: const TextStyle(fontSize: 12)),
                          Chip(label: Text(item.type, style: const TextStyle(fontSize: 10))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatBox(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 14)),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}