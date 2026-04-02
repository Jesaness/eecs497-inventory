import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

const Color cPrimary = Color(0xFF00A878);
const Color cSecondary = Color(0xFFD8F1A0);
const Color cAccent = Color(0xFFF3C178);
const Color cHighlight = Color(0xFFFE5E41);
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
        fontFamily: 'Georgia',
        colorScheme: ColorScheme.fromSeed(seedColor: cPrimary),
        scaffoldBackgroundColor: cBackground,
      ),
      home: const HomePage(),
    );
  }
}

// --- BORROWER MODEL ---
class Borrower {
  final String name;
  final String phone;
  final String? email;
  final int quantity;
  final DateTimeRange timeframe;

  Borrower({
    required this.name,
    required this.phone,
    this.email,
    required this.quantity,
    required this.timeframe,
  });
}

class InventoryItem {
  final String name;
  final String location;
  final String type;
  final Uint8List? imageBytes;
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
  final _checkoutFormKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _bName = TextEditingController();
  final TextEditingController _bPhone = TextEditingController();
  final TextEditingController _bEmail = TextEditingController();
  final TextEditingController _bQuantity = TextEditingController(text: '1');
  Uint8List? _webImage;

  final Set<String> _locations = {};
  String? _selectedLocation;

  String _selectedType = 'Disposable';
  DateTimeRange? _checkoutRange;

  String _filterMode = "All"; // Options: "All", "Storage", "CheckedOut"

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _linkController.dispose();
    _commentController.dispose();
    _qtyController.dispose();
    _bName.dispose();
    _bPhone.dispose();
    _bEmail.dispose();
    _bQuantity.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatRange(DateTimeRange range) {
    return '${_formatDate(range.start)} - ${_formatDate(range.end)}';
  }

  String? _requiredField(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _validatePhone(String? value) {
    final input = value?.trim() ?? '';
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Phone number is required.';
    if (digits.length < 10 || digits.length > 15)
      return 'Enter a valid phone number.';
    return null;
  }

  String? _validateEmail(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(input)) return 'Enter a valid email address.';
    return null;
  }

  String? _validateCheckoutQuantity(String? value, InventoryItem item) {
    final input = value?.trim() ?? '';
    final parsed = int.tryParse(input);
    final available = int.tryParse(item.quantity ?? '1') ?? 1;
    if (parsed == null || parsed <= 0) return 'Enter a valid quantity.';
    if (parsed > available) return 'Only $available available.';
    return null;
  }

  void _resetCheckoutFields() {
    _bName.clear();
    _bPhone.clear();
    _bEmail.clear();
    _bQuantity.text = '1';
    _checkoutRange = null;
  }

  Future<void> _pickCheckoutRange(StateSetter setSheetState) async {
    final now = DateTime.now();
    final initialRange =
        _checkoutRange ??
        DateTimeRange(start: now, end: now.add(const Duration(days: 7)));

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDateRange: initialRange,
      saveText: 'Apply',
    );

    if (picked != null) {
      setSheetState(() => _checkoutRange = picked);
    }
  }

  // --- SEARCH ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<InventoryItem> get _filteredInventory {
    // First, filter by the Button Category
    List<InventoryItem> categoryList = _inventory.where((item) {
      if (_filterMode == "Storage") return item.borrower == null;
      if (_filterMode == "CheckedOut") return item.borrower != null;
      return true; // "All" mode
    }).toList();

    // Then, apply the Search Query if there is one
    if (_searchQuery.isEmpty) return categoryList;
    
    return categoryList.where((item) {
      final query = _searchQuery.toLowerCase();
      return item.name.toLowerCase().contains(query) ||
            item.location.toLowerCase().contains(query) ||
            (item.borrower?.name.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _syncLocationsFromInventory();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  void _syncLocationsFromInventory() {
    for (final item in _inventory) {
      _locations.add(item.location);
    }
  }

  Widget _buildItemForm(StateSetter setSheetState, {bool isEdit = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        _buildSectionLabel("Item Name *"),
        _buildTextField(
            _nameController, 
            "e.g. Hiking Boots",
            validator: (value) =>
                _requiredField(value, 'Item name is required.'),
          ),
        

        _buildSectionLabel("Location *"),
        _buildLocationDropdown(
          setSheetState,
          validator: (value) =>
                _requiredField(value, 'Storage Location is required.'),
        ),

        _buildSectionLabel("Quantity *"),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // MINUS BUTTON
            _buildStepperBtn(Icons.remove_rounded, () {
              int current = int.tryParse(_qtyController.text) ?? 0;
              if (current > 0) {
                setSheetState(() => _qtyController.text = (current - 1).toString());
              }
            }),
            
            // MANUAL INPUT BOX
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: _buildTextField(
                _qtyController,
                "Qty",
                isNum: true,
                // Center the text inside the box for better looks
                textAlign: TextAlign.center, 
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (int.tryParse(value) == null) return 'Invalid';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),

            // PLUS BUTTON
            _buildStepperBtn(Icons.add_rounded, () {
              int current = int.tryParse(_qtyController.text) ?? 0;
              setSheetState(() => _qtyController.text = (current + 1).toString());
            }),
          ],
        ),

        _buildSectionLabel("Item Category *"),
        Center(
          child: ToggleButtons(
            borderRadius: BorderRadius.circular(15),
            selectedColor: Colors.white,
            fillColor: cPrimary,
            constraints: const BoxConstraints(minHeight: 45, minWidth: 130),
            isSelected: [
              _selectedType == "Reusable",
              _selectedType == "Disposable",
            ],
            onPressed: (index) {
              setSheetState(() {
                _selectedType = (index == 0) ? "Reusable" : "Disposable";
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text("Reusable", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text("Disposable", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // NEW: Dynamic Helper Text
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
          child: Center(
            child: Text(
              _selectedType == "Reusable"
                  ? "✓ Can be checked out and returned by borrowers."
                  : "⚠ Consumable item (e.g. spoons, plates). Not for checkout.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _selectedType == "Reusable" ? cPrimary : Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),

        _buildSectionLabel("Item Image"),
        InkWell(
          onTap: () => _pickImage(setSheetState),
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: cBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _webImage == null
                ? const Icon(Icons.add_a_photo_outlined, color: cPrimary, size: 32)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.memory(_webImage!, fit: BoxFit.cover),
                  ),
          ),
        ),

        _buildSectionLabel("Link & Comments"),
        _buildTextField(_linkController, "URL Link (Optional)"),
        const SizedBox(height: 12),
        _buildTextField(_commentController, "Notes...", maxLines: 3),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog(InventoryItem item) {
    _resetCheckoutFields();
    if (item.type == 'Reusable') {
      _bQuantity.text = '1';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _checkoutFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Checkout Item',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [cPrimary, Color(0xFF0F7B61)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item.location} • ${item.type}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                          ),
                        ),
                        if (item.quantity != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Available quantity: ${item.quantity}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildSectionLabel('Borrower Name *'),
                  _buildTextField(
                    _bName,
                    'e.g. Grace Pang',
                    validator: (value) =>
                        _requiredField(value, 'Borrower name is required.'),
                  ),
                  _buildSectionLabel('Phone Number *'),
                  _buildTextField(
                    _bPhone,
                    'e.g. (555) 123-4567',
                    keyboardType: TextInputType.phone,
                    validator: _validatePhone,
                  ),
                  _buildSectionLabel('Email'),
                  _buildTextField(
                    _bEmail,
                    'name@example.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  _buildSectionLabel('Quantity *'),
                  _buildTextField(
                    _bQuantity,
                    item.type == 'Reusable' ? '1' : 'How many?',
                    isNum: true,
                    readOnly: item.type == 'Reusable',
                    validator: (value) =>
                        _validateCheckoutQuantity(value, item),
                  ),
                  _buildSectionLabel('Timeframe *'),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _pickCheckoutRange(setSheetState),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: cBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            color: cPrimary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _checkoutRange == null
                                  ? 'Select checkout and return dates'
                                  : _formatRange(_checkoutRange!),
                              style: TextStyle(
                                fontSize: 15,
                                color: _checkoutRange == null
                                    ? Colors.grey.shade600
                                    : Colors.black87,
                                fontWeight: _checkoutRange == null
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_checkoutRange == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'A timeframe is required.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  _btn('Confirm Checkout', cHighlight, () {
                    final isValid =
                        _checkoutFormKey.currentState?.validate() ?? false;
                    if (!isValid || _checkoutRange == null) {
                      setSheetState(() {});
                      return;
                    }

                    setState(() {
                      item.borrower = Borrower(
                        name: _bName.text.trim(),
                        phone: _bPhone.text.trim(),
                        email: _bEmail.text.trim().isEmpty
                            ? null
                            : _bEmail.text.trim(),
                        quantity: int.parse(_bQuantity.text),
                        timeframe: _checkoutRange!,
                      );
                    });

                    _resetCheckoutFields();
                    Navigator.pop(sheetContext);
                    Navigator.pop(context);
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(void Function(void Function()) setSheetState) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final Uint8List imageBytes = await pickedFile.readAsBytes();
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final newLocation = newLocationController.text.trim();
              
              if (newLocation.isNotEmpty) {
                // ignore case
                final bool exists = _locations.any(
                  (loc) => loc.toLowerCase() == newLocation.toLowerCase(),
                );

                setSheetState(() {
                  if (!exists) {
                    _locations.add(newLocation);
                    _selectedLocation = newLocation;
                  } else {
                    final existingLocation = _locations.firstWhere(
                      (loc) => loc.toLowerCase() == newLocation.toLowerCase(),
                    );
                    _selectedLocation = existingLocation;
                  }
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow(
              Icons.location_on_outlined,
              'Location',
              item.location,
            ),
            _buildInfoRow(
              Icons.category_outlined,
              'Type',
              item.type,
            ),
            _buildInfoRow(
              Icons.inventory,
              'Quantity',
              '${item.quantity}',
            ),
            _buildInfoRow(
              Icons.link,
              'Link',
              (item.link == null || item.link!.isEmpty) ? 'None' : item.link!,
            ),
            _buildInfoRow(
              Icons.comment,
              'Comments',
              (item.comment == null || item.comment!.isEmpty) ? 'None' : item.comment!,
            ),
            const Divider(height: 40),

            if (item.borrower != null) ...[
              Text(
                "Currently with ${item.borrower!.name}",
                style: const TextStyle(
                  color: cHighlight,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                "Phone: ${item.borrower!.phone}",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _btn('Return Item', cPrimary, () {
                      setState(() => item.borrower = null);
                      Navigator.pop(context);
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _smallBtn(
                      'Edit Item',
                      cHighlight,
                      () => _showEditItemSheet(item, index),
                    ),
                  ),
                ],
              ),
            ] else ...[
              if(item.type == "Reusable") ...[
                Row(
                  children: [
                    Expanded(
                      child: _btn(
                        'Check Out Item',
                        cAccent,
                        () => _showCheckoutDialog(item),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _smallBtn(
                        'Edit Item',
                        cHighlight,
                        () => _showEditItemSheet(item, index),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _smallBtn(
                        'Edit Item',
                        cHighlight,
                        () => _showEditItemSheet(item, index),
                      ),
                    ),
                  ],
                ),
              ]
            ],
            // THE EDIT BUTTON
            // Positioned(
            //   top: 8,
            //   right: 8,
            //   child: IconButton.filled(
            //     style: IconButton.styleFrom(
            //       backgroundColor: cPrimary.withOpacity(0.1),
            //       foregroundColor: cPrimary,
            //     ),
            //     icon: const Icon(Icons.edit_outlined, size: 40),
            //     onPressed: () {
            //       // THE FIX:
            //       WidgetsBinding.instance.addPostFrameCallback((_) {
            //         if (mounted) _showEditItemSheet(item, index);
            //       });
            //     },
            //   ),
            // ),
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() => _inventory.removeAt(index));
                  Navigator.pop(context);
                },
                child: const Text(
                  "Delete from Inventory",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, Color col, VoidCallback tap) => SizedBox(
    height: 55,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: col,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: tap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );

  Widget _smallBtn(String label, Color col, VoidCallback tap) => SizedBox(
    height: 55,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: col,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: tap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );

  Widget _buildStatBox(
    String title,
    String value,
    Color bgColor,
    Color textColor,
  ) {
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
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemSheet() {
    _formKey.currentState?.reset();
      // Reset for new entry
      _nameController.clear();
      _qtyController.clear();
      _linkController.clear();
      _commentController.clear();
      _selectedLocation = null;
      _selectedType = "Disposable";
      _webImage = null;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) => Form( // <--- ADD THIS
          key: _formKey, // <--- ADD THIS
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              padding: EdgeInsets.only(
                top: 20, left: 24, right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Add New Item", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    _buildItemForm(setSheetState),

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
                          // 1. Trigger the red error messages and the scroll-to-error logic
                          if (_formKey.currentState!.validate()) {
                            // SUCCESS: This only runs if EVERY field passed its validator
                            setState(() {
                              _inventory.add(InventoryItem(
                                name: _nameController.text.trim(),
                                location: _selectedLocation!,
                                type: _selectedType,
                                imageBytes: _webImage,
                                // Since you want Quantity to always show, we save it regardless of type
                                quantity: _qtyController.text.isNotEmpty ? _qtyController.text : "0",
                                link: _linkController.text,
                                comment: _commentController.text,
                              ));
                            });
                            
                            // Clear and close
                            _nameController.clear();
                            _qtyController.clear();
                            _selectedLocation = null;
                            _webImage = null;
                            
                            Navigator.pop(context);
                          } else {
                            // FAIL: The form is now red. Let's make sure they see the error.
                            // This scrolls the list to the first field that has a red error.
                            Scrollable.ensureVisible(
                              _formKey.currentContext!,
                              alignment: 0.5, 
                              duration: const Duration(milliseconds: 300),
                            );
                          }
                        },
                        child: const Text("Add to Inventory", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

  void _showEditItemSheet(InventoryItem item, int index) {
    _formKey.currentState?.reset();
    // Populate data
    _nameController.text = item.name;
    _selectedLocation = item.location;
    _selectedType = item.type;
    _qtyController.text = item.quantity ?? "";
    _linkController.text = item.link ?? "";
    _commentController.text = item.comment ?? "";
    _webImage = item.imageBytes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Form( // <--- MUST ADD THIS
          key: _formKey, // <--- MUST ADD THIS
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            ),
            padding: EdgeInsets.only(
              top: 20, left: 24, right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Edit ${item.name}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  _buildItemForm(setSheetState),

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
                        if (_formKey.currentState!.validate()) {
                          setState(() {
                            _inventory[index] = InventoryItem(
                              name: _nameController.text.trim(),
                              location: _selectedLocation ?? item.location,
                              type: _selectedType,
                              imageBytes: _webImage,
                              quantity: _qtyController.text, // Always save if you want it to show
                              link: _linkController.text,
                              comment: _commentController.text,
                              borrower: item.borrower,
                            );
                          });
                          Navigator.pop(context);
                        } else {
                          // This snaps the view to the top-most error
                          Scrollable.ensureVisible(
                            _formKey.currentContext!,
                            alignment: 0.5,
                            duration: const Duration(milliseconds: 300),
                          );
                        }
                      },
                      child: const Text("Save Changes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  void _saveItem(void Function(void Function()) setSheetState) {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an item name.")),
      );
      return;
    }
    if (_selectedLocation != null) {
      setState(() {
        _inventory.add(
          InventoryItem(
            name: _nameController.text,
            location: _selectedLocation!,
            type: _selectedType,
            imageBytes: _webImage,
            quantity: _qtyController.text,
            link: _linkController.text,
            comment: _commentController.text,
          ),
        );
      });
      _nameController.clear();
      _qtyController.clear();
      _linkController.clear();
      _commentController.clear();
      setSheetState(() {
        _selectedLocation = null;
        _webImage = null;
      });
      Navigator.pop(context);
    }
  }

  // @override
  // Widget build(BuildContext context) {
  //   final filtered = _filteredInventory;

  //   return Scaffold(
  //     appBar: AppBar(
  //       title: const Text(
  //         'My Inventory',
  //         style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
  //       ),
  //       centerTitle: true,
  //       backgroundColor: cBackground,
  //       elevation: 0,
  //     ),
  //     body: Padding(
  //       padding: const EdgeInsets.symmetric(horizontal: 20),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           // --- SEARCH BAR ---
  //           Container(
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(20),
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: Colors.black.withOpacity(0.05),
  //                   blurRadius: 10,
  //                   offset: const Offset(0, 4),
  //                 ),
  //               ],
  //             ),
  //             child: TextField(
  //               controller: _searchController,
  //               decoration: InputDecoration(
  //                 hintText: "Search by name, location, borrower...",
  //                 hintStyle: TextStyle(
  //                   color: Colors.grey.shade400,
  //                   fontSize: 15,
  //                 ),
  //                 prefixIcon: const Icon(Icons.search_rounded, color: cPrimary),
  //                 suffixIcon: _searchQuery.isNotEmpty
  //                     ? IconButton(
  //                         icon: Icon(
  //                           Icons.close_rounded,
  //                           color: Colors.grey.shade400,
  //                         ),
  //                         onPressed: () => _searchController.clear(),
  //                       )
  //                     : null,
  //                 filled: true,
  //                 fillColor: Colors.white,
  //                 border: OutlineInputBorder(
  //                   borderRadius: BorderRadius.circular(20),
  //                   borderSide: BorderSide.none,
  //                 ),
  //                 contentPadding: const EdgeInsets.symmetric(vertical: 14),
  //               ),
  //             ),
  //           ),
  //           const SizedBox(height: 16),

  //           // --- STAT BOXES ---
  //           Row(
  //             children: [
  //               _buildStatBox(
  //                 "Total Items",
  //                 _inventory.length.toString(),
  //                 cPrimary,
  //                 Colors.white,
  //               ),
  //               const SizedBox(width: 16),
  //               _buildStatBox(
  //                 "Checked Out",
  //                 _inventory.where((i) => i.borrower != null).length.toString(),
  //                 cSecondary,
  //                 cPrimary,
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 32),

  //           // --- SECTION TITLE ---
  //           Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               const Text(
  //                 "Current Stock",
  //                 style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
  //               ),
  //               if (_searchQuery.isNotEmpty)
  //                 Text(
  //                   "${filtered.length} result${filtered.length == 1 ? '' : 's'}",
  //                   style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
  //                 ),
  //             ],
  //           ),
  //           const SizedBox(height: 16),

  //           Expanded(
  //             child: filtered.isEmpty
  //                 ? Center(
  //                     child: Text(
  //                       _searchQuery.isNotEmpty
  //                           ? "No items match \"$_searchQuery\""
  //                           : "Empty. Let's add something!",
  //                       style: TextStyle(
  //                         color: Colors.grey.shade400,
  //                         fontSize: 16,
  //                       ),
  //                     ),
  //                   )
  //                 : GridView.builder(
  //                     gridDelegate:
  //                         const SliverGridDelegateWithMaxCrossAxisExtent(
  //                           maxCrossAxisExtent: 220,
  //                           crossAxisSpacing: 16,
  //                           mainAxisSpacing: 16,
  //                           childAspectRatio: 0.85,
  //                         ),
  //                     itemCount: filtered.length,
  //                     itemBuilder: (context, index) {
  //                       final item = filtered[index];
  //                       final int realIndex = _inventory.indexOf(item);
  //                       final bool isBorrowed = item.borrower != null;

  //                       return InkWell(
  //                         onTap: () => _viewItemDetails(item, realIndex),
  //                         borderRadius: BorderRadius.circular(28),
  //                         child: Container(
  //                           decoration: BoxDecoration(
  //                             color: Colors.white,
  //                             borderRadius: BorderRadius.circular(28),
  //                             border: isBorrowed
  //                                 ? Border.all(color: cAccent, width: 2)
  //                                 : null,
  //                             boxShadow: [
  //                               BoxShadow(
  //                                 color: Colors.black.withOpacity(0.04),
  //                                 blurRadius: 10,
  //                                 offset: const Offset(0, 4),
  //                               ),
  //                             ],
  //                           ),
  //                           padding: const EdgeInsets.all(16),
  //                           child: Column(
  //                             crossAxisAlignment: CrossAxisAlignment.start,
  //                             children: [
  //                               Expanded(
  //                                 child: Container(
  //                                   width: double.infinity,
  //                                   decoration: BoxDecoration(
  //                                     color: cBackground,
  //                                     borderRadius: BorderRadius.circular(15),
  //                                   ),
  //                                   child: item.imageBytes != null
  //                                       ? ClipRRect(
  //                                           borderRadius: BorderRadius.circular(
  //                                             15,
  //                                           ),
  //                                           child: Image.memory(
  //                                             item.imageBytes!,
  //                                             fit: BoxFit.cover,
  //                                           ),
  //                                         )
  //                                       : Icon(
  //                                           isBorrowed
  //                                               ? Icons.outbox_rounded
  //                                               : Icons.inventory_2_outlined,
  //                                           color: isBorrowed
  //                                               ? cAccent
  //                                               : cPrimary.withOpacity(0.4),
  //                                         ),
  //                                 ),
  //                               ),
  //                               const SizedBox(height: 8),
  //                               Text(
  //                                 item.name,
  //                                 style: const TextStyle(
  //                                   fontSize: 20,
  //                                   fontWeight: FontWeight.bold,
  //                                 ),
  //                                 maxLines: 1,
  //                               ),
  //                               Text(
  //                                 isBorrowed
  //                                     ? "With: ${item.borrower!.name}"
  //                                     : item.location,
  //                                 style: TextStyle(
  //                                   fontSize: 14,
  //                                   color: isBorrowed
  //                                       ? cHighlight
  //                                       : Colors.grey.shade600,
  //                                   fontWeight: isBorrowed
  //                                       ? FontWeight.bold
  //                                       : FontWeight.normal,
  //                                 ),
  //                               ),
  //                               const SizedBox(height: 10),
  //                               Container(
  //                                 padding: const EdgeInsets.symmetric(
  //                                   horizontal: 10,
  //                                   vertical: 4,
  //                                 ),
  //                                 decoration: BoxDecoration(
  //                                   color: isBorrowed
  //                                       ? cAccent.withOpacity(0.2)
  //                                       : (item.type == "Disposable"
  //                                             ? Colors.orange.withOpacity(0.1)
  //                                             : cSecondary.withOpacity(0.4)),
  //                                   borderRadius: BorderRadius.circular(10),
  //                                 ),
  //                                 child: Text(
  //                                   isBorrowed
  //                                       ? "Checked Out"
  //                                       : "Qty: ${item.quantity}",
  //                                   style: const TextStyle(
  //                                     fontSize: 12,
  //                                     fontWeight: FontWeight.bold,
  //                                   ),
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                       );
  //                     },
  //                   ),
  //           ),
  //         ],
  //       ),
  //     ),
  //     floatingActionButton: FloatingActionButton.large(
  //       onPressed: _showAddItemSheet,
  //       backgroundColor: cHighlight,
  //       foregroundColor: Colors.white,
  //       child: const Icon(Icons.add_rounded, size: 40),
  //     ),
  //   );
  // }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? "No items match \"$_searchQuery\""
                : "Your inventory is empty!",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.large(
      onPressed: _showAddItemSheet,
      backgroundColor: cHighlight,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add_rounded, size: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredInventory;

    return Scaffold(
      appBar: AppBar( /* ... same as your code ... */ ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SEARCH BAR ---
            
            const SizedBox(height: 16),

            // --- FILTER BUTTONS ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterBtn("All", Icons.inventory_2_rounded, "All"),
                  const SizedBox(width: 8),
                  _filterBtn("In Storage", Icons.archive_rounded, "Storage"),
                  const SizedBox(width: 8),
                  _filterBtn("Checked Out", Icons.outbox_rounded, "CheckedOut"),
                ],
              ),
            ),

            const SizedBox(height: 24),
            
            // --- SECTION TITLE ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _filterMode == "All" ? "Current Stock" : (_filterMode == "Storage" ? "In Storage" : "Borrowed Items"),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  "${filtered.length} items",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
            
            const SizedBox(height: 16),

            // --- GRIDVIEW (Keep your existing GridView.builder here) ---
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? "No items match \"$_searchQuery\""
                            : "Empty. Let's add something!",
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.85,
                          ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final int realIndex = _inventory.indexOf(item);
                        final bool isBorrowed = item.borrower != null;

                        return InkWell(
                          onTap: () => _viewItemDetails(item, realIndex),
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: isBorrowed
                                  ? Border.all(color: cAccent, width: 2)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
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
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: item.imageBytes != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                            child: Image.memory(
                                              item.imageBytes!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Icon(
                                            isBorrowed
                                                ? Icons.outbox_rounded
                                                : Icons.inventory_2_outlined,
                                            color: isBorrowed
                                                ? cAccent
                                                : cPrimary.withOpacity(0.4),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                ),
                                Text(
                                  isBorrowed
                                      ? "With: ${item.borrower!.name}"
                                      : item.location,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isBorrowed
                                        ? cHighlight
                                        : Colors.grey.shade600,
                                    fontWeight: isBorrowed
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isBorrowed
                                        ? cAccent.withOpacity(0.2)
                                        : (item.type == "Disposable"
                                              ? Colors.orange.withOpacity(0.1)
                                              : cSecondary.withOpacity(0.4)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isBorrowed
                                        ? "Checked Out"
                                        : "Qty: ${item.quantity}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
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
      floatingActionButton: _buildFAB(),
    );
  }

  // Helper for the Filter Buttons
  Widget _filterBtn(String label, IconData icon, String mode) {
    bool isSelected = _filterMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _filterMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? cPrimary : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
          border: isSelected ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : cPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint, {
    bool isNum = false,
    int maxLines = 1,
    bool readOnly = false,
    TextInputType? keyboardType,
    TextAlign textAlign = TextAlign.start,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      textAlign: textAlign,
      keyboardType:
          keyboardType ?? (isNum ? TextInputType.number : TextInputType.text),
      inputFormatters: isNum ? [FilteringTextInputFormatter.digitsOnly] : [],
      maxLines: maxLines,
      readOnly: readOnly,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: cBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: cHighlight),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: cHighlight, width: 1.2),
        ),
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

Widget _buildLocationDropdown(
    void Function(void Function()) setSheetState, {
    String? Function(String?)? validator, // Add this optional parameter
  }) {
    final List<String> dropdownItems = [..._locations, "Add New Location"];

    return DropdownButtonFormField<String>(
      value: _locations.contains(_selectedLocation) ? _selectedLocation : null,
      hint: const Text("Select or add location"),
      validator: validator, // Use the passed-in validator here
      decoration: InputDecoration(
        filled: true,
        fillColor: cBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        // Adding error borders so the dropdown turns red like the text fields
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: cHighlight),
        ),
      ),
      items: dropdownItems.map((location) {
        return DropdownMenuItem<String>(
          value: location,
          child: Text(
            location,
            style: TextStyle(
              color: location == "Add New Location" ? cPrimary : Colors.black,
              fontWeight: location == "Add New Location"
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == "Add New Location") {
          _showAddLocationDialog(setSheetState);
        } else {
          setSheetState(() => _selectedLocation = value);
        }
      },
    );
  }  

Widget _buildStepperBtn(IconData icon, VoidCallback onPressed) {
  return Container(
    decoration: BoxDecoration(
      color: cPrimary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: IconButton(
      icon: Icon(icon, color: cPrimary),
      onPressed: onPressed,
    ),
  );
}
}
