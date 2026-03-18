import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  String _selectedType = 'Reusable';
  DateTimeRange? _checkoutRange;

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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
    if (digits.length < 10 || digits.length > 15) return 'Enter a valid phone number.';
    return null;
  }

  String? _validateEmail(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(input)) return 'Enter a valid email address.';
    return null;
  }

  String? _validateInventoryQuantity(String? value) {
    if (_selectedType == 'Reusable') return null;
    final input = value?.trim() ?? '';
    final parsed = int.tryParse(input);
    if (parsed == null || parsed <= 0) return 'Enter available quantity.';
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
    final initialRange = _checkoutRange ??
        DateTimeRange(
          start: now,
          end: now.add(const Duration(days: 7)),
        );

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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    validator: (value) => _requiredField(value, 'Borrower name is required.'),
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
                    validator: (value) => _validateCheckoutQuantity(value, item),
                  ),
                  _buildSectionLabel('Timeframe *'),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _pickCheckoutRange(setSheetState),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      decoration: BoxDecoration(
                        color: cBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: cPrimary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _checkoutRange == null
                                  ? 'Select checkout and return dates'
                                  : _formatRange(_checkoutRange!),
                              style: TextStyle(
                                fontSize: 15,
                                color: _checkoutRange == null ? Colors.grey.shade600 : Colors.black87,
                                fontWeight: _checkoutRange == null ? FontWeight.normal : FontWeight.w600,
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
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 28),
                  _btn('Confirm Checkout', cHighlight, () {
                    final isValid = _checkoutFormKey.currentState?.validate() ?? false;
                    if (!isValid || _checkoutRange == null) {
                      setSheetState(() {});
                      return;
                    }

                    setState(() {
                      item.borrower = Borrower(
                        name: _bName.text.trim(),
                        phone: _bPhone.text.trim(),
                        email: _bEmail.text.trim().isEmpty ? null : _bEmail.text.trim(),
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

  void _viewItemDetails(InventoryItem item, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
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
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.location_on_outlined, 'Location', item.location),
            _buildInfoRow(Icons.category_outlined, 'Type', '${item.type} ${item.quantity ?? ''}'),
            const Divider(height: 40),
            if (item.borrower != null) ...[
              Text(
                'Currently with ${item.borrower!.name}',
                style: const TextStyle(
                  color: cHighlight,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text('Phone: ${item.borrower!.phone}', style: const TextStyle(fontSize: 16)),
              if (item.borrower!.email?.isNotEmpty == true)
                Text('Email: ${item.borrower!.email}', style: const TextStyle(fontSize: 16)),
              Text('Quantity: ${item.borrower!.quantity}', style: const TextStyle(fontSize: 16)),
              Text(
                'Timeframe: ${_formatRange(item.borrower!.timeframe)}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              _btn('Return Item', cPrimary, () {
                setState(() => item.borrower = null);
                Navigator.pop(context);
              }),
            ] else ...[
              _btn('Check Out Item', cAccent, () => _showCheckoutDialog(item)),
            ],
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() => _inventory.removeAt(index));
                  Navigator.pop(context);
                },
                child: const Text(
                  'Delete from Inventory',
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
        width: double.infinity,
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
              style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

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
                top: 20,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 30),
                          ),
                          const Text(
                            'New Item',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSectionLabel('Item Name *'),
                      _buildTextField(
                        _nameController,
                        'e.g. Hiking Boots',
                        validator: (value) => _requiredField(value, 'Item name is required.'),
                      ),
                      _buildSectionLabel('Location *'),
                      _buildTextField(
                        _locationController,
                        'e.g. Closet Shelf',
                        validator: (value) => _requiredField(value, 'Location is required.'),
                      ),
                      _buildSectionLabel('Type & Quantity *'),
                      Row(
                        children: [
                          Checkbox(
                            value: _selectedType == 'Reusable',
                            onChanged: (val) {
                              if (val == true) {
                                setSheetState(() => _selectedType = 'Reusable');
                              }
                            },
                          ),
                          const Text('Reusable'),
                          const SizedBox(width: 8),
                          Checkbox(
                            value: _selectedType == 'Disposable',
                            onChanged: (val) {
                              if (val == true) {
                                setSheetState(() => _selectedType = 'Disposable');
                              }
                            },
                          ),
                          const Text('Disposable'),
                          if (_selectedType == 'Disposable') ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                _qtyController,
                                'Qty',
                                isNum: true,
                                validator: _validateInventoryQuantity,
                              ),
                            ),
                          ],
                        ],
                      ),
                      _buildSectionLabel('Item Image'),
                      InkWell(
                        onTap: () {},
                        child: Container(
                          width: double.infinity,
                          height: 100,
                          decoration: BoxDecoration(
                            color: cBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(Icons.add_a_photo_outlined, color: cPrimary, size: 32),
                        ),
                      ),
                      _buildSectionLabel('Link & Comments'),
                      _buildTextField(_linkController, 'URL Link (Optional)'),
                      const SizedBox(height: 12),
                      _buildTextField(_commentController, 'Notes...', maxLines: 3),
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
                            if (_formKey.currentState!.validate()) _saveItem();
                          },
                          child: const Text(
                            'Add to Inventory',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
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
      _inventory.add(
        InventoryItem(
          name: _nameController.text.trim(),
          location: _locationController.text.trim(),
          type: _selectedType,
          quantity: _selectedType == 'Disposable' ? _qtyController.text.trim() : null,
          link: _linkController.text.trim(),
          comment: _commentController.text.trim(),
        ),
      );
    });

    _nameController.clear();
    _locationController.clear();
    _linkController.clear();
    _commentController.clear();
    _qtyController.clear();
    _selectedType = 'Reusable';
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
        backgroundColor: cBackground,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFF0F7F4)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildStatBox('Total Items', _inventory.length.toString(), cPrimary, Colors.white),
                      const SizedBox(width: 16),
                      _buildStatBox(
                        'Checked Out',
                        _inventory.where((i) => i.borrower != null).length.toString(),
                        cSecondary,
                        cPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Current Stock',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: cAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_inventory.where((i) => i.borrower == null).length} available now',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _inventory.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 56, color: cPrimary),
                            SizedBox(height: 12),
                            Text(
                              'Inventory is empty',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add an item to start tracking stock and checkouts.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
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
                        final bool isBorrowed = item.borrower != null;

                        return InkWell(
                          onTap: () => _viewItemDetails(item, index),
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: isBorrowed ? Border.all(color: cAccent, width: 2) : null,
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
                                Container(
                                  height: 70,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: cBackground,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Icon(
                                    isBorrowed ? Icons.outbox_rounded : Icons.inventory_2_outlined,
                                    color: isBorrowed ? cAccent : cPrimary.withOpacity(0.4),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  isBorrowed ? 'With: ${item.borrower!.name}' : item.location,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isBorrowed ? cHighlight : Colors.grey.shade600,
                                    fontWeight: isBorrowed ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isBorrowed
                                        ? cAccent.withOpacity(0.2)
                                        : (item.type == 'Disposable'
                                            ? Colors.orange.withOpacity(0.1)
                                            : cSecondary.withOpacity(0.4)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isBorrowed
                                        ? 'Out: ${item.borrower!.quantity}'
                                        : (item.type == 'Disposable' ? 'Qty: ${item.quantity}' : 'Reusable'),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
      floatingActionButton: FloatingActionButton.large(
        onPressed: _showAddItemSheet,
        backgroundColor: cHighlight,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded, size: 40),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType ?? (isNum ? TextInputType.number : TextInputType.text),
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
    );
  }
}
