// ignore_for_file: file_names

import 'package:cse_kch/constants/app_constants.dart';
import 'package:flutter/material.dart';

class DeroulantTextFormField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final List<String> options;
  final void Function(String)? onChanged;

  const DeroulantTextFormField({
    required this.controller,
    required this.labelText,
    required this.options,
    this.onChanged,
    super.key,
  });

  @override
  State<DeroulantTextFormField> createState() => _DeroulantTextFormFieldState();
}

class _DeroulantTextFormFieldState extends State<DeroulantTextFormField> {
  late FocusNode _focusNode;
  bool _justFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.controller.text.isEmpty) {
        setState(() {
          _justFocused = true;
          widget.controller.text = ' ';
          widget.controller.selection = TextSelection.collapsed(
            offset: widget.controller.text.length,
          );
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_justFocused) {
            widget.controller.clear();
            _justFocused = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return RawAutocomplete<String>(
              textEditingController: widget.controller,
              focusNode: _focusNode,
              optionsBuilder: (TextEditingValue textEditingValue) {
                final input = textEditingValue.text.trim().toLowerCase();
                if (input.isEmpty) return widget.options;
                return widget.options.where(
                  (option) => option.toLowerCase().contains(input),
                );
              },
              fieldViewBuilder:
                  (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      readOnly: true, // ✅ empêche le clavier de s’ouvrir
                      onTap: () {
                        focusNode
                            .requestFocus(); // ✅ affiche quand même la liste déroulante
                      },
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: widget.labelText,
                        labelStyle: const TextStyle(fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => widget.controller.clear(),
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: AppConstants.backUpper,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: AppConstants.backUpper,
                          ),
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
                        errorStyle: const TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '${widget.labelText} ?'
                          : null,
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: constraints.maxWidth,
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: options
                              .map(
                                (option) => ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  title: Text(
                                    option,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  onTap: () {
                                    onSelected(option);
                                    widget.onChanged?.call(option);
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
