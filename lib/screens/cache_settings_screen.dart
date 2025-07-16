import 'package:flutter/material.dart';
import '../services/optimized_tile_cache_service.dart';
import '../l10n/app_localizations.dart';

class CacheSettingsScreen extends StatefulWidget {
  const CacheSettingsScreen({super.key});

  @override
  State<CacheSettingsScreen> createState() => _CacheSettingsScreenState();
}

class _CacheSettingsScreenState extends State<CacheSettingsScreen> {
  final OptimizedTileCacheService _cacheService = OptimizedTileCacheService();
  Map<String, dynamic>? _cacheStats;
  bool _isClearing = false;
  bool _isRefreshing = true; // Start with refreshing state

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final stats = await _cacheService.getCacheStats();
      if (mounted) {
        setState(() {
          _cacheStats = stats;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cache stats: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmClearCache),
        content: Text(AppLocalizations.of(context)!.clearCacheWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.clear),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        setState(() {
          _isClearing = true;
        });
      }
      try {
        await _cacheService.clearCache();
        await _loadCacheStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.cacheCleared)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear cache: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isClearing = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.cacheSettings),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.cacheStatistics,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (_isRefreshing)
                      const Center(child: CircularProgressIndicator())
                    else if (_cacheStats != null)
                      Column(
                        children: [
                          _buildStatRow(
                            AppLocalizations.of(context)!.memoryCachedTiles,
                            '${_cacheStats!['memoryCacheCount']} / ${_cacheStats!['memoryCacheMaxSize']}',
                          ),
                          const SizedBox(height: 8),
                          _buildStatRow(
                            AppLocalizations.of(context)!.diskCachedTiles,
                            _cacheStats!['diskCacheCount'].toString(),
                          ),
                          const SizedBox(height: 8),
                          _buildStatRow(
                            AppLocalizations.of(context)!.diskCacheSize,
                            '${_cacheStats!['diskCacheSizeMB']} MB / ${_cacheStats!['diskCacheMaxSizeMB']} MB',
                          ),
                        ],
                      )
                    else
                      Center(
                        child: Text(AppLocalizations.of(context)!.failedToLoadCacheStats),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.cacheManagement,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isClearing || _isRefreshing ? null : _clearCache,
                        icon: _isClearing
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.delete_outline),
                        label: Text(AppLocalizations.of(context)!.clearCache),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isRefreshing || _isClearing ? null : _loadCacheStats,
                        icon: _isRefreshing
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                        label: Text(AppLocalizations.of(context)!.refreshStats),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.cacheInfo,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.cacheDescription,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
