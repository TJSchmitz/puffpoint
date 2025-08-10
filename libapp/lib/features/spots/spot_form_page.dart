import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repo/spots_repository.dart';

class SpotFormPage extends ConsumerStatefulWidget {
  const SpotFormPage({super.key});

  @override
  ConsumerState<SpotFormPage> createState() => _SpotFormPageState();
}

class _SpotFormPageState extends ConsumerState<SpotFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  String legalStatus = 'allowed';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final create = ref.read(createSpotProvider);
    await create(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      coords: GeoPoint(
        double.parse(_latCtrl.text),
        double.parse(_lngCtrl.text),
      ),
      legalStatus: legalStatus,
      address: null,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spot erstellen')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Titel'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Pflichtfeld' : null,
              ),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Beschreibung'),
              ),
              DropdownButtonFormField<String>(
                value: legalStatus,
                decoration: const InputDecoration(labelText: 'Legalstatus'),
                items: const [
                  DropdownMenuItem(value: 'allowed', child: Text('allowed')),
                  DropdownMenuItem(
                    value: 'restricted',
                    child: Text('restricted'),
                  ),
                  DropdownMenuItem(
                    value: 'forbidden',
                    child: Text('forbidden'),
                  ),
                ],
                onChanged: (v) => setState(() => legalStatus = v ?? 'allowed'),
              ),
              TextFormField(
                controller: _latCtrl,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                validator: (v) =>
                    v == null || double.tryParse(v) == null ? 'Ungültig' : null,
              ),
              TextFormField(
                controller: _lngCtrl,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                validator: (v) =>
                    v == null || double.tryParse(v) == null ? 'Ungültig' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _save, child: const Text('Speichern')),
            ],
          ),
        ),
      ),
    );
  }
}
