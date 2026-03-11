import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final String type; 
  final String? link;
  final String? comment;

  InventoryItem({
    required this.name,
    required this.location,
    required this.type,
    this.link,
    this.comment,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<InventoryItem> _inventory = [];
  final _formKey = GlobalKey<FormState>();

  // Controllers for the input fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String _selectedType = "Reusable";

  // --- NEW FIGMA-STYLED INPUT SHEET ---
  void _showAddItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            bool isReusable = _selectedType == "Reusable";

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F2),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("cancel", 
                              style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                          ),
                          const Text("New Item", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 60), 
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Item Name & Image Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  hintText: "Item Name: Quantity", 
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(color: Colors.grey),
                                ),
                                validator: (value) => value == null || value.isEmpty ? "Enter name & qty" : null, // TODO: data validation when only name is entered
                              ),
                            ),
                            const Icon(Icons.add_photo_alternate_outlined, size: 45, color: Colors.black), // TODO: Make to actually add icon
                          ],
                        ),
                      ),
                      
                      _buildSectionLabel("Location"),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(border: InputBorder.none),
                          hint: const Text("Select Existing Locations"),
                          items: ["Kitchen", "Garage", "Office", "Bedroom"] // TODO: make this dynamic
                              .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                              .toList(),
                          onChanged: (val) => _locationController.text = val ?? "",
                          validator: (value) => value == null ? "Select a location" : null,
                        ),
                      ),

                      Row(
                        children: [
                          _buildSectionLabel("Reusable"),
                          const SizedBox(width: 8),
                          Checkbox(
                            value: isReusable,
                            onChanged: (val) {
                              setSheetState(() {
                                isReusable = val!;
                                _selectedType = isReusable ? "Reusable" : "Disposable";
                              });
                            },
                          ),
                        ],
                      ),

                      _buildSectionLabel("Link"),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                        child: Row(
                          children: [
                            const Icon(Icons.link, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _linkController,
                                decoration: const InputDecoration(hintText: "URL address of link", border: InputBorder.none),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                // 1. Get data from the system clipboard
                                  ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
                                  
                                  // 2. If there is text there, update the controller
                                  if (data != null && data.text != null) {
                                    setState(() {
                                      _linkController.text = data.text!;
                                    });
                                    
                                    // Optional: Show a quick toast/snackbar so the user knows it worked
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Link Pasted!"), duration: Duration(seconds: 1)),
                                    );
                                  }
                              }, // TODO: Future Paste Logic
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF333333),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text("Paste Link"),
                            ),
                          ],
                        ),
                      ),

                      _buildSectionLabel("Comment"),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                        child: TextField(
                          controller: _commentController,
                          maxLines: 4,
                          decoration: const InputDecoration(hintText: "Insert Comment", border: InputBorder.none),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Add Item Button
                      SizedBox(
                        width: 180,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF59A638),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _saveItem();
                            }
                          },
                          child: const Text("Add Item", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- ADD THIS METHOD BELOW _showAddItemSheet ---
  void _viewItemDetails(InventoryItem item, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFFF2F2F2), // Matching the Figma light grey
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Title and Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(item.name, 
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Image Placeholder (Grey box from Figma)
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.image_not_supported_outlined, size: 50, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Item Data Rows
              _buildDetailRow("Location", item.location, Icons.location_on_outlined),
              _buildDetailRow("Type", item.type, Icons.category_outlined),
              
              if (item.link != null && item.link!.isNotEmpty)
                _buildDetailRow("Link", item.link!, Icons.link),

              if (item.comment != null && item.comment!.isNotEmpty)
                _buildDetailRow("Comment", item.comment!, Icons.notes),
              
              const Spacer(),
              
              // Delete Action
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _inventory.removeAt(index));
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text("Remove from Inventory", style: TextStyle(color: Colors.red, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper function for the rows (place this right under _viewItemDetails)
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF59A638), size: 22), // Using the green from your Figma
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _saveItem() {
    setState(() {
      _inventory.add(InventoryItem(
        name: _nameController.text,
        location: _locationController.text,
        type: _selectedType,
        link: _linkController.text,
        comment: _commentController.text,
      ));
    });
    _nameController.clear();
    _locationController.clear();
    _linkController.clear();
    _commentController.clear();
    _selectedType = "Reusable";
    Navigator.pop(context);
  }

  Widget _buildSectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  // --- STAT BOXES AND GRID REMAIN SIMILAR ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
              child: _inventory.isEmpty 
                ? const Center(child: Text("No items yet. Tap + to add!"))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.4,
                    ),
                    itemCount: _inventory.length,
                    itemBuilder: (context, index) {
                      final item = _inventory[index];
                      return InkWell( // <--- 1. Wrap with InkWell to make it clickable
                        onTap: () => _viewItemDetails(item, index), // <--- 2. Call the pop-up function
                        borderRadius: BorderRadius.circular(15),
                        child: Card(
                          elevation: 0,
                          color: item.type == "Disposable" ? Colors.green.shade50 : Colors.purple.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                Text(item.location, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                  child: Text(item.type, style: const TextStyle(fontSize: 10)),
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemSheet,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
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