import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:network_sanitizer/network_sanitizer.dart';

final Dio dio = Dio();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  dio.options = BaseOptions(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  );

  dio.interceptors.add(
    NetworkSanitizerInterceptor(const Duration(seconds: 2)),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ),
    );
  }

  runApp(const NetworkSanitizerExampleApp());
}

class NetworkSanitizerExampleApp extends StatelessWidget {
  const NetworkSanitizerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Sanitizer Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<RequestDemo> _requests = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Sanitizer Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _clearRequests,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPlatformInfo(),
          _buildControlPanel(),
          const Divider(),
          Expanded(
            child: _buildRequestsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformInfo() {
    String platform = 'Unknown';
    String cacheType = 'Unknown';

    if (kIsWeb) {
      platform = 'Web';
      cacheType = 'Hive (Web Compatible)';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      platform = 'iOS';
      cacheType = 'hive (Native)';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      platform = 'Android';
      cacheType = 'hive (Native)';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Platform: $platform',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cache Storage: $cacheType',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Cache Duration: 5 seconds',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _makeRequest('/posts/1'),
                  icon: const Icon(Icons.download),
                  label: const Text('Fetch Post #1'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _makeRequest('/users/1'),
                  icon: const Icon(Icons.person),
                  label: const Text('Fetch User #1'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _makeDuplicateRequests,
                  icon: const Icon(Icons.copy),
                  label: const Text('Test Deduplication'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _makeForceRefreshRequest,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Force Refresh'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.network_check, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No requests yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Tap a button above to start testing',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[_requests.length - 1 - index];
        return RequestCard(request: request);
      },
    );
  }

  Future<void> _makeRequest(String endpoint) async {
    setState(() => _isLoading = true);

    final request = RequestDemo(
      endpoint: endpoint,
      timestamp: DateTime.now(),
      status: RequestStatus.loading,
    );

    setState(() => _requests.add(request));

    try {
      final stopwatch = Stopwatch()..start();
      final response = await dio.get(endpoint);
      stopwatch.stop();

      request.updateSuccess(
        statusCode: response.statusCode ?? 0,
        duration: stopwatch.elapsedMilliseconds,
        dataSize: response.data.toString().length,
        fromCache: response.extra.containsKey('cache_timestamp'),
      );
    } catch (e) {
      request.updateError(e.toString());
    }

    setState(() => _isLoading = false);
  }

  Future<void> _makeDuplicateRequests() async {
    setState(() => _isLoading = true);

    final futures = List.generate(3, (index) {
      final request = RequestDemo(
        endpoint: '/posts/1',
        timestamp: DateTime.now(),
        status: RequestStatus.loading,
        isDuplicate: index > 0,
      );

      setState(() => _requests.add(request));

      return _executeRequest(request);
    });

    await Future.wait(futures);
    setState(() => _isLoading = false);
  }

  Future<void> _makeForceRefreshRequest() async {
    setState(() => _isLoading = true);

    final request = RequestDemo(
      endpoint: '/posts/1',
      timestamp: DateTime.now(),
      status: RequestStatus.loading,
      isForceRefresh: true,
    );

    setState(() => _requests.add(request));

    try {
      final stopwatch = Stopwatch()..start();
      final response = await dio.get(
        '/posts/1',
        options: Options(
          extra: {'invalidateCache': true},
        ),
      );
      stopwatch.stop();

      request.updateSuccess(
        statusCode: response.statusCode ?? 0,
        duration: stopwatch.elapsedMilliseconds,
        dataSize: response.data.toString().length,
        fromCache: false,
      );
    } catch (e) {
      request.updateError(e.toString());
    }

    setState(() => _isLoading = false);
  }

  Future<void> _executeRequest(RequestDemo request) async {
    try {
      final stopwatch = Stopwatch()..start();
      final response = await dio.get(request.endpoint);
      stopwatch.stop();

      request.updateSuccess(
        statusCode: response.statusCode ?? 0,
        duration: stopwatch.elapsedMilliseconds,
        dataSize: response.data.toString().length,
        fromCache: response.extra.containsKey('cache_timestamp'),
      );
    } catch (e) {
      request.updateError(e.toString());
    }
  }

  void _clearRequests() {
    setState(() => _requests.clear());
  }
}

class RequestCard extends StatelessWidget {
  final RequestDemo request;

  const RequestCard({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.endpoint,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  _formatTime(request.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRequestDetails(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (request.status) {
      case RequestStatus.loading:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case RequestStatus.success:
        return Icon(
          request.fromCache ? Icons.cached : Icons.check_circle,
          color: request.fromCache ? Colors.orange : Colors.green,
          size: 20,
        );
      case RequestStatus.error:
        return const Icon(
          Icons.error,
          color: Colors.red,
          size: 20,
        );
    }
  }

  Widget _buildRequestDetails(BuildContext context) {
    final details = <Widget>[];

    if (request.isDuplicate) {
      details.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Color(0x1A9C27B0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'DUPLICATE REQUEST',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ),
      );
    }

    if (request.isForceRefresh) {
      details.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Color.fromRGBO(33, 150, 243, 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'FORCE REFRESH',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
      );
    }

    if (request.status == RequestStatus.success) {
      details.addAll([
        Text('Status: ${request.statusCode}'),
        Text('Duration: ${request.duration}ms'),
        Text('Size: ${request.dataSize} chars'),
        if (request.fromCache)
          const Text(
            'Source: Cache',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          )
        else
          const Text(
            'Source: Network',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
      ]);
    } else if (request.status == RequestStatus.error) {
      details.add(
        Text(
          'Error: ${request.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: details,
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

enum RequestStatus { loading, success, error }

class RequestDemo {
  final String endpoint;
  final DateTime timestamp;
  final bool isDuplicate;
  final bool isForceRefresh;

  RequestStatus status;
  int statusCode = 0;
  int duration = 0;
  int dataSize = 0;
  bool fromCache = false;
  String error = '';

  RequestDemo({
    required this.endpoint,
    required this.timestamp,
    required this.status,
    this.isDuplicate = false,
    this.isForceRefresh = false,
  });

  void updateSuccess({
    required int statusCode,
    required int duration,
    required int dataSize,
    required bool fromCache,
  }) {
    this.status = RequestStatus.success;
    this.statusCode = statusCode;
    this.duration = duration;
    this.dataSize = dataSize;
    this.fromCache = fromCache;
  }

  void updateError(String error) {
    this.status = RequestStatus.error;
    this.error = error;
  }
}
