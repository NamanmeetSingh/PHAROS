import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/activity_log_service.dart';

class ActivityLogWidget extends StatefulWidget {
  final int maxVisible;

  const ActivityLogWidget({
    Key? key,
    this.maxVisible = 30,
  }) : super(key: key);

  @override
  State<ActivityLogWidget> createState() => _ActivityLogWidgetState();
}

class _ActivityLogWidgetState extends State<ActivityLogWidget> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(ActivityLogWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to bottom when new logs are added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.telemetry:
        return const Color(0xFF00FF88); // Neon Green
      case LogLevel.microphone:
        return const Color(0xFF0066FF); // Neon Blue
      case LogLevel.vad:
        return const Color(0xFFFFAA00); // Neon Orange
      case LogLevel.io:
        return const Color(0xFFFF00FF); // Neon Magenta
      case LogLevel.engine:
        return const Color(0xFF00FFFF); // Neon Cyan
      case LogLevel.error:
        return const Color(0xFFFF3333); // Neon Red
      case LogLevel.info:
        return const Color(0xFFBBBBBB); // Light Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityLogService>(
      builder: (context, logService, _) {
        final logs = logService.logs;
        final visibleLogs = logs.length > widget.maxVisible
            ? logs.sublist(logs.length - widget.maxVisible)
            : logs;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E27),
            border: Border.all(
              color: const Color(0xFF00FF88),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.1),
                  border: const Border(
                    bottom: BorderSide(
                      color: Color(0xFF00FF88),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '▌ ACTIVITY LOG',
                      style: TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '${logs.length} events',
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              // Log content
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: visibleLogs.length,
                  itemBuilder: (context, index) {
                    final log = visibleLogs[index];
                    final color = _getLogColor(log.level);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        log.formatted,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontFamily: 'Courier New',
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
