import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final String? link;
  final String? comment;
  final String? quantity;
  Borrower? borrower; 

  InventoryItem({
    required this.name,
    required this.location,
    required this.type,
    this.link,
    this.comment,
    this.quantity,
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

  final _bName = TextEditingController();
  final _bPhone = TextEditingController();
  final _bEmail = TextEditingController();

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
                      _buildTextField(_locationController, "e.g. Closet Shelf"), // TODO: make it dropdown with last option being "Add New Location" that opens a dialog to add to a list of locations

                      // Type & Quantity in one Row
                      _buildSectionLabel("Type *"),
                      Row(  // TODO: either case requires qty input
                        children: [
                          Checkbox(
                            value: _selectedType == "Reusable",
                            onChanged: (val) { if (val == true) setSheetState(() => _selectedType = "Reusable"); },
                          ),
                          const Text("Reusable"), // TODO: means checkout function will be enabled for this item
                          const SizedBox(width: 8),
                          Checkbox(
                            value: _selectedType == "Disposable",
                            onChanged: (val) { if (val == true) setSheetState(() => _selectedType = "Disposable"); },
                          ),
                          const Text("Disposable"),
                          if (_selectedType == "Disposable") ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(_qtyController, "Qty", isNum: true),
                            ),
                          ]
                        ],
                      ),

                      // Image Placeholder
                      _buildSectionLabel("Item Image"),
                      InkWell(
                        onTap: () {}, //TODO Image picker logic
                        child: Container(
                          width: double.infinity,
                          height: 100,
                          decoration: BoxDecoration(
                            color: cBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                          ),
                          child: const Icon(Icons.add_a_photo_outlined, color: cPrimary, size: 32),
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
                          onPressed: () { if (_formKey.currentState!.validate()) _saveItem(); },
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

  void _saveItem() {
    setState(() {
      _inventory.add(InventoryItem(
        name: _nameController.text,
        location: _locationController.text,
        type: _selectedType,
        quantity: _selectedType == "Disposable" ? _qtyController.text : null,
        link: _linkController.text,
        comment: _commentController.text,
      ));
    });
    _nameController.clear();
    _locationController.clear();
    _qtyController.clear();
    Navigator.pop(context);
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
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, 
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
                                Container(
                                  height: 70, width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: cBackground, 
                                    borderRadius: BorderRadius.circular(15)
                                  ),
                                  // CHANGE: Swap icon if borrowed
                                  child: Icon(
                                    isBorrowed ? Icons.outbox_rounded : Icons.inventory_2_outlined, 
                                    color: isBorrowed ? cAccent : cPrimary.withOpacity(0.4)
                                  ),
                                ),
                                const Spacer(),
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
}