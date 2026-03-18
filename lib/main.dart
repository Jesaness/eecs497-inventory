import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

// --- NEW COLOR PALETTE ---
const Color cPrimary = Color(0xFF00A878);   // Midnight Green
const Color cSecondary = Color(0xFFD8F1A0); // Mindaro (Light Lime)
const Color cAccent = Color(0xFFF3C178);    // Sunset (Yellow/Orange)
const Color cHighlight = Color(0xFFFE5E41); // Flame (Red/Orange)
const Color cBackground = Color(0xFFF8F9FA);

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
        useMaterial3: true,
        fontFamily: 'Georgia', // Soft, humanistic serif font
        colorScheme: ColorScheme.fromSeed(seedColor: cPrimary),
        scaffoldBackgroundColor: cBackground,
      ),
      home: const HomePage(),
    );
  }
}

/// A small reusable checkbox that can show a status message inline when enabled.
class ReusableCheckbox extends StatelessWidget {
  const ReusableCheckbox({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.enabledMessage,
  });

  final bool value;
  final String label;
  final ValueChanged<bool?> onChanged;
  final String? enabledMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
        ),
        Text(label),
        if (value && enabledMessage != null) ...[
          const SizedBox(width: 8),
          Text(enabledMessage!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ],
    );
  }
}

// --- NEW BORROWER MODEL ---
class Borrower {
  final String name;
  final String phone;
  final String? email;
  Borrower({required this.name, required this.phone, this.email});
}

class InventoryItem {
  final String name;
  final String location;
  final String type;
  final Uint8List? imageBytes; // Store image as bytes for Web compatibility
  final String? link;
  final String? comment;
  final String? quantity;
  final String? imagePath;
  Borrower? borrower; 

  InventoryItem({
    required this.name,
    required this.location,
    required this.type,
    this.imageBytes,
    this.link,
    this.comment,
    this.quantity,
    this.imagePath,
    this.borrower, 
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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  String _selectedType = "Reusable";
  Uint8List? _webImage;

  // Add locations tracking
  final Set<String> _locations = {}; // Default locations
  String? _selectedLocation;

  final _bName = TextEditingController();
  final _bPhone = TextEditingController();
  final _bEmail = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncLocationsFromInventory();
  }

  void _syncLocationsFromInventory() {
    for (final item in _inventory) {
      _locations.add(item.location);
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, color: cPrimary, size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Borrower Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _bName, decoration: const InputDecoration(hintText: "Name (Required)")),
            TextField(controller: _bPhone, decoration: const InputDecoration(hintText: "Phone (Required)")),
            TextField(controller: _bEmail, decoration: const InputDecoration(hintText: "Email (Optional)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (_bName.text.isNotEmpty && _bPhone.text.isNotEmpty) {
                setState(() {
                  item.borrower = Borrower(name: _bName.text, phone: _bPhone.text, email: _bEmail.text);
                });
                _bName.clear(); _bPhone.clear(); _bEmail.clear();
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close sheet
              }
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  // ImagePicker function that works for both Web and Mobile
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(void Function(void Function()) setSheetState) async {
    try {
      // 1. Open the gallery/file picker
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000, // Optional: Resize to save memory
        imageQuality: 85, // Optional: Compress slightly
      );

      if (pickedFile != null) {
        // 2. Read the file as bytes (Universal for Web/iOS/Android)
        final Uint8List imageBytes = await pickedFile.readAsBytes();

        // 3. Update the BottomSheet's state
        setSheetState(() {
          _webImage = imageBytes;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _showAddLocationDialog(void Function(void Function()) setSheetState) {
    final TextEditingController newLocationController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Location"),
        content: TextField(
          controller: newLocationController,
          decoration: const InputDecoration(hintText: "Enter location name"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final newLocation = newLocationController.text.trim();
              if (newLocation.isNotEmpty && !_locations.contains(newLocation)) {
                setSheetState(() {
                  _locations.add(newLocation);
                  _selectedLocation = newLocation;
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _viewItemDetails(InventoryItem item, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(item.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 20),
            // Info Rows
            _buildInfoRow(Icons.location_on_outlined, "Location", item.location),
            _buildInfoRow(Icons.category_outlined, "Type", "${item.type} ${item.quantity ?? ''}"),
            
            const Divider(height: 40),

            // --- BORROWER SECTION ---
            if (item.borrower != null) ...[
              Text("Currently with ${item.borrower!.name}", style: const TextStyle(color: cHighlight, fontWeight: FontWeight.bold, fontSize: 18)),
              Text("Phone: ${item.borrower!.phone}", style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              _btn("Return Item", cPrimary, () {
                setState(() => item.borrower = null);
                Navigator.pop(context);
              }),
            ] else ...[
              _btn("Check Out Item", cAccent, () => _showCheckoutDialog(item)),
            ],

            const Spacer(),
            Center(
              child: TextButton(
                onPressed: () { setState(() => _inventory.removeAt(index)); Navigator.pop(context); },
                child: const Text("Delete from Inventory", style: TextStyle(color: Colors.red)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Small helper for the buttons
  Widget _btn(String label, Color col, VoidCallback tap) => SizedBox(
    width: double.infinity, height: 55,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: col, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      onPressed: tap, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );

  // --- STAT BOX COMPONENT ---
  Widget _buildStatBox(String title, String value, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // --- THE ADD ITEM SHEET ---
  void _showAddItemSheet() {
    // Reset form state
    _selectedLocation = null;
    XFile? pickedImage;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              padding: EdgeInsets.only(
                top: 20, left: 24, right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with Grey X Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 30),
                          ),
                          const Text("Add New Item", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _buildSectionLabel("Item Name *"),
                      _buildTextField(_nameController, "e.g. Hiking Boots"),

                      _buildSectionLabel("Location *"),
                      _buildLocationDropdown(setSheetState),

                      _buildSectionLabel("Quantity *"),
                      _buildTextField(_qtyController, "Qty", isNum: true),

                      // Type & Quantity in one Row
                      _buildSectionLabel("Type *"),
                      Row(
                        children: [
                          ReusableCheckbox(
                            value: _selectedType == "Reusable",
                            label: "Reusable",
                            onChanged: (val) {
                              setSheetState(() {
                                _selectedType = (val ?? false) ? "Reusable" : "Disposable";
                              });
                            },
                            enabledMessage: "(borrowing system enabled for this item)",
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),

                      // Image Picker
                      _buildSectionLabel("Item Image"),
                      InkWell(
                        onTap: () => _pickImage(setSheetState), // Call the function here
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            color: cBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                          ),
                          child: _webImage == null 
                              ? const Icon(Icons.add_a_photo_outlined, color: cPrimary, size: 32)
                              : Stack(
                                  children: [
                                    // Display the actual image
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.memory(
                                        _webImage!, 
                                        width: double.infinity, 
                                        height: 120, 
                                        fit: BoxFit.cover
                                      ),
                                    ),
                                    // Optional: Add a small "Change" badge
                                    Positioned(
                                      right: 8, bottom: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        child: const Icon(Icons.edit, color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      _buildSectionLabel("Link & Comments"),
                      _buildTextField(_linkController, "URL Link (Optional)"),
                      const SizedBox(height: 12),
                      _buildTextField(_commentController, "Notes...", maxLines: 3),

                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () { 
                            if (_formKey.currentState!.validate()){
                              _saveItem(setSheetState); 
                            } 
                          },
                          child: const Text("Add to Inventory", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
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

  void _saveItem(void Function(void Function()) setSheetState) {
    // 1. Validation check (Double-check that a location is picked)
      // Name
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter an item name.")));
      return;
    }
      // Location
    if (_selectedLocation != null) {
      setState(() {
        _inventory.add(InventoryItem(
          name: _nameController.text,
          location: _selectedLocation!,
          type: _selectedType,
          imageBytes: _webImage, // Store the bytes we captured in _pickImage
          quantity: _selectedType == "Disposable" ? _qtyController.text : null,
          link: _linkController.text,
          comment: _commentController.text,
        ));
      });

      // 2. Clear all controllers for the next entry
      _nameController.clear();
      _qtyController.clear();
      _linkController.clear();
      _commentController.clear();
      
      // 3. Reset the selection and the image preview
      setSheetState(() {
        _selectedLocation = null;
        _webImage = null; // Important: Clear the preview so the next item starts blank
      });

      // 4. Close the Bottom Sheet
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Inventory", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
        backgroundColor: cBackground,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatBox("Total Items", _inventory.length.toString(), cPrimary, Colors.white),
                const SizedBox(width: 16),
                _buildStatBox("Checked Out", _inventory.where((i) => i.borrower != null).length.toString(), cSecondary, cPrimary),
              ],
            ),
            const SizedBox(height: 32),
            const Text("Current Stock", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: _inventory.isEmpty
                  ? const Center(child: Text("Empty. Let's add something!"))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _inventory.length,
                      itemBuilder: (context, index) {
                        final item = _inventory[index];
                        // CHECK: Is the item currently borrowed?
                        final bool isBorrowed = item.borrower != null;

                        return InkWell(
                          // ACTION: Open the details popup created in Step 2
                          onTap: () => _viewItemDetails(item, index),
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              // CHANGE: Add a Sunset Orange border if checked out
                              border: isBorrowed ? Border.all(color: cAccent, width: 2) : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04), 
                                  blurRadius: 10, 
                                  offset: const Offset(0, 4)
                                )
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: cBackground, 
                                      borderRadius: BorderRadius.circular(15)
                                    ),
                                    // CHANGE: Show item image if available, otherwise fall back to icon
                                    child: item.imageBytes != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(15),
                                            child: Image.memory(item.imageBytes!, fit: BoxFit.cover),
                                          )
                                        : Icon(
                                            isBorrowed ? Icons.outbox_rounded : Icons.inventory_2_outlined,
                                            color: isBorrowed ? cAccent : cPrimary.withOpacity(0.4),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.name, 
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), 
                                  maxLines: 1
                                ),
                                // CHANGE: Display borrower name instead of location if out
                                Text(
                                  isBorrowed ? "With: ${item.borrower!.name}" : item.location, 
                                  style: TextStyle(
                                    fontSize: 14, 
                                    color: isBorrowed ? cHighlight : Colors.grey.shade600,
                                    fontWeight: isBorrowed ? FontWeight.bold : FontWeight.normal,
                                  )
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    // CHANGE: Use Flame/Accent color for "Checked Out" badge
                                    color: isBorrowed 
                                        ? cAccent.withOpacity(0.2) 
                                        : (item.type == "Disposable" ? Colors.orange.withOpacity(0.1) : cSecondary.withOpacity(0.4)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isBorrowed ? "Checked Out" : (item.type == "Disposable" ? "Qty: ${item.quantity}" : "Reusable"),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                )
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
      floatingActionButton: FloatingActionButton.large(
        onPressed: _showAddItemSheet,
        backgroundColor: cHighlight,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded, size: 40),
      ),
    );
  }

  // --- REUSABLE COMPONENTS ---
  Widget _buildSectionLabel(String text) {
    return Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 20, bottom: 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))));
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, {bool isNum = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      inputFormatters: isNum ? [FilteringTextInputFormatter.digitsOnly] : [],
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: cBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildLocationDropdown(void Function(void Function()) setSheetState) {
    final List<String> dropdownItems = [..._locations, "Add New Location"];

    return DropdownButtonFormField<String>(
      value: _locations.contains(_selectedLocation) ? _selectedLocation : null, 
      hint: const Text("Select or add location"),
      decoration: InputDecoration(
        filled: true,
        fillColor: cBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
      items: dropdownItems.map((location) {
        return DropdownMenuItem<String>(
          value: location,
          child: Text(
            location,
            style: TextStyle(
              color: location == "Add New Location" ? cPrimary : Colors.black,
              fontWeight: location == "Add New Location" ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == "Add New Location") {
          _showAddLocationDialog(setSheetState);
        } else {
          setSheetState(() {
            _selectedLocation = value;
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a location';
        }
        return null;
      },
    );
  }
}