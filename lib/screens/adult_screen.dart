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
  String _sortBy = 'Date Added'; // Options: Date Added, Title, Year

  int _calculateItemsPerPage(BoxConstraints constraints) {
    
    // AdultScreen uses maxCrossAxisExtent = 340, childAspectRatio = 16 / 9
    final double gridWidth = constraints.maxWidth - 24; // approx padding
    const double maxCrossAxisExtent = 340;
    const double childAspectRatio = 16 / 9;
    const double spacing = 12;

    int crossAxisCount = (gridWidth / (maxCrossAxisExtent + spacing)).ceil();
    if (crossAxisCount < 1) crossAxisCount = 1;

    final double itemWidth = (gridWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
    final double itemHeight = itemWidth / childAspectRatio;

    // Estimate available height. 
    // AdultScreen has header (approx 48) and pagination (approx 60).
    // Let's reserve ~120 height.
    final double availableHeight = constraints.maxHeight - 140; 
    if (availableHeight <= 0) return 12; // Fallback

    int rowCount = (availableHeight / (itemHeight + spacing)).floor();
    if (rowCount < 2) rowCount = 2;

    return crossAxisCount * rowCount;
  }

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
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 2. Paginate dynamically
        final int pageSize = _calculateItemsPerPage(constraints);
        final totalItems = sortedItems.length;
        final totalPages = (totalItems / pageSize).ceil();
        
        // Clamp current page
        if (_currentPage >= totalPages && totalPages > 0) _currentPage = totalPages - 1;
        if (_currentPage < 0) _currentPage = 0;

        final start = _currentPage * pageSize;
        final end = (start + pageSize).clamp(0, totalItems);
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
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                child: _buildPagination(context, totalPages),
              ),
          ],
        );
      },
    );
  }
}
