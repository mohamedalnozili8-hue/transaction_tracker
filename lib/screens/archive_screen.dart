import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/transaction_model.dart';
import 'transaction_detail_screen.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final _db = DatabaseHelper.instance;
  List<TransactionModel> _items = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _db.getArchivedTransactions();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  List<TransactionModel> get _filtered {
    if (_query.trim().isEmpty) return _items;
    final q = _query.trim();
    return _items
        .where((t) =>
            t.title.contains(q) || t.templateName.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأرشيف')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث في المعاملات المؤرشفة...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) => _buildCard(_filtered[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('لا توجد معاملات مؤرشفة بعد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('المعاملات المكتملة أو الملغاة ستظهر هنا تلقائياً',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(TransactionModel t) {
    final isCompleted = t.status == TransactionStatus.completed;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor:
              isCompleted ? Colors.green.shade50 : Colors.grey.shade200,
          child: Icon(
            isCompleted ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: isCompleted ? Colors.green : Colors.grey.shade600,
          ),
        ),
        title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${t.templateName} • ${t.completedAt != null ? DateFormat('yyyy/MM/dd', 'ar').format(t.completedAt!) : ''}',
        ),
        trailing: Text(
          isCompleted ? 'مكتملة' : 'ملغاة',
          style: TextStyle(
            color: isCompleted ? Colors.green.shade700 : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TransactionDetailScreen(transactionId: t.id)),
          );
        },
      ),
    );
  }
}
