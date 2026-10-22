import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A scrollable time form that fits above the keyboard on compact screens.
/// The framework input time picker imposes a fixed minimum height of 216px.
class MedicineTimeDialog extends StatefulWidget {
  const MedicineTimeDialog({
    super.key,
    required this.initialTime,
    required this.dose,
  });
  final TimeOfDay initialTime;
  final int dose;

  @override
  State<MedicineTimeDialog> createState() => _MedicineTimeDialogState();
}

class _MedicineTimeDialogState extends State<MedicineTimeDialog> {
  final _form = GlobalKey<FormState>();
  late final _hour = TextEditingController(
    text: widget.initialTime.hour.toString().padLeft(2, '0'),
  );
  late final _minute = TextEditingController(
    text: widget.initialTime.minute.toString().padLeft(2, '0'),
  );

  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.pop(
        context,
        TimeOfDay(hour: int.parse(_hour.text), minute: int.parse(_minute.text)),
      );
    }
  }

  Widget _field(String label, TextEditingController controller, int maximum) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textInputAction: maximum == 23
            ? TextInputAction.next
            : TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final number = int.tryParse(value ?? '');
          return number == null || number < 0 || number > maximum
              ? 'Use 0–$maximum'
              : null;
        },
        onFieldSubmitted: maximum == 59 ? (_) => _save() : null,
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text('Time for dose ${widget.dose}'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('24-hour time'),
          const SizedBox(height: 16),
          _field('Hour (0–23)', _hour, 23),
          const SizedBox(height: 12),
          _field('Minute (0–59)', _minute, 59),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save time')),
    ],
  );
}
