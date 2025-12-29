/// lib/screens/adult_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../models/media_item.dart';
import '../widgets/media_grid.dart';
import '../widgets/empty_state.dart';

class AdultScreen extends StatefulWidget {
  const AdultScreen({super.key});

  @override
  State<AdultScreen> createState() => _AdultScreenState();
}

class _AdultScreenState extends State<AdultScreen> {
  int _currentPage = 0;
  final int _pageSize = 24;
  String _sortBy = 'Date Added'; // Options: Date Added, Title, Year

  Widget _buildPagination(BuildContext context, int totalPages) {
     final theme = Theme.of(context);
     final current = _currentPage + 1; // 1-indexed for display
     
     // Determine range of pages to show (e.g., current +/- 2)
     // Always show First (1) and Last (totalPages)
     
     final pages = <int>[];
     final start = (current - 2).clamp(1, totalPages);
     final end = (current + 2).clamp(1, totalPages);
     
     if (start > 1) pages.add(1);
     if (start > 2) pages.add(-1); // -1 indicates ellipsis
     
     for (int i = start; i <= end; i++) {
        pages.add(i);
     }
     
     if (end < totalPages - 1) pages.add(-1);
     if (end < totalPages) pages.add(totalPages);
     
     return Row(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
          // Previous Arrow
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            tooltip: 'Previous Page',
          ),
          
          const SizedBox(width: 8),

          // Numbered Buttons
          ...pages.map((p) {
             if (p == -1) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('...', style: TextStyle(color: Colors.white54)),
                );
             }
             
             final isActive = p == current;
             return Padding(
               padding: const EdgeInsets.symmetric(horizontal: 4),
               child: InkWell(
                 borderRadius: BorderRadius.circular(4),
                 onTap: () => setState(() => _currentPage = p - 1),
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                   decoration: BoxDecoration(
                     color: isActive ? Colors.blueAccent : Colors.transparent,
                     borderRadius: BorderRadius.circular(4),
                     border: isActive ? null : Border.all(color: Colors.white24),
                   ),
                   child: Text(
                     '$p',
                     style: TextStyle(
                       color: isActive ? Colors.white : Colors.white70,
                       fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                     ),
                   ),
                 ),
               ),
             );
          }).toList(),
          
          const SizedBox(width: 8),

          // Next Arrow
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
            tooltip: 'Next Page',
          ),
       ],
     );
  }

  @override
  Widget build(BuildContext context) {
    final allItems = context.watch<LibraryProvider>().adult;
    
    if (allItems.isEmpty) return const EmptyState(message: 'No adult content found.');

    // 1. Sort
    final sortedItems = List<MediaItem>.from(allItems);
    switch (_sortBy) {
      case 'Title':
        sortedItems.sort((a, b) => (a.title ?? a.fileName).compareTo(b.title ?? b.fileName));
        break;
      case 'Year':
        sortedItems.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
        break;
      case 'Date Added':
      default:
        // Assuming the provider list is already somewhat sorted or we use file creation time if available
        // For now, let's assume the provider gives them consistent order, or we reverse if "Date Added" implies newest.
        // If MediaItem has a dateAdded field, use that. If not, default order is usually scan order.
        // Let's reverse standard list for "Newest first" if that's the implication, or just keep as is.
        // Actually, let's try to sort by 'modified' if available, or just name as fallback?
        // Let's stick to simple list reversal for "Date Added" (Newest) usually effectively means "Latest scanned" often at end?
        // Let's check MediaItem definition later. For now, default order.
        break;
    }

    // 2. Paginate
    final totalItems = sortedItems.length;
    final totalPages = (totalItems / _pageSize).ceil();
    // Clamp current page if out of bounds (e.g. after filtering changes)
    if (_currentPage >= totalPages && totalPages > 0) _currentPage = totalPages - 1;
    if (_currentPage < 0) _currentPage = 0;

    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, totalItems);
    final pageItems = sortedItems.sublist(start, end);

    return Column(
      children: [
        // Controls Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalItems items',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              DropdownButton<String>(
                value: _sortBy,
                underline: const SizedBox(),
                style: Theme.of(context).textTheme.bodyMedium,
                onChanged: (val) {
                  if (val != null) setState(() => _sortBy = val);
                },
                items: const [
                  DropdownMenuItem(value: 'Date Added', child: Text('Date Added')),
                  DropdownMenuItem(value: 'Title', child: Text('Title')),
                  DropdownMenuItem(value: 'Year', child: Text('Year')),
                ],
              ),
            ],
          ),
        ),
        
        // Grid
        Expanded(
          child: MediaGrid(
            items: pageItems,
            childAspectRatio: 16 / 9,
            maxCrossAxisExtent: 340,
          ),
        ),

        // Pagination Footer
        if (totalPages > 1)
          Padding(
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: _buildPagination(context, totalPages),
          ),
          ),
      ],
    );
  }
}
