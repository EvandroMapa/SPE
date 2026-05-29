import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:acoplan/app/core/utils/global_resource.dart';
import 'package:flutter/material.dart';

class AppMultipleRegisters<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget createPage;
  final Function(T) onEdit;
  final Function(T) onAdd;
  final Function(T)? onDelete;
  final List<T> itens;
  final Widget Function(T) titleBuilder;

  const AppMultipleRegisters({
    required this.icon,
    required this.title,
    required this.createPage,
    required this.onEdit,
    required this.onAdd,
    this.onDelete,
    required this.itens,
    required this.titleBuilder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 36,
          child: GestureDetector(
            onTap: () async {
              final result = await push(context, createPage);
              if (result != null) {
                onAdd(result as T);
              }
            },
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon),
              title: Text(
                title + (itens.isNotEmpty ? '(${itens.length})' : ''),
                style: AppCss.mediumRegular,
              ),
              trailing: const Icon(Icons.add),
            ),
          ),
        ),
        for (T item in itens)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 12),
                  child: Text(
                    (itens.indexOf(item) + 1).toString(),
                    style: AppCss.minimumRegular,
                  ),
                ),
                Expanded(child: titleBuilder(item)),
                if (onDelete != null)
                  InkWell(
                    onTap: () => onDelete!(item),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red[400],
                      ),
                    ),
                  ),
                InkWell(
                  onTap: () => onEdit.call(item),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.edit_outlined, size: 18),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
      ],
    );
  }
}
