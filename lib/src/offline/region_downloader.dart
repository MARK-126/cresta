import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'map_sources.dart';
import 'offline_region.dart';
import 'tile_store.dart';

class DownloadProgress {
  const DownloadProgress(this.done, this.total, this.bytes);
  final int done;
  final int total;
  final int bytes;
}

enum DownloadOutcome { complete, cancelled, offline, failed }

class DownloadResult {
  const DownloadResult(this.outcome, {this.message});
  final DownloadOutcome outcome;
  final String? message;
}

/// Permite pausar una descarga en curso.
class CancelToken {
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Descarga los mosaicos de una zona.
///
/// Es reanudable: los mosaicos que ya están en disco se cuentan como hechos y no se vuelven a pedir.
class RegionDownloader {
  RegionDownloader({
    required this.store,
    required this.client,
    required this.topoTemplate,
    this.concurrency = 4,
    this.retryDelay = const Duration(milliseconds: 600),
  });

  final TileStore store;
  final http.Client client;
  final Future<String?> Function() topoTemplate;

  /// Pocas conexiones a la vez: los servicios son gratuitos y piden uso moderado.
  final int concurrency;
  final Duration retryDelay;

  /// Fallos de red seguidos a partir de los cuales se asume que no hay conexión.
  static const _offlineAfter = 6;

  Future<DownloadResult> run(
    OfflineRegion region, {
    required CancelToken token,
    void Function(DownloadProgress)? onProgress,
  }) async {
    final topo = region.sources.contains(MapSource.topo)
        ? await topoTemplate()
        : null;
    if (region.sources.contains(MapSource.topo) && topo == null) {
      return const DownloadResult(
        DownloadOutcome.offline,
        message: 'Sin conexión para obtener el mapa topográfico',
      );
    }

    final jobs = region.jobs.iterator;
    var done = 0, bytes = 0, consecutiveFailures = 0, missing = 0;
    DownloadResult? stop;

    Future<void> worker() async {
      while (stop == null && !token.cancelled) {
        if (!jobs.moveNext()) {
          return; // el iterador se comparte; Dart es de un solo hilo
        }
        final job = jobs.current;

        final existing = store.file(job.source, job.z, job.x, job.y);
        if (await existing.exists()) {
          bytes += await existing.length();
        } else {
          final r = await _fetch(
            tileUrl(job.source, job.z, job.x, job.y, topoTemplate: topo)!,
          );
          switch (r) {
            case _Fetched(:final body):
              await store.write(job.source, job.z, job.x, job.y, body);
              bytes += body.length;
              consecutiveFailures = 0;
            case _NoTile():
              missing++; // el servidor no tiene ese mosaico (p. ej. mar abierto); no es un error
              consecutiveFailures = 0;
            case _Failed():
              consecutiveFailures++;
              if (consecutiveFailures >= _offlineAfter) {
                stop = const DownloadResult(
                  DownloadOutcome.offline,
                  message: 'Se perdió la conexión',
                );
              }
              continue; // no cuenta como hecho: se reintenta al reanudar
          }
        }
        done++;
        onProgress?.call(DownloadProgress(done, region.totalTiles, bytes));
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));

    if (stop != null) return stop!;
    if (token.cancelled) return const DownloadResult(DownloadOutcome.cancelled);
    if (done < region.totalTiles) {
      return DownloadResult(
        DownloadOutcome.failed,
        message: 'Faltaron ${region.totalTiles - done} mosaicos',
      );
    }
    return DownloadResult(
      DownloadOutcome.complete,
      message: missing > 0
          ? '$missing mosaicos sin datos en el servidor'
          : null,
    );
  }

  Future<_FetchResult> _fetch(Uri url) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final r = await client
            .get(url, headers: {'User-Agent': userAgent})
            .timeout(const Duration(seconds: 20));
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
          return _Fetched(r.bodyBytes);
        }
        if (r.statusCode == 404 || r.statusCode == 204) return const _NoTile();
        if (r.statusCode >= 400 && r.statusCode < 500 && r.statusCode != 429) {
          return const _Failed();
        }
      } on TimeoutException {
        // reintentar
      } on SocketException {
        // reintentar
      } on http.ClientException {
        // reintentar
      }
      await Future<void>.delayed(retryDelay * (1 << attempt));
    }
    return const _Failed();
  }
}

sealed class _FetchResult {
  const _FetchResult();
}

class _Fetched extends _FetchResult {
  const _Fetched(this.body);
  final List<int> body;
}

class _NoTile extends _FetchResult {
  const _NoTile();
}

class _Failed extends _FetchResult {
  const _Failed();
}
