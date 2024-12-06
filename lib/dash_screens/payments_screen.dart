import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaymentsScreen extends StatefulWidget {
  final String schoolCode;
  final String userId;
  final bool isAdmin;

  const PaymentsScreen({
    super.key,
    required this.schoolCode,
    required this.userId,
    this.isAdmin = false,
  });

  @override
  PaymentsScreenState createState() => PaymentsScreenState();
}

class PaymentsScreenState extends State<PaymentsScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _studentEmailController = TextEditingController();
  bool _isLoading = false;
  String? _selectedPaymentCategory;
  Map<String, dynamic>? _paymentIntent;

  final List<String> _paymentCategories = [
    'Tuition Fee',
    'Activity Fee',
    'Lab Fee',
    'Library Fee',
    'Transport Fee',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _initializeStripe();
  }

  Future<void> _initializeStripe() async {
    // Initialize Stripe with your publishable key
    stripe.Stripe.publishableKey = 'your_stripe_publishable_key';
    await stripe.Stripe.instance.applySettings();
  }

  Future<void> _createPaymentIntent(String amount, String currency) async {
    try {
      // Convert amount to cents/smallest currency unit
      final amountInCents = (double.parse(amount) * 100).round().toString();

      // Make request to your backend to create payment intent
      final response = await http.post(
        Uri.parse('your_backend_url/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount': amountInCents,
          'currency': currency,
          'payment_method_types[]': 'card'
        }),
      );

      _paymentIntent = json.decode(response.body);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> _savePaymentRecord({
    required String studentEmail,
    required String amount,
    required String description,
    required String status,
    required String paymentIntentId,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('payments')
          .add({
        'studentEmail': studentEmail,
        'amount': double.parse(amount),
        'description': description,
        'category': _selectedPaymentCategory,
        'status': status,
        'paymentIntentId': paymentIntentId,
        'timestamp': FieldValue.serverTimestamp(),
        'processorId': widget.userId,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _handlePayment() async {
    if (_amountController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _studentEmailController.text.isEmpty ||
        _selectedPaymentCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create payment intent
      await _createPaymentIntent(
        _amountController.text.trim(),
        'usd',
      );

      if (_paymentIntent == null) throw 'Payment intent creation failed';

      // Initialize payment sheet
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: _paymentIntent!['client_secret'],
          merchantDisplayName: 'School Payments',
          style: ThemeMode.system,
        ),
      );

      // Present payment sheet
      await stripe.Stripe.instance.presentPaymentSheet();

      // Save payment record
      await _savePaymentRecord(
        studentEmail: _studentEmailController.text.trim(),
        amount: _amountController.text.trim(),
        description: _descriptionController.text.trim(),
        status: 'completed',
        paymentIntentId: _paymentIntent!['id'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment successful')),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _amountController.clear();
    _descriptionController.clear();
    _studentEmailController.clear();
    setState(() => _selectedPaymentCategory = null);
  }

  Widget _buildPaymentForm() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _studentEmailController,
              decoration: const InputDecoration(
                labelText: 'Student Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPaymentCategory,
              decoration: const InputDecoration(
                labelText: 'Payment Category',
                prefixIcon: Icon(Icons.category),
              ),
              items: _paymentCategories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? value) {
                setState(() => _selectedPaymentCategory = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (USD)',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Process Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('payments')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final payments = snapshot.data?.docs ?? [];

        if (payments.isEmpty) {
          return const Center(child: Text('No payment records found'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Icon(
                  payment['status'] == 'completed'
                      ? Icons.check_circle
                      : Icons.pending,
                  color:
                  payment['status'] == 'completed' ? Colors.green : Colors.orange,
                ),
                title: Text(payment['studentEmail']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(payment['description']),
                    Text(
                      'Category: ${payment['category']}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                trailing: Text(
                  '\$${payment['amount'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onTap: () => _showPaymentDetails(payment),
              ),
            );
          },
        );
      },
    );
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Student', payment['studentEmail']),
              _buildDetailRow('Amount', '\$${payment['amount'].toStringAsFixed(2)}'),
              _buildDetailRow('Category', payment['category']),
              _buildDetailRow('Description', payment['description']),
              _buildDetailRow('Status', payment['status']),
              _buildDetailRow('Payment ID', payment['paymentIntentId']),
              _buildDetailRow(
                'Date',
                payment['timestamp']?.toDate().toString() ?? 'N/A',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Management'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isAdmin) _buildPaymentForm(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Payment History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildPaymentHistory(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _studentEmailController.dispose();
    super.dispose();
  }
}