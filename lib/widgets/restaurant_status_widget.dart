import 'package:flutter/material.dart';
import 'package:african_cuisine/services/restaurant_hours_service.dart';

class RestaurantStatusWidget extends StatelessWidget {
  const RestaurantStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: RestaurantHoursService().restaurantStatusStream().cast<bool>(),
      builder: (context, snapshot) {
        final isOpen = snapshot.data ?? false;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isOpen ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOpen ? Icons.store : Icons.store_mall_directory_outlined,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                isOpen ? 'Open' : 'Closed',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}