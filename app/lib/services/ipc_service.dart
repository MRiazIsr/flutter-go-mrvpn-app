import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show sleep;
import 'dart:math';

import 'package:ffi/ffi.dart';

import 'logger.dart';

/// Windows API constants for named pipe client.
const int _genericRead = 0x80000000;
const int _genericWrite = 0x40000000;
const int _openExisting = 3;
const int _invalidHandleValue = -1;
const int _fileAttributeNormal = 0x80;

/// Windows kernel32 function signatures.
typedef _CreateFileNative = IntPtr Function(
  Pointer<Utf16> lpFileName,
  Uint32 dwDesiredAccess,
  Uint32 dwShareMode,
  Pointer<Void> lpSecurityAttributes,
  Uint32 dwCreationDisposition,
  Uint32 dwFlagsAndAttributes,
  IntPtr hTemplateFile,
);
typedef _CreateFileDart = int Function(
  Pointer<Utf16> lpFileName,
  int dwDesiredAccess,
  int dwShareMode,
  Pointer<Void> lpSecurityAttributes,
  int dwCreationDisposition,
  int dwFlagsAndAttributes,
  int hTemplateFile,
);

typedef _ReadFileNative = Int32 Function(
  IntPtr hFile,
  Pointer<Uint8> lpBuffer,
  Uint32 nNumberOfBytesToRead,
  Pointer<Uint32> lpNumberOfBytesRead,
  Pointer<Void> lpOverlapped,
);
typedef _ReadFileDart = int Function(
  int hFile,
  Pointer<Uint8> lpBuffer,
  int nNumberOfBytesToRead,
  Pointer<Uint32> lpNumberOfBytesRead,
  Pointer<Void> lpOverlapped,
);

typedef _WriteFileNative = Int32 Function(
  IntPtr hFile,
  Pointer<Uint8> lpBuffer,
  Uint32 nNumberOfBytesToWrite,
  Pointer<Uint32> lpNumberOfBytesWritten,
  Pointer<Void> lpOverlapped,
);
typedef _WriteFileDart = int Function(
  int hFile,
  Pointer<Uint8> lpBuffer,
  int nNumberOfBytesToWrite,
  Pointer<Uint32> lpNumberOfBytesWritten,
  Pointer<Void> lpOverlapped,
);

typedef _CloseHandleNative = Int32 Function(IntPtr hObject);
typedef _CloseHandleDart = int Function(int hObject);

typedef _PeekNamedPipeNative = Int32 Function(
  IntPtr hNamedPipe,
  Pointer<Void> lpBuffer,
  Uint32 nBufferSize,
  Pointer<Uint32> lpBytesRead,
  Pointer<Uint32> lpTotalBytesAvail,
  Pointer<Uint32> lpBytesLeftThisMessage,
);
typedef _PeekNamedPipeDart = int Function(
  int hNamedPipe,
  Pointer<Void> lpBuffer,
  int nBufferSize,
  Pointer<Uint32> lpBytesRead,
  Pointer<Uint32> lpTotalBytesAvail,
  Pointer<Uint32> lpBytesLeftThisMessage,
);

/// IPC client for communicating with the MRVPN Go backend
/// via a Windows named pipe (\\.\pipe\MRVPN).
///
/// Uses a JSON line-delimited protocol where each message is a JSON object
/// terminated by a newline character.
class IpcService {
  static const String _pipePath = r'\\.\pipe\MRVPN';
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const Duration _reconnectBaseDelay = Duration(seconds: 1);
  static const Duration _reconnectMaxDelay = Duration(seconds: 30);
  static const int _maxReconnectAttempts = 10;

  int _pipeHandle = _invalidHandleValue;
  bool _connected = false;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _readTimer;
  int _nextRequestId = 1;

  late final _CreateFileDart _createFile;
  late final _ReadFileDart _readFile;
  late final _WriteFileDart _writeFile;
  late final _CloseHandleDart _closeHandle;
  late final _PeekNamedPipeDart _peekNamedPipe;

  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};
  final List<int> _readByteBuffer = [];

  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get notifications =>
      _notificationController.stream;
  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool get isConnected => _connected;

  IpcService() {
    _loadKernel32();
  }

  /// Send a one-shot shutdown command to the backend via a fresh pipe connection.
  /// This is independent of the main IPC connection state — useful during app
  /// exit when the Riverpod-managed IpcService may already be disposed.
  static void sendShutdownSync() {
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final createFile = kernel32
          .lookupFunction<_CreateFileNative, _CreateFileDart>('CreateFileW');
      final writeFile = kernel32
          .lookupFunction<_WriteFileNative, _WriteFileDart>('WriteFile');
      final closeHandle = kernel32
          .lookupFunction<_CloseHandleNative, _CloseHandleDart>('CloseHandle');

      final pipeNamePtr = _pipePath.toNativeUtf16();
      final handle = createFile(
        pipeNamePtr,
        _genericRead | _genericWrite,
        0,
        nullptr,
        _openExisting,
        _fileAttributeNormal,
        0,
      );
      calloc.free(pipeNamePtr);

      if (handle == _invalidHandleValue || handle == 0) return;

      final msg = utf8.encode('{"id":"0","method":"service.shutdown"}\n');
      final buffer = calloc<Uint8>(msg.length);
      final bytesWritten = calloc<Uint32>();
      for (int i = 0; i < msg.length; i++) {
        buffer[i] = msg[i];
      }
      writeFile(handle, buffer, msg.length, bytesWritten, nullptr);
      calloc.free(buffer);
      calloc.free(bytesWritten);

      // Give the backend a moment to process before closing
      sleep(const Duration(milliseconds: 200));
      closeHandle(handle);
    } catch (_) {
      // Best-effort — if pipe is not available, backend is already gone.
    }
  }

  void _loadKernel32() {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    _createFile = kernel32
        .lookupFunction<_CreateFileNative, _CreateFileDart>('CreateFileW');
    _readFile =
        kernel32.lookupFunction<_ReadFileNative, _ReadFileDart>('ReadFile');
    _writeFile =
        kernel32.lookupFunction<_WriteFileNative, _WriteFileDart>('WriteFile');
    _closeHandle = kernel32
        .lookupFunction<_CloseHandleNative, _CloseHandleDart>('CloseHandle');
    _peekNamedPipe = kernel32
        .lookupFunction<_PeekNamedPipeNative, _PeekNamedPipeDart>(
            'PeekNamedPipe');
  }

  /// Connect to the Go backend via the named pipe.
  Future<bool> connect() async {
    AppLogger.log('IPC', 'connect() called, disposed=$_disposed connected=$_connected');
    if (_disposed) return false;
    if (_connected) return true;

    AppLogger.log('IPC', 'CreateFileW on $_pipePath...');
    final pipeNamePtr = _pipePath.toNativeUtf16();
    try {
      _pipeHandle = _createFile(
        pipeNamePtr,
        _genericRead | _genericWrite,
        0, // no sharing
        nullptr, // default security
        _openExisting,
        _fileAttributeNormal,
        0, // no template
      );
    } finally {
      calloc.free(pipeNamePtr);
    }
    AppLogger.log('IPC', 'CreateFileW returned handle=$_pipeHandle');

    if (_pipeHandle == _invalidHandleValue || _pipeHandle == 0) {
      AppLogger.log('IPC', 'Pipe not available, scheduling reconnect (attempt $_reconnectAttempts)');
      _scheduleReconnect();
      return false;
    }

    _connected = true;
    _reconnectAttempts = 0;
    _connectionStatusController.add(true);
    AppLogger.log('IPC', 'Connected to pipe, starting reader');

    // Start reading from the pipe in a polling manner
    _startReading();

    return true;
  }

  /// Disconnect from the Go backend.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = _maxReconnectAttempts;
    _stopReading();
    _closePipe();
  }

  /// Send a request and await the response.
  Future<Map<String, dynamic>> sendRequest(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    AppLogger.log('IPC', 'sendRequest("$method") connected=$_connected');
    if (!_connected) {
      throw const IpcException('Not connected to backend');
    }

    final requestId = _nextRequestId++;
    final request = <String, dynamic>{
      'id': requestId.toString(),
      'method': method,
    };
    if (params != null) {
      request['params'] = params;
    }

    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;

    try {
      final jsonLine = '${jsonEncode(request)}\n';
      AppLogger.log('IPC', 'writeToPipe for "$method" (id=$requestId)...');
      _writeToPipe(jsonLine);
      AppLogger.log('IPC', 'writeToPipe done for "$method"');

      final response = await completer.future.timeout(
        _requestTimeout,
        onTimeout: () {
          _pendingRequests.remove(requestId);
          throw TimeoutException(
            'Request "$method" (id: $requestId) timed out',
            _requestTimeout,
          );
        },
      );

      if (response.containsKey('error') && response['error'] != null) {
        final error = response['error'];
        final message =
            error is Map ? error['message'] as String? : '$error';
        throw IpcException(message ?? 'Unknown backend error');
      }

      final result = response['result'];
      if (result is Map<String, dynamic>) {
        return result;
      }
      return <String, dynamic>{'value': result};
    } catch (e) {
      _pendingRequests.remove(requestId);
      if (e is IpcException || e is TimeoutException) rethrow;
      throw IpcException('Failed to send request "$method": $e');
    }
  }

  void _writeToPipe(String data) {
    final bytes = utf8.encode(data);
    final buffer = calloc<Uint8>(bytes.length);
    final bytesWritten = calloc<Uint32>();

    try {
      for (int i = 0; i < bytes.length; i++) {
        buffer[i] = bytes[i];
      }

      final result = _writeFile(
        _pipeHandle,
        buffer,
        bytes.length,
        bytesWritten,
        nullptr,
      );

      if (result == 0) {
        throw const IpcException('Failed to write to pipe');
      }
    } finally {
      calloc.free(buffer);
      calloc.free(bytesWritten);
    }
  }

  void _startReading() {
    // Poll for data every 50ms using an isolate-safe timer
    _readTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_connected) return;
      try {
        _readFromPipe();
      } catch (e, st) {
        AppLogger.log('IPC', 'EXCEPTION in _readFromPipe: $e');
        AppLogger.log('IPC', 'Stack: $st');
      }
    });
  }

  void _stopReading() {
    _readTimer?.cancel();
    _readTimer = null;
  }

  int _readPollCount = 0;

  void _readFromPipe() {
    _readPollCount++;
    if (_readPollCount % 100 == 1) {
      AppLogger.log('IPC', '_readFromPipe poll #$_readPollCount');
    }

    final totalAvail = calloc<Uint32>();

    try {
      final peekResult = _peekNamedPipe(
        _pipeHandle,
        nullptr,
        0,
        nullptr,
        totalAvail,
        nullptr,
      );

      if (peekResult == 0) {
        AppLogger.log('IPC', 'PeekNamedPipe FAILED (pipe broken), poll #$_readPollCount');
        _handleDisconnect();
        return;
      }

      if (totalAvail.value == 0) {
        return;
      }

      AppLogger.log('IPC', 'PeekNamedPipe: ${totalAvail.value} bytes available');
    } finally {
      calloc.free(totalAvail);
    }

    // Use a 256KB buffer — app list with icons can be several hundred KB.
    const bufferSize = 262144;
    final buffer = calloc<Uint8>(bufferSize);
    final bytesRead = calloc<Uint32>();

    try {
      final result = _readFile(
        _pipeHandle,
        buffer,
        bufferSize,
        bytesRead,
        nullptr,
      );
      AppLogger.log('IPC', 'ReadFile returned result=$result bytesRead=${bytesRead.value}');

      if (result != 0 && bytesRead.value > 0) {
        // Append raw bytes — do NOT utf8.decode here to avoid splitting
        // multi-byte characters across read boundaries.
        for (int i = 0; i < bytesRead.value; i++) {
          _readByteBuffer.add(buffer[i]);
        }
        AppLogger.log('IPC', 'Buffer now ${_readByteBuffer.length} bytes');
        _processByteBuffer();
      } else if (result == 0) {
        AppLogger.log('IPC', 'ReadFile failed, disconnecting');
        _handleDisconnect();
      }
    } catch (e, st) {
      AppLogger.log('IPC', 'EXCEPTION in ReadFile section: $e');
      AppLogger.log('IPC', 'Stack: $st');
    } finally {
      calloc.free(buffer);
      calloc.free(bytesRead);
    }
  }

  /// Process the byte buffer, extracting and handling complete newline-delimited
  /// JSON messages. Only decodes UTF-8 on complete lines to avoid boundary bugs.
  void _processByteBuffer() {
    while (true) {
      final newlineIndex = _readByteBuffer.indexOf(0x0A); // '\n'
      if (newlineIndex == -1) break;

      // Extract bytes for this complete line (excluding the newline).
      final lineBytes = _readByteBuffer.sublist(0, newlineIndex);
      _readByteBuffer.removeRange(0, newlineIndex + 1);

      if (lineBytes.isEmpty) continue;

      try {
        final line = utf8.decode(lineBytes).trim();
        if (line.isEmpty) continue;
        AppLogger.log('IPC', 'Processing line: ${line.length} chars');
        final message = jsonDecode(line) as Map<String, dynamic>;
        _handleMessage(message);
      } catch (e) {
        AppLogger.log('IPC', 'Failed to decode/parse line: $e');
      }
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    if (message.containsKey('id') && message['id'] != null) {
      // Response to a pending request
      final idStr = message['id'].toString();
      final id = int.tryParse(idStr);
      if (id != null && _pendingRequests.containsKey(id)) {
        _pendingRequests.remove(id)!.complete(message);
      }
    } else if (message.containsKey('method')) {
      // Server-initiated notification
      _notificationController.add(message);
    }
  }

  void _handleDisconnect() {
    AppLogger.log('IPC', '_handleDisconnect called, was connected=$_connected');
    if (!_connected) return;

    _connected = false;
    _connectionStatusController.add(false);
    _stopReading();

    for (final completer in _pendingRequests.values) {
      completer.completeError(const IpcException('Connection lost'));
    }
    _pendingRequests.clear();
    _readByteBuffer.clear();

    _closePipeHandle();

    if (!_disposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    AppLogger.log('IPC', '_scheduleReconnect attempt=$_reconnectAttempts/$_maxReconnectAttempts disposed=$_disposed');
    if (_disposed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      AppLogger.log('IPC', 'Max reconnect attempts reached, giving up');
      return;
    }

    _reconnectTimer?.cancel();

    final delay = Duration(
      milliseconds: (_reconnectBaseDelay.inMilliseconds *
              pow(2, _reconnectAttempts.clamp(0, 5)))
          .toInt(),
    );
    final clampedDelay =
        delay > _reconnectMaxDelay ? _reconnectMaxDelay : delay;

    _reconnectAttempts++;

    _reconnectTimer = Timer(clampedDelay, () async {
      if (!_disposed && !_connected) {
        await connect();
      }
    });
  }

  void _closePipe() {
    _connected = false;
    _connectionStatusController.add(false);

    for (final completer in _pendingRequests.values) {
      completer.completeError(const IpcException('Connection closed'));
    }
    _pendingRequests.clear();
    _readByteBuffer.clear();
    _closePipeHandle();
  }

  void _closePipeHandle() {
    if (_pipeHandle != _invalidHandleValue && _pipeHandle != 0) {
      _closeHandle(_pipeHandle);
      _pipeHandle = _invalidHandleValue;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopReading();
    _closePipe();
    await _notificationController.close();
    await _connectionStatusController.close();
  }
}

/// Exception thrown when an IPC operation fails.
class IpcException implements Exception {
  final String message;
  const IpcException(this.message);

  @override
  String toString() => 'IpcException: $message';
}
