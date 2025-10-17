import 'package:cse_kch/constants/app_constants.dart';
import 'package:flutter/material.dart';

class MultiSelectTextFormField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final List<String> options;
  final void Function(List<String>)? onSelectionChanged;

  const MultiSelectTextFormField({
    required this.controller,
    required this.labelText,
    required this.options,
    this.onSelectionChanged,
    super.key,
  });

  @override
  State<MultiSelectTextFormField> createState() =>
      _MultiSelectTextFormFieldState();
}

class _MultiSelectTextFormFieldState extends State<MultiSelectTextFormField> {
  late FocusNode _focusNode;
  List<String> selectedItems = [];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _showMultiSelectDialog() async {
    final List<String> tempSelected = List.from(selectedItems);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(widget.labelText),
              content: SingleChildScrollView(
                child: Column(
                  children: widget.options.map((option) {
                    final isChecked = tempSelected.contains(option);
                    return CheckboxListTile(
                      title: Text(option, style: const TextStyle(fontSize: 13)),
                      value: isChecked,
                      onChanged: (checked) {
                        setStateDialog(() {
                          if (checked == true) {
                            tempSelected.add(option);
                          } else {
                            tempSelected.remove(option);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedItems = List.from(tempSelected);
                      widget.controller.text = selectedItems.join(', ');
                      widget.onSelectionChanged?.call(selectedItems);
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text("Valider"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showMultiSelectDialog,
      child: AbsorbPointer(
        child: TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          readOnly: true,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: widget.labelText,
            labelStyle: const TextStyle(fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  selectedItems.clear();
                  widget.controller.clear();
                  widget.onSelectionChanged?.call([]);
                });
              },
              icon: const Icon(
                Icons.close,
                size: 18,
                color: AppConstants.backUpper,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppConstants.backUpper),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.orange),
              borderRadius: BorderRadius.circular(12),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.red),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.orange),
              borderRadius: BorderRadius.circular(12),
            ),
            errorStyle: const TextStyle(color: Colors.red, fontSize: 11),
          ),
          validator: (value) {
            if (selectedItems.isEmpty) {
              return '${widget.labelText} ?';
            }
            return null;
          },
        ),
      ),
    );
  }
}
