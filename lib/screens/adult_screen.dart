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
  String _sortBy = 'Date Added'; // Options: Date Added, Title, Year

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

    return Column(
      children: [
        // Controls Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${sortedItems.length} items',
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
            items: sortedItems,
            childAspectRatio: 16 / 9,
            maxCrossAxisExtent: 340,
          ),
        ),
      ],
    );
  }
}
