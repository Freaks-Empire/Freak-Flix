import 'package:flutter/material.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Determine the range of pages to show (e.g., current-2 to current+2)
    const range = 2; // Neighbours on each side
    // clamp start and end
    int start = currentPage - range;
    int end = currentPage + range;
    
    // adjust if out of bounds
    if (start < 0) {
      end += -start; // shift window right
      start = 0;
    }
    if (end >= totalPages) {
       start -= (end - totalPages + 1); // shift window left
       end = totalPages - 1;
    }
    // clamp again just in case
    start = start < 0 ? 0 : start;
    end = end >= totalPages ? totalPages - 1 : end;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // FIRST / PREV
          IconButton.filledTonal(
            onPressed: currentPage > 0 ? () => onPageChanged(0) : null,
            icon: const Icon(Icons.first_page),
            tooltip: 'First Page',
          ),
          IconButton.filledTonal(
            onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous',
          ),

          // NUMBERED BUTTONS
          for (var i = start; i <= end; i++)
            if (i == currentPage)
               FilledButton(
                 onPressed: null, // Active
                 child: Text('${i + 1}'),
               )
            else
               OutlinedButton(
                 onPressed: () => onPageChanged(i),
                 style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                 ),
                 child: Text('${i + 1}'),
               ),

          // NEXT / LAST
          IconButton.filledTonal(
            onPressed: currentPage < totalPages - 1 ? () => onPageChanged(currentPage + 1) : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next',
          ),
          IconButton.filledTonal(
            onPressed: currentPage < totalPages - 1 ? () => onPageChanged(totalPages - 1) : null,
            icon: const Icon(Icons.last_page),
            tooltip: 'Last Page',
          ),
          
          const SizedBox(width: 8),
          Text(
            'Page ${currentPage + 1} of $totalPages',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
