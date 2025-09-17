import 'package:flutter/material.dart';

class ResultDisplay extends StatelessWidget {
  final String title;
  final String value;
  final bool isMainResult;
  final Color? backgroundColor;
  final Color? textColor;

  const ResultDisplay({
    Key? key,
    required this.title,
    required this.value,
    this.isMainResult = false,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMainResult ? 24 : 16),
      decoration: BoxDecoration(
        color: backgroundColor ?? (isMainResult ? Colors.blue[50] : Colors.grey[50]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMainResult ? Colors.blue[300]! : Colors.grey[300]!,
          width: isMainResult ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isMainResult ? 18 : 14,
              fontWeight: FontWeight.w500,
              color: textColor ?? Colors.grey[700],
            ),
          ),
          SizedBox(height: isMainResult ? 12 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isMainResult ? 36 : 24,
              fontWeight: FontWeight.bold,
              color: textColor ?? (isMainResult ? Colors.blue[800] : Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}

class DataDisplayCard extends StatelessWidget {
  final String title;
  final List<DataItem> items;

  const DataDisplayCard({
    Key? key,
    required this.title,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 12),
            ...items.map((item) => _buildDataItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildDataItem(DataItem item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            item.label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            item.value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class DataItem {
  final String label;
  final String value;

  const DataItem({
    required this.label,
    required this.value,
  });
}

class ConfidenceIndicator extends StatelessWidget {
  final double confidence;
  final String? label;

  const ConfidenceIndicator({
    Key? key,
    required this.confidence,
    this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color getConfidenceColor() {
      if (confidence >= 0.8) return Colors.green;
      if (confidence >= 0.6) return Colors.orange;
      return Colors.red;
    }

    String getConfidenceText() {
      if (confidence >= 0.8) return '高精度';
      if (confidence >= 0.6) return '中精度';
      return '低精度';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: getConfidenceColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: getConfidenceColor()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            size: 16,
            color: getConfidenceColor(),
          ),
          SizedBox(width: 4),
          Text(
            label ?? getConfidenceText(),
            style: TextStyle(
              color: getConfidenceColor(),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}